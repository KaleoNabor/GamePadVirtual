import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:gamepadvirtual/models/connection_state.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';
// ADICIONE ESTE IMPORT
import 'package:gamepadvirtual/models/gamepad_input_data.dart';

// CLASSE REMOVIDA: GamepadInputData agora está em 'gamepad_input_data.dart'

// Classe DiscoveredServer (sem alterações)
class DiscoveredServer {
  final String name;
  final InternetAddress ipAddress;
  DiscoveredServer({required this.name, required this.ipAddress});
}

// ENUM CORRIGIDO: Renomeado para evitar conflito
enum DiscoveredDeviceType { ble, classic }

// CLASSE CORRIGIDA: Usa o novo nome do enum
class DiscoveredBluetoothDevice {
  final String id;
  final String name;
  final String address;
  final DiscoveredDeviceType type;
  final dynamic underlyingDevice;

  DiscoveredBluetoothDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.underlyingDevice,
  });

  factory DiscoveredBluetoothDevice.fromBle(ble.BluetoothDevice device) {
    return DiscoveredBluetoothDevice(
      id: device.remoteId.toString(),
      name: device.platformName,
      address: device.remoteId.toString(),
      type: DiscoveredDeviceType.ble,
      underlyingDevice: device,
    );
  }

  factory DiscoveredBluetoothDevice.fromClassic(classic.BluetoothDevice device) {
    return DiscoveredBluetoothDevice(
      id: device.address,
      name: device.name ?? 'Dispositivo Desconhecido',
      address: device.address,
      type: DiscoveredDeviceType.classic,
      underlyingDevice: device,
    );
  }
}

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  // --- UUIDs do nosso servidor C++ ---
  static final ble.Guid SERVICE_UUID = ble.Guid("00001812-0000-1000-8000-00805f9b34fb");
  static final ble.Guid INPUT_CHAR_UUID = ble.Guid("00002a4d-0000-1000-8000-00805f9b34fb");
  static final ble.Guid VIBRATION_CHAR_UUID = ble.Guid("1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d");

  // --- Constantes e Canais ---
  static const MethodChannel _discoveryChannel = MethodChannel('com.example.gamepadvirtual/discovery');
  static const int dataPort = 27015;

  // --- Controladores de Stream ---
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _discoveredServersController = StreamController<List<DiscoveredServer>>.broadcast();
  final _discoveredBleDevicesController = StreamController<List<DiscoveredBluetoothDevice>>.broadcast();
  final _unifiedBluetoothDevicesController = StreamController<List<DiscoveredBluetoothDevice>>.broadcast();

  // --- Variáveis de Estado (Unificadas) ---
  ConnectionState _currentState = ConnectionState.disconnected();
  final VibrationService _vibrationService = VibrationService();
  
  // Estado do UDP
  RawDatagramSocket? _udpSocket;
  InternetAddress? _serverAddress;
  final List<DiscoveredServer> _foundServers = [];
  
  // Estado do BLE
  ble.BluetoothDevice? _connectedBleDevice;
  ble.BluetoothCharacteristic? _gamepadInputCharacteristic;
  ble.BluetoothCharacteristic? _vibrationOutputCharacteristic;
  StreamSubscription<List<ble.ScanResult>>? _scanSubscription;

  // BLUETOOTH CLÁSSICO (REINTRODUZIDO)
  classic.BluetoothConnection? _classicBluetoothConnection;

  // --- Streams Públicas ---
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<DiscoveredServer>> get discoveredServersStream => _discoveredServersController.stream;
  Stream<List<DiscoveredBluetoothDevice>> get discoveredBleDevicesStream => _discoveredBleDevicesController.stream;
  Stream<List<DiscoveredBluetoothDevice>> get unifiedBluetoothDevicesStream => _unifiedBluetoothDevicesController.stream;
  ConnectionState get currentState => _currentState;

  // --- Lógica de Descoberta Wi-Fi (sem alterações) ---
  Future<void> discoverServers() async {
    _foundServers.clear();
    _discoveredServersController.add(_foundServers);
    try {
      _discoveryChannel.setMethodCallHandler((call) async {
        if (call.method == 'serverFound') {
          final Map args = call.arguments;
          final serverIp = args['ip'];
          final serverName = args['name'];
          if (serverIp != null && serverName != null) {
            final newServer = DiscoveredServer(name: serverName, ipAddress: InternetAddress(serverIp));
            if (!_foundServers.any((s) => s.ipAddress.address == newServer.ipAddress.address)) {
              _foundServers.add(newServer);
              _discoveredServersController.add(List.from(_foundServers));
            }
          }
        }
      });
      await _discoveryChannel.invokeMethod('startDiscovery');
    } catch (e) {
      print("Erro ao iniciar descoberta nativa: $e");
    }
  }

  void stopDiscovery() {
    _discoveryChannel.invokeMethod('stopDiscovery');
    _discoveryChannel.setMethodCallHandler(null);
  }

  // --- CONEXÃO UDP ---
  Future<bool> connectToServer(DiscoveredServer server) async {
    await _disconnectCurrent(updateState: false);
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _serverAddress = server.ipAddress;
      
      _listenForVibration(_udpSocket!);
      
      _updateConnectionState(ConnectionState.wifiDirectConnected(deviceName: '${server.name} (${server.ipAddress.address})'));
      return true;
    } catch (e) {
      print("Erro ao iniciar cliente UDP: $e");
      await _disconnectCurrent();
      return false;
    }
  }

  // =======================================================================
  // NOVA FUNÇÃO PRINCIPAL DE DESCOBERTA UNIFICADA
  // =======================================================================
  void discoverAllBluetoothDevices() {
    final foundDevices = <String, DiscoveredBluetoothDevice>{};

    // 1. Inicia o scan BLE
    ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    ble.FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        if (r.device.platformName.isNotEmpty && r.advertisementData.serviceUuids.contains(SERVICE_UUID)) {
          final device = DiscoveredBluetoothDevice.fromBle(r.device);
          foundDevices[device.address] = device;
        }
      }
      _unifiedBluetoothDevicesController.add(foundDevices.values.toList());
    });

    // 2. Busca os dispositivos pareados
    getPairedDevices().then((pairedDevices) {
      for (var device in pairedDevices) {
        if (!foundDevices.containsKey(device.address)) {
          foundDevices[device.address] = DiscoveredBluetoothDevice.fromClassic(device);
        }
      }
      _unifiedBluetoothDevicesController.add(foundDevices.values.toList());
    });
  }

  void stopAllBluetoothDiscovery() {
    ble.FlutterBluePlus.stopScan();
  }

  // =======================================================================
  // FUNÇÃO CORRIGIDA: CONEXÃO "INTELIGENTE"
  // =======================================================================
  Future<bool> connectToBluetoothDevice(DiscoveredBluetoothDevice device) {
    if (device.type == DiscoveredDeviceType.ble) {
      return connectToBleDevice(device.underlyingDevice as ble.BluetoothDevice);
    } else {
      return connectToClassicBluetooth(device.underlyingDevice as classic.BluetoothDevice);
    }
  }

  // =======================================================================
  // LÓGICA: BLUETOOTH LOW ENERGY (ATUALIZADA)
  // =======================================================================
  void scanForBleDevices() {
    final List<DiscoveredBluetoothDevice> foundDevices = [];
    
    _scanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
      for (ble.ScanResult r in results) {
        if (r.device.platformName.isNotEmpty && !foundDevices.any((d) => d.id == r.device.remoteId.toString())) {
            foundDevices.add(DiscoveredBluetoothDevice.fromBle(r.device));
        }
      }
      _discoveredBleDevicesController.add(List.from(foundDevices));
    });

    ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)); 
  }

  void stopBleScan() {
    ble.FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
  }

  Future<bool> connectToBleDevice(ble.BluetoothDevice device) async {
    await _disconnectCurrent(updateState: false);

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedBleDevice = device;

      List<ble.BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid == SERVICE_UUID) {
          for (var char in service.characteristics) {
            if (char.uuid == INPUT_CHAR_UUID) {
              _gamepadInputCharacteristic = char;
            } else if (char.uuid == VIBRATION_CHAR_UUID) {
              _vibrationOutputCharacteristic = char;
            }
          }
        }
      }

      if (_gamepadInputCharacteristic != null && _vibrationOutputCharacteristic != null) {
        await _vibrationOutputCharacteristic!.setNotifyValue(true);
        _vibrationOutputCharacteristic!.onValueReceived.listen((value) {
          try {
            final message = utf8.decode(value);
            final json = jsonDecode(message);
            if (json['type'] == 'vibration') {
              final List<dynamic> patternDyn = json['pattern'];
              final List<int> pattern = patternDyn.map((e) => e as int).toList();
              _vibrationService.vibratePattern(pattern);
            }
          } catch(e) { /* Ignora dados inválidos */ }
        });

        _updateConnectionState(ConnectionState.bluetoothLeConnected(
          deviceName: device.platformName, 
          deviceAddress: device.remoteId.toString()
        ));
        return true;
      }
    } catch (e) {
      print("Erro ao conectar via BLE: $e");
    }
    
    await _disconnectCurrent();
    return false;
  }

  // =======================================================================
  // LÓGICA REINTRODUZIDA: BLUETOOTH CLÁSSICO
  // =======================================================================
  Future<List<classic.BluetoothDevice>> getPairedDevices() async {
    try {
      return await classic.FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print("Erro ao obter dispositivos pareados: $e");
      return [];
    }
  }

  Future<bool> connectToClassicBluetooth(classic.BluetoothDevice device) async {
    await _disconnectCurrent(updateState: false);
    try {
      _classicBluetoothConnection = await classic.BluetoothConnection.toAddress(device.address);
      
      _classicBluetoothConnection!.input!.listen((data) {
          try {
            final message = utf8.decode(data);
            final json = jsonDecode(message);
            if (json['type'] == 'vibration') {
              final pattern = List<int>.from(json['pattern']);
              _vibrationService.vibratePattern(pattern);
            }
          } catch (e) { /* Ignora pacotes não-JSON */ }
      }, onDone: disconnect);
      
      _updateConnectionState(ConnectionState.bluetoothClassicConnected(
          deviceName: device.name ?? 'Desconhecido', 
          deviceAddress: device.address
      ));
      return true;
    } catch (e) {
      print("Erro ao conectar via Bluetooth Clássico: $e");
      await _disconnectCurrent();
      return false;
    }
  }

  // --- Lógica de Envio de Dados (UNIFICADA) ---
  void sendGamepadData(GamepadInputData data) {
    if (!_currentState.isConnected) return;
    try {
      final Uint8List packet = data.toPacketBytes();

      if (_currentState.isBle && _gamepadInputCharacteristic != null) {
        _gamepadInputCharacteristic!.write(packet, withoutResponse: true);
      } 
      else if (_currentState.isClassicBt && _classicBluetoothConnection != null) {
        _classicBluetoothConnection!.output.add(packet);
      }
      else if (_currentState.isWifi && _udpSocket != null && _serverAddress != null) {
        _udpSocket!.send(packet, _serverAddress!, dataPort);
      }
    } catch (e) {
      print('Erro ao enviar dados do gamepad: $e');
    }
  }

  // --- Lógica para Ouvir Comandos de Vibração ---
  void _listenForVibration(Stream<RawSocketEvent> stream) {
    stream.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? datagram = _udpSocket?.receive();
        if (datagram == null) return;
        
        try {
          final message = utf8.decode(datagram.data);
          final json = jsonDecode(message);
          if (json['type'] == 'vibration') {
            final List<dynamic> patternDyn = json['pattern'];
            final List<int> pattern = patternDyn.map((e) => e as int).toList();
            _vibrationService.vibratePattern(pattern);
          }
        } catch (e) {
          // Ignora pacotes que não são JSON
        }
      }
    });
  }
  
  Future<void> sendDisconnectSignal() async {
    final disconnectMessage = utf8.encode("DISCONNECT_GPV_PLAYER");

    if (_currentState.isWifi && _udpSocket != null && _serverAddress != null) {
      _udpSocket!.send(disconnectMessage, _serverAddress!, dataPort);
      print("Sinal de desconexão UDP enviado.");
    }
    else if (_currentState.isBle && _gamepadInputCharacteristic != null) {
      final disconnectPacket = Uint8List.fromList([0xFF, 0xFF]);
      _gamepadInputCharacteristic!.write(disconnectPacket, withoutResponse: true);
      print("Sinal de desconexão BLE enviado.");
    }
    else if (_currentState.isClassicBt && _classicBluetoothConnection != null) {
      _classicBluetoothConnection!.output.add(disconnectMessage);
      print("Sinal de desconexão Bluetooth Clássico enviado.");
    }
  }

  // --- Lógica de Desconexão (UNIFICADA) ---
  Future<void> disconnect() async {
    await _disconnectCurrent();
  }

  Future<void> _disconnectCurrent({bool updateState = true}) async {
    // UDP
    _udpSocket?.close();
    _udpSocket = null;
    _serverAddress = null;
    stopDiscovery();
    
    // BLE
    await _connectedBleDevice?.disconnect();
    _connectedBleDevice = null;
    _gamepadInputCharacteristic = null;
    _vibrationOutputCharacteristic = null;
    stopBleScan();
    
    // BLUETOOTH CLÁSSICO
    _classicBluetoothConnection?.close();
    _classicBluetoothConnection = null;

    if (updateState) {
      _updateConnectionState(ConnectionState.disconnected());
    }
  }

  void _updateConnectionState(ConnectionState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
  }
  
  void dispose() {
    _disconnectCurrent();
    _connectionStateController.close();
    _discoveredServersController.close();
    _discoveredBleDevicesController.close();
    _unifiedBluetoothDevicesController.close();
    _scanSubscription?.cancel();
  }
}