// ignore_for_file: non_constant_identifier_names
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:gamepadvirtual/models/connection_state.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';
import 'package:gamepadvirtual/models/gamepad_input_data.dart';
import 'package:flutter/foundation.dart';

// =============================================
// MODELOS DE DADOS PARA DESCOBERTA DE SERVIDORES
// =============================================

/// Representa um servidor descoberto na rede local
class DiscoveredServer {
  final String name;
  final InternetAddress ipAddress;
  DiscoveredServer({required this.name, required this.ipAddress});
}

/// Tipos de dispositivos Bluetooth suportados
enum DiscoveredDeviceType { ble, classic }

/// Representa um dispositivo Bluetooth descoberto (BLE ou Clássico)
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

  /// Construtor para dispositivos BLE
  factory DiscoveredBluetoothDevice.fromBle(ble.BluetoothDevice device) {
    return DiscoveredBluetoothDevice(
      id: device.remoteId.toString(),
      name: device.platformName,
      address: device.remoteId.toString(),
      type: DiscoveredDeviceType.ble,
      underlyingDevice: device,
    );
  }

  /// Construtor para dispositivos Bluetooth Clássico
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

// =============================================
// SERVIÇO PRINCIPAL DE GERENCIAMENTO DE CONEXÕES
// =============================================

/// Serviço central para gerenciar todas as conexões (Wi-Fi, Bluetooth BLE, Bluetooth Clássico)
class ConnectionService {
  // =============================================
  // CONFIGURAÇÕES E CONSTANTES
  // =============================================
  
  /// Padrão Singleton - única instância do serviço
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  
  /// UUIDs do serviço BLE e características
  static final ble.Guid SERVICE_UUID = ble.Guid("00001812-0000-1000-8000-00805f9b34fb");
  static final ble.Guid INPUT_CHAR_UUID = ble.Guid("00002a4d-0000-1000-8000-00805f9b34fb");
  static final ble.Guid VIBRATION_CHAR_UUID = ble.Guid("1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d");

  /// Portas de comunicação com o servidor PC
  static const int CONTROL_PORT_TCP = 42000;
  static const int DATA_PORT_UDP = 42001;
  
  /// Configurações do watchdog de conexão
  static const Duration _watchdogInterval = Duration(seconds: 3);
  static const Duration _connectionTimeout = Duration(seconds: 5);

  // =============================================
  // CANAIS DE COMUNICAÇÃO E STREAMS
  // =============================================
  
  /// Canal nativo para descoberta de servidores
  static const MethodChannel _discoveryChannel = MethodChannel('com.example.gamepadvirtual/discovery');
  
  /// Streams para notificação de mudanças de estado
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _systemMessageController = StreamController<String>.broadcast();
  final _discoveredServersController = StreamController<List<DiscoveredServer>>.broadcast();
  final _discoveredBleDevicesController = StreamController<List<DiscoveredBluetoothDevice>>.broadcast();
  final _unifiedBluetoothDevicesController = StreamController<List<DiscoveredBluetoothDevice>>.broadcast();

  // =============================================
  // ESTADO INTERNO E GERENCIAMENTO DE CONEXÕES
  // =============================================
  
  /// Estado atual da conexão
  ConnectionState _currentState = ConnectionState.disconnected();
  
  /// Serviço de vibração para feedback háptico
  final VibrationService _vibrationService = VibrationService();
  
  // =============================================
  // CONEXÕES DE REDE (Wi-Fi/USB)
  // =============================================
  
  /// Socket TCP para controle e handshake
  Socket? _tcpSocket;
  
  /// Socket UDP para dados do gamepad (alta frequência)
  RawDatagramSocket? _udpSocket;
  
  /// Endereço do servidor conectado
  InternetAddress? _serverAddress;
  
  /// Lista de servidores descobertos
  final List<DiscoveredServer> _foundServers = [];
  
  // =============================================
  // CONEXÕES BLUETOOTH
  // =============================================
  
  /// Dispositivo BLE conectado
  ble.BluetoothDevice? _connectedBleDevice;
  
  /// Características BLE para entrada/saída
  ble.BluetoothCharacteristic? _gamepadInputCharacteristic;
  ble.BluetoothCharacteristic? _vibrationOutputCharacteristic;
  
  /// Subscription para scan BLE
  StreamSubscription<List<ble.ScanResult>>? _scanSubscription;
  
  /// Conexão Bluetooth Clássico
  classic.BluetoothConnection? _classicBluetoothConnection;

