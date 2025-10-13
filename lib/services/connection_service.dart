import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gamepadvirtual/models/connection_state.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';

// Definição da classe GamepadInputData (sem alterações)
class GamepadInputData {
  final Map<ButtonType, bool> buttons;
  final Map<String, double> analogSticks;
  final Map<String, dynamic> sensors;
  final DateTime timestamp;

  GamepadInputData({
    required this.buttons,
    required this.analogSticks,
    required this.sensors,
    required this.timestamp,
  });

  Uint8List toPacketBytes() {
    final byteData = ByteData(20);
    int buttonFlags = 0;
    if (buttons[ButtonType.dpadUp] == true) buttonFlags |= (1 << 0);
    if (buttons[ButtonType.dpadDown] == true) buttonFlags |= (1 << 1);
    if (buttons[ButtonType.dpadLeft] == true) buttonFlags |= (1 << 2);
    if (buttons[ButtonType.dpadRight] == true) buttonFlags |= (1 << 3);
    if (buttons[ButtonType.start] == true) buttonFlags |= (1 << 4);
    if (buttons[ButtonType.select] == true) buttonFlags |= (1 << 5);
    if (buttons[ButtonType.leftStickButton] == true) buttonFlags |= (1 << 6);
    if (buttons[ButtonType.rightStickButton] == true) buttonFlags |= (1 << 7);
    if (buttons[ButtonType.leftBumper] == true) buttonFlags |= (1 << 8);
    if (buttons[ButtonType.rightBumper] == true) buttonFlags |= (1 << 9);
    if (buttons[ButtonType.a] == true || buttons[ButtonType.cross] == true) buttonFlags |= (1 << 12);
    if (buttons[ButtonType.b] == true || buttons[ButtonType.circle] == true) buttonFlags |= (1 << 13);
    if (buttons[ButtonType.x] == true || buttons[ButtonType.square] == true) buttonFlags |= (1 << 14);
    if (buttons[ButtonType.y] == true || buttons[ButtonType.triangle] == true) buttonFlags |= (1 << 15);
    byteData.setUint16(0, buttonFlags, Endian.little);
    byteData.setInt8(2, ((analogSticks['leftX'] ?? 0.0) * 127).round());
    byteData.setInt8(3, ((analogSticks['leftY'] ?? 0.0) * 127).round());
    byteData.setInt8(4, ((analogSticks['rightX'] ?? 0.0) * 127).round());
    byteData.setInt8(5, ((analogSticks['rightY'] ?? 0.0) * 127).round());
    byteData.setUint8(6, ((analogSticks['leftTrigger'] ?? 0.0) * 255).toInt());
    byteData.setUint8(7, ((analogSticks['rightTrigger'] ?? 0.0) * 255).toInt());
    final gyroX = (sensors['gyroX'] ?? 0.0) * 100;
    final gyroY = (sensors['gyroY'] ?? 0.0) * 100;
    final gyroZ = (sensors['gyroZ'] ?? 0.0) * 100;
    byteData.setInt16(8, gyroX.round(), Endian.little);
    byteData.setInt16(10, gyroY.round(), Endian.little);
    byteData.setInt16(12, gyroZ.round(), Endian.little);
    final accelX = (sensors['accelX'] ?? 0.0) * 100;
    final accelY = (sensors['accelY'] ?? 0.0) * 100;
    final accelZ = (sensors['accelZ'] ?? 0.0) * 100;
    byteData.setInt16(14, accelX.round(), Endian.little);
    byteData.setInt16(16, accelY.round(), Endian.little);
    byteData.setInt16(18, accelZ.round(), Endian.little);
    return byteData.buffer.asUint8List();
  }
}

// Classe DiscoveredServer (sem alterações)
class DiscoveredServer {
  final String name;
  final InternetAddress ipAddress;
  DiscoveredServer({required this.name, required this.ipAddress});
}

