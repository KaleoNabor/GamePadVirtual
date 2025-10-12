import 'dart:async';
import 'dart:convert'; // Necessário para JSON
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:gamepadvirtual/models/connection_state.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/vibration_service.dart'; // Importe seu serviço de vibração

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

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  // --- Constantes ---
  static const MethodChannel _discoveryChannel = MethodChannel('com.example.gamepadvirtual/discovery');
  static const int dataPort = 27015;

  // --- Controladores de Stream ---
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _discoveredServersController = StreamController<List<DiscoveredServer>>.broadcast();

  // --- Variáveis de Estado (MODIFICADAS PARA UDP) ---
  ConnectionState _currentState = ConnectionState.disconnected();
  RawDatagramSocket? _udpSocket; // <<< TROCADO de Socket para RawDatagramSocket
  InternetAddress? _serverAddress; // <<< Endereço do servidor para enviar pacotes
  BluetoothConnection? _bluetoothConnection;
  final List<DiscoveredServer> _foundServers = [];
  final VibrationService _vibrationService = VibrationService(); // Instância do serviço de vibração

  // --- Streams Públicas ---
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<DiscoveredServer>> get discoveredServersStream => _discoveredServersController.stream;
  ConnectionState get currentState => _currentState;

  // --- Lógica de Descoberta (sem alterações) ---
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

  // --- CONEXÃO UDP (LÓGICA COMPLETAMENTE NOVA) ---
  Future<bool> connectToServer(DiscoveredServer server) async {
    await _disconnectCurrent(updateState: false);
    try {
      // Em UDP, não "conectamos", apenas criamos um socket para enviar e receber
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _serverAddress = server.ipAddress;
      
      // Configura o listener para receber comandos de vibração
      _listenForVibration(_udpSocket!);
      
      _updateConnectionState(ConnectionState.wifiDirectConnected(deviceName: '${server.name} (${server.ipAddress.address})'));
      return true;
    } catch (e) {
      print("Erro ao iniciar cliente UDP: $e");
      await _disconnectCurrent();
      return false;
    }
  }

  // --- Lógica de Envio de Dados (MODIFICADA) ---
  void sendGamepadData(GamepadInputData data) {
    if (!_currentState.isConnected) return;
    try {
      final Uint8List packet = data.toPacketBytes();
      if (_currentState.type == ConnectionType.bluetooth && _bluetoothConnection != null) {
        _bluetoothConnection!.output.add(packet);
      } else if (_udpSocket != null && _serverAddress != null) {
        // Envia o pacote para o endereço do servidor que descobrimos
        _udpSocket!.send(packet, _serverAddress!, dataPort);
      }
    } catch (e) {
      // Em UDP, erros de envio são menos comuns, mas podemos desconectar se algo der errado
      print('Erro ao enviar dados do gamepad: $e');
    }
  }

  // --- Lógica para Ouvir Comandos de Vibração (NOVA FUNÇÃO REUTILIZÁVEL) ---
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
          // Ignora pacotes que não são JSON (como os pacotes do gamepad, se o servidor os enviasse de volta)
        }
      }
    });
  }
  
  Future<void> sendDisconnectSignal() async {
    // A mensagem precisa ser exatamente a mesma que o servidor C++ espera.
    final disconnectMessage = utf8.encode("DISCONNECT_GPV_PLAYER");

    if (_currentState.type == ConnectionType.wifiDirect && _udpSocket != null && _serverAddress != null) {
      _udpSocket!.send(disconnectMessage, _serverAddress!, dataPort);
      print("Sinal de desconexão UDP enviado.");
    }
    // No futuro, a lógica para Bluetooth seria adicionada aqui
    else if (_currentState.type == ConnectionType.bluetooth && _bluetoothConnection != null) {
        _bluetoothConnection!.output.add(disconnectMessage);
        print("Sinal de desconexão Bluetooth enviado.");
    }
  }

  // --- Lógica de Desconexão (MODIFICADA) ---
  Future<void> disconnect() async {
    await _disconnectCurrent();
  }

  Future<void> _disconnectCurrent({bool updateState = true}) async {
    // Bluetooth
    _bluetoothConnection?.close();
    _bluetoothConnection = null;
    
    // UDP
    _udpSocket?.close();
    _udpSocket = null;
    _serverAddress = null;
    
    stopDiscovery();
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
  }
  
  // Lógica do Bluetooth (sem grandes alterações, mas adaptada para o novo fluxo)
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try { return await FlutterBluetoothSerial.instance.getBondedDevices(); } 
    catch (e) { return []; }
  }

  Future<bool> connectToBluetooth(BluetoothDevice device) async {
    await _disconnectCurrent(updateState: false);
    try {
      _bluetoothConnection = await BluetoothConnection.toAddress(device.address);
      _updateConnectionState(ConnectionState.bluetoothConnected(deviceName: device.name ?? 'Unknown Device', deviceAddress: device.address));
      // Listener para vibração via Bluetooth
      _bluetoothConnection!.input!.listen((data) {
          try {
            final message = utf8.decode(data);
            final json = jsonDecode(message);
            if (json['type'] == 'vibration') {
              final List<dynamic> patternDyn = json['pattern'];
              final List<int> pattern = patternDyn.map((e) => e as int).toList();
              _vibrationService.vibratePattern(pattern);
            }
          } catch (e) {
             // Ignora pacotes não-JSON
          }
      }, onDone: disconnect);
      return true;
    } catch (e) {
      await _disconnectCurrent();
      return false;
    }
  }
}