  // =============================================
  // TIMERS E WATCHDOG
  // =============================================
  
  /// Timer para keep-alive da conexão
  Timer? _keepAliveTimer;
  
  /// Watchdog para detectar conexões perdidas
  Timer? _connectionWatchdogTimer;
  
  /// Timestamp do último dado recebido
  DateTime? _lastDataReceivedTime;
  
  /// Flag de controle do watchdog
  

  // CORREÇÃO: Flag para prevenir chamadas múltiplas de desconexão (race condition)
  bool _isDisconnecting = false;

  // =============================================
  // CONSTRUTOR E INICIALIZAÇÃO
  // =============================================

  /// Construtor privado para padrão Singleton
  ConnectionService._internal() {
    _startConnectionWatchdog();
  }

  // =============================================
  // INTERFACE PÚBLICA - GETTERS E STREAMS
  // =============================================

  /// Stream do estado da conexão
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  /// Stream de mensagens do sistema
  Stream<String> get systemMessageStream => _systemMessageController.stream;
  
  /// Stream de servidores descobertos
  Stream<List<DiscoveredServer>> get discoveredServersStream => _discoveredServersController.stream;
  
  /// Stream de dispositivos BLE descobertos
  Stream<List<DiscoveredBluetoothDevice>> get discoveredBleDevicesStream => _discoveredBleDevicesController.stream;
  
  /// Stream unificado de dispositivos Bluetooth
  Stream<List<DiscoveredBluetoothDevice>> get unifiedBluetoothDevicesStream => _unifiedBluetoothDevicesController.stream;
  
  /// Estado atual da conexão
  ConnectionState get currentState => _currentState;

  // =============================================
  // DESCOBERTA DE SERVIDORES NA REDE
  // =============================================

  /// Inicia a descoberta de servidores na rede local
  Future<void> discoverServers() async {
    _foundServers.clear();
    _discoveredServersController.add(_foundServers);
    
    try {
      // Configura handler para servidores encontrados
      _discoveryChannel.setMethodCallHandler((call) async {
        if (call.method == 'serverFound') {
          final Map args = call.arguments;
          final serverIp = args['ip'];
          final serverName = args['name'];
          
          if (serverIp != null && serverName != null) {
            final newServer = DiscoveredServer(
              name: serverName, 
              ipAddress: InternetAddress(serverIp)
            );
            
            // Adiciona apenas se não existir
            if (!_foundServers.any((s) => s.ipAddress.address == newServer.ipAddress.address)) {
              _foundServers.add(newServer);
              _discoveredServersController.add(List.from(_foundServers));
            }
          }
        }
      });
      
      await _discoveryChannel.invokeMethod('startDiscovery');
    } catch (e) {
      debugPrint("Erro ao iniciar descoberta nativa: $e");
    }
  }

  /// Para a descoberta de servidores
  void stopDiscovery() {
    try {
      _discoveryChannel.invokeMethod('stopDiscovery');
      _discoveryChannel.setMethodCallHandler(null);
    } catch (e) {
      debugPrint("Erro ao parar descoberta (ignorado): $e");
    }
  }

  // =============================================
  // CONEXÃO VIA REDE (Wi-Fi / USB)
  // =============================================

  /// Conecta a um servidor via TCP/UDP
  Future<bool> connectToServer(DiscoveredServer server) async {
    await _disconnectCurrent(updateState: false);
    _isDisconnecting = false; // Garante que podemos conectar
    
    try {
      // Estabelece conexão TCP
      _tcpSocket = await Socket.connect(
        server.ipAddress, 
        CONTROL_PORT_TCP,
        timeout: const Duration(seconds: 5),
      );
      
      _serverAddress = server.ipAddress;
      
      // CORREÇÃO: Handlers de 'done' e 'error' precisam ser robustos
      _tcpSocket!.done.then((_) {
        debugPrint("Socket.done (TCP) recebido. Disparando desconexão.");
        disconnect(); // Chama a função de desconexão segura
      }).catchError((e) {
        // Captura erros que possam ocorrer no próprio listener 'done'
        debugPrint("Erro no listener 'done' (TCP): $e");
        disconnect();
      });

      _tcpSocket!.handleError((error) {
        // Este é o handler que captura o "Broken pipe"
        debugPrint("Socket.handleError (TCP) recebido: $error. Disparando desconexão.");
        disconnect(); // Chama a função de desconexão segura
      });

      // Configura socket UDP para dados do gamepad
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _listenForVibration(_udpSocket!);
      
      _startKeepAlive();

      // Atualiza estado da conexão
      _updateConnectionState(ConnectionState.wifiDirectConnected(
          deviceName: '${server.name} (${server.ipAddress.address})'));
      return true;

    } catch (e) {
      debugPrint("Erro ao conectar via TCP/UDP: $e");
      await _disconnectCurrent();
      return false;
    }
  }