// NOVA CLASSE para representar um dispositivo BLE descoberto
class DiscoveredBleDevice {
  final String id;
  final String name;
  final BluetoothDevice device;
  DiscoveredBleDevice({required this.id, required this.name, required this.device});
}

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  // --- UUIDs do nosso servidor C++ ---
  static final Guid SERVICE_UUID = Guid("00001812-0000-1000-8000-00805f9b34fb");
  static final Guid INPUT_CHAR_UUID = Guid("00002a4d-0000-1000-8000-00805f9b34fb");
  static final Guid VIBRATION_CHAR_UUID = Guid("1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d");

  // --- Constantes e Canais ---
  static const MethodChannel _discoveryChannel = MethodChannel('com.example.gamepadvirtual/discovery');
  static const int dataPort = 27015;

  // --- Controladores de Stream ---
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _discoveredServersController = StreamController<List<DiscoveredServer>>.broadcast();
  final _discoveredBleDevicesController = StreamController<List<DiscoveredBleDevice>>.broadcast();

  // --- Variáveis de Estado ---
  ConnectionState _currentState = ConnectionState.disconnected();
  final VibrationService _vibrationService = VibrationService();
  
  // Estado do UDP
  RawDatagramSocket? _udpSocket;
  InternetAddress? _serverAddress;
  final List<DiscoveredServer> _foundServers = [];
  
  // NOVO ESTADO do BLE
  BluetoothDevice? _connectedBleDevice;
  BluetoothCharacteristic? _gamepadInputCharacteristic;
  BluetoothCharacteristic? _vibrationOutputCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // --- Streams Públicas ---
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<DiscoveredServer>> get discoveredServersStream => _discoveredServersController.stream;
  Stream<List<DiscoveredBleDevice>> get discoveredBleDevicesStream => _discoveredBleDevicesController.stream;
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
  // NOVA LÓGICA: BLUETOOTH LOW ENERGY
  // =======================================================================
  void scanForBleDevices() {
    final List<DiscoveredBleDevice> foundDevices = [];
    
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Filtra para garantir que o dispositivo tenha um nome e não esteja já na lista
        if (r.device.platformName.isNotEmpty && !foundDevices.any((d) => d.id == r.device.remoteId.toString())) {
            foundDevices.add(DiscoveredBleDevice(
              id: r.device.remoteId.toString(),
              name: r.device.platformName,
              device: r.device,
            ));
        }
      }
      _discoveredBleDevicesController.add(List.from(foundDevices));
    });

    // Inicia o scan, filtrando por nosso serviço específico para otimização
    //FlutterBluePlus.startScan(withServices: [SERVICE_UUID], timeout: const Duration(seconds: 5));
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)); 
  }

  void stopBleScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
  }

  Future<bool> connectToBleDevice(DiscoveredBleDevice discoveredDevice) async {
    await _disconnectCurrent(updateState: false);
    final device = discoveredDevice.device;

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedBleDevice = device;

      List<BluetoothService> services = await device.discoverServices();
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
        // Assina a característica de vibração para receber notificações
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

        _updateConnectionState(ConnectionState.bluetoothConnected(
          deviceName: discoveredDevice.name, 
          deviceAddress: discoveredDevice.id
        ));
        return true;
      }
    } catch (e) {
      print("Erro ao conectar via BLE: $e");
    }
    
    await _disconnectCurrent();
    return false;
  }

  // --- Lógica de Envio de Dados (Atualizada) ---
  void sendGamepadData(GamepadInputData data) {
    if (!_currentState.isConnected) return;
    try {
      final Uint8List packet = data.toPacketBytes();

      if (_currentState.type == ConnectionType.bluetooth && _gamepadInputCharacteristic != null) {
        // Envia via BLE. 'withoutResponse: true' é crucial para alta frequência, como UDP.
        _gamepadInputCharacteristic!.write(packet, withoutResponse: true);
      } 
      else if (_udpSocket != null && _serverAddress != null) {
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

    if (_currentState.type == ConnectionType.wifiDirect && _udpSocket != null && _serverAddress != null) {
      _udpSocket!.send(disconnectMessage, _serverAddress!, dataPort);
      print("Sinal de desconexão UDP enviado.");
    }
    // Para BLE, podemos enviar um pacote especial ou simplesmente desconectar
    else if (_currentState.type == ConnectionType.bluetooth && _gamepadInputCharacteristic != null) {
      // Envia um pacote especial de desconexão via BLE
      final disconnectPacket = Uint8List.fromList([0xFF, 0xFF]); // Pacote especial
      _gamepadInputCharacteristic!.write(disconnectPacket, withoutResponse: true);
      print("Sinal de desconexão BLE enviado.");
    }
  }

  // --- Lógica de Desconexão (Atualizada) ---
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
    _scanSubscription?.cancel();
  }
}