  // =============================================
  // SISTEMA DE KEEP-ALIVE
  // =============================================

  /// Inicia o envio periódico de pacotes keep-alive
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_tcpSocket != null && _currentState.isWifi && !_isDisconnecting) {
        try {
          // A exceção 'Broken pipe' não será pega aqui,
          // será pega pelo _tcpSocket.handleError
          _tcpSocket!.add(Uint8List.fromList([0x01]));
        } catch (e) {
          // Este catch é para erros síncronos (raro)
          debugPrint("Keep-alive falhou (erro síncrono): $e");
          disconnect(); 
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  // =============================================
  // DESCOBERTA DE DISPOSITIVOS BLUETOOTH
  // =============================================

  /// Descobre todos os dispositivos Bluetooth (BLE + Clássico)
  void discoverAllBluetoothDevices() {
    final foundDevices = <String, DiscoveredBluetoothDevice>{};

    // Scan BLE
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

    // Dispositivos pareados (Clássico)
    getPairedDevices().then((pairedDevices) {
      for (var device in pairedDevices) {
        if (!foundDevices.containsKey(device.address)) {
          foundDevices[device.address] = DiscoveredBluetoothDevice.fromClassic(device);
        }
      }
      _unifiedBluetoothDevicesController.add(foundDevices.values.toList());
    });
  }

  /// Para toda a descoberta Bluetooth
  void stopAllBluetoothDiscovery() {
    ble.FlutterBluePlus.stopScan();
  }

  // =============================================
  // CONEXÃO BLUETOOTH BLE
  // =============================================

  /// Escaneia dispositivos BLE específicos do gamepad
  void scanForBleDevices() {
    final List<DiscoveredBluetoothDevice> foundDevices = [];
    
    _scanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
      for (ble.ScanResult r in results) {
        if (r.device.platformName.isNotEmpty && 
            !foundDevices.any((d) => d.id == r.device.remoteId.toString())) {
            foundDevices.add(DiscoveredBluetoothDevice.fromBle(r.device));
        }
      }
      _discoveredBleDevicesController.add(List.from(foundDevices));
    });

    ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)); 
  }

  /// Para o scan BLE
  void stopBleScan() {
    ble.FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
  }

  /// Conecta a um dispositivo BLE
  Future<bool> connectToBleDevice(ble.BluetoothDevice device) async {
    await _disconnectCurrent(updateState: false);
    _isDisconnecting = false;

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedBleDevice = device;

      // Descobre serviços e características
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

      // Configura notificação de vibração
      if (_gamepadInputCharacteristic != null && _vibrationOutputCharacteristic != null) {
        await _vibrationOutputCharacteristic!.setNotifyValue(true);
        _vibrationOutputCharacteristic!.onValueReceived.listen((value) {
          _handleReceivedData(value);
        });

        _updateConnectionState(ConnectionState.bluetoothLeConnected(
          deviceName: device.platformName, 
          deviceAddress: device.remoteId.toString()
        ));
        return true;
      }
    } catch (e) {
      debugPrint("Erro ao conectar via BLE: $e");
    }
    
    await _disconnectCurrent();
    return false;
  }

  // =============================================
  // CONEXÃO BLUETOOTH CLÁSSICO
  // =============================================

  /// Obtém dispositivos Bluetooth pareados
  Future<List<classic.BluetoothDevice>> getPairedDevices() async {
    try {
      return await classic.FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      debugPrint("Erro ao obter dispositivos pareados: $e");
      return [];
    }
  }

  /// Conecta via Bluetooth Clássico
  Future<bool> connectToClassicBluetooth(classic.BluetoothDevice device) async {
    await _disconnectCurrent(updateState: false);
    _isDisconnecting = false;
    try {
      _classicBluetoothConnection = await classic.BluetoothConnection.toAddress(device.address);
      
      _classicBluetoothConnection!.input!.listen((data) {
        _handleReceivedData(data);
      }, onDone: disconnect);
      
      _updateConnectionState(ConnectionState.bluetoothClassicConnected(
          deviceName: device.name ?? 'Desconhecido', 
          deviceAddress: device.address
      ));
      return true;
    } catch (e) {
      debugPrint("Erro ao conectar via Bluetooth Clássico: $e");
      await _disconnectCurrent();
      return false;
    }
  }

  /// Conecta a qualquer tipo de dispositivo Bluetooth
  Future<bool> connectToBluetoothDevice(DiscoveredBluetoothDevice device) {
    if (device.type == DiscoveredDeviceType.ble) {
      return connectToBleDevice(device.underlyingDevice as ble.BluetoothDevice);
    } else {
      return connectToClassicBluetooth(device.underlyingDevice as classic.BluetoothDevice);
    }
  }

  // =============================================
  // PROCESSAMENTO DE DADOS RECEBIDOS
  // =============================================

  /// Processa dados recebidos do servidor (vibração, mensagens de sistema)
  void _handleReceivedData(List<int> data) {
    _lastDataReceivedTime = DateTime.now(); // Atualiza watchdog
    
    try {
      final message = utf8.decode(data);
      final json = jsonDecode(message);
      
      if (json['type'] == 'vibration') {
        // Processa comando de vibração
        final List<dynamic> patternDyn = json['pattern'];
        final List<int> pattern = patternDyn.map((e) => e as int).toList();
        
        List<int>? amplitudes;
        if (json['amplitudes'] != null) {
          final List<dynamic> amplitudesDyn = json['amplitudes'];
          amplitudes = amplitudesDyn.map((e) => e as int).toList();
        }
        
        _vibrationService.vibratePatternFromGame(pattern, amplitudes: amplitudes);
        
      } else if (json['type'] == 'system' && json['code'] == 'server_full') {
        // Processa mensagem de servidor cheio
        _systemMessageController.add('server_full');
      }
    } catch (e) {
      // Ignora erros de parsing - dados podem ser binários
    }
  }

  // =============================================
  // ENVIO DE DADOS DO GAMEPAD
  // =============================================

  /// Envia dados do gamepad para o servidor
  void sendGamepadData(GamepadInputData data) {
    if (!_currentState.isConnected || _isDisconnecting) return;
    
    try {
      final Uint8List packet = data.toPacketBytes();

      // Envia via protocolo apropriado
      if (_currentState.isBle && _gamepadInputCharacteristic != null) {
        _gamepadInputCharacteristic!.write(packet, withoutResponse: true);
      } 
      else if (_currentState.isClassicBt && _classicBluetoothConnection != null) {
        _classicBluetoothConnection!.output.add(packet);
      }
      else if (_currentState.isWifi && _udpSocket != null && _serverAddress != null) {
        _udpSocket!.send(packet, _serverAddress!, DATA_PORT_UDP);
      }
      
      _lastDataReceivedTime = DateTime.now(); // Atualiza watchdog
      
    } catch (e) {
      debugPrint('Erro ao enviar dados do gamepad: $e');
      // Se há erro no envio, provavelmente a conexão caiu
      disconnect();
    }
  }

  // =============================================
  // ESCUTA DE VIBRAÇÃO VIA UDP
  // =============================================

  /// Configura listener para comandos de vibração via UDP
  void _listenForVibration(RawDatagramSocket socket) {
    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? datagram = socket.receive();
        if (datagram == null) return;
        _handleReceivedData(datagram.data);
      }
    });
  }

  // =============================================
  // WATCHDOG DE CONEXÃO
  // =============================================

  /// Inicia o watchdog para detectar conexões perdidas
  void _startConnectionWatchdog() {
    _connectionWatchdogTimer?.cancel();
    _connectionWatchdogTimer = Timer.periodic(_watchdogInterval, (timer) {
      if (_currentState.isConnected && !_isDisconnecting) {
        final now = DateTime.now();
        // Se não recebemos dados há mais do timeout, considera desconectado
        if (_lastDataReceivedTime != null && 
            now.difference(_lastDataReceivedTime!) > _connectionTimeout) {
          debugPrint("Watchdog: Conexão perdida - timeout");
          disconnect();
        }
      }
    });
  }

  /// Para o watchdog
  void _stopConnectionWatchdog() {
    _connectionWatchdogTimer?.cancel();
    _connectionWatchdogTimer = null;
  }

  // =============================================
  // CORREÇÃO: Função de desconexão (Tornar Idempotente)
  // =============================================

  /// Desconecta do servidor atual
  Future<void> disconnect() async {
    // CORREÇÃO: Trava para garantir que a limpeza só rode UMA VEZ.
    if (_isDisconnecting || !_currentState.isConnected) {
      return; // Já está desconectando ou já desconectado
    }
    
    debugPrint("Iniciando desconexão...");
    _isDisconnecting = true; // Ativa a trava

    try {
      // Envia sinal de desconexão apropriado para cada protocolo
      if (_currentState.isWifi && _tcpSocket != null) {
        // Não precisamos enviar nada, o 'destroy' abaixo cuida disso.
      } 
      else if (_currentState.isBle && _gamepadInputCharacteristic != null) {
        final disconnectPacket = Uint8List.fromList([0xFF, 0xFF]);
        _gamepadInputCharacteristic!.write(disconnectPacket, withoutResponse: true);
        debugPrint("Pacote de desconexão BLE enviado.");
      } 
      else if (_currentState.isClassicBt && _classicBluetoothConnection != null) {
        final disconnectMessage = utf8.encode("DISCONNECT_GPV_PLAYER");
        _classicBluetoothConnection!.output.add(disconnectMessage);
        await Future.delayed(const Duration(milliseconds: 100));
        debugPrint("Mensagem de desconexão Bluetooth enviada.");
      }
    } catch (e) {
      debugPrint("Erro ao enviar sinal de desconexão (ignorado): $e");
    }

    // Chama a limpeza real
    await _disconnectCurrent();
  }

  // =============================================
  // CORREÇÃO: Função de limpeza interna (Tornar Síncrona Segura)
  // =============================================

  /// Limpeza interna de conexões
  Future<void> _disconnectCurrent({bool updateState = true}) async {
    // Para timers
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _lastDataReceivedTime = null;
    
    // Para descobertas
    stopDiscovery();

    // CORREÇÃO: Envolver operações de I/O síncronas (que causam o freeze)
    // em try-catch para evitar que um erro impeça a limpeza dos outros.
    try {
      _tcpSocket?.destroy();
    } catch (e) {
      debugPrint("Erro ao destruir TCP (ignorado): $e");
    }
    _tcpSocket = null;
    
    try {
      _udpSocket?.close();
    } catch (e) {
      debugPrint("Erro ao fechar UDP (ignorado): $e");
    }
    _udpSocket = null;
    _serverAddress = null;
    
    // Limpa conexões BLE
    try {
      await _connectedBleDevice?.disconnect();
    } catch (e) {
      debugPrint("Erro ao desconectar BLE (ignorado): $e");
    }
    _connectedBleDevice = null;
    _gamepadInputCharacteristic = null;
    _vibrationOutputCharacteristic = null;
    stopBleScan();
    
    // Limpa conexões Bluetooth Clássico
    try {
      _classicBluetoothConnection?.close();
    } catch (e) {
      debugPrint("Erro ao fechar BT Clássico (ignorado): $e");
    }
    _classicBluetoothConnection = null;

    // Atualiza estado se solicitado
    if (updateState) {
      _updateConnectionState(ConnectionState.disconnected());
    }

    // CORREÇÃO: Libera a trava SOMENTE SE atualizou o estado
    if (updateState) {
      _isDisconnecting = false;
      debugPrint("Desconexão completa.");
    }
  }

  // =============================================
  // ATUALIZAÇÃO DE ESTADO
  // =============================================

  /// Atualiza o estado da conexão e notifica listeners
  void _updateConnectionState(ConnectionState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
  }

  // =============================================
  // VERIFICAÇÃO DE STATUS
  // =============================================

  /// Verifica manualmente o status da conexão
  void checkConnectionStatus() {
    if (_currentState.isConnected && !_isDisconnecting) {
      // Verifica se os sockets ainda estão válidos
      if (_currentState.isWifi && (_tcpSocket == null || _udpSocket == null)) {
        debugPrint("checkConnectionStatus: Detectado estado inconsistente (socket nulo). Forçando desconexão.");
        disconnect();
      }
      // Para Bluetooth, confiamos no watchdog e callbacks nativas
    }
  }

  // =============================================
  // LIMPEZA DE RECURSOS
  // =============================================

  /// Libera todos os recursos do serviço
  void dispose() {
    _stopConnectionWatchdog();
    _keepAliveTimer?.cancel();
    _disconnectCurrent(updateState: true); // Garante a limpeza ao descartar o singleton
    _connectionStateController.close();
    _systemMessageController.close();
    _discoveredServersController.close();
    _discoveredBleDevicesController.close();
    _unifiedBluetoothDevicesController.close();
    _scanSubscription?.cancel();
  }
}