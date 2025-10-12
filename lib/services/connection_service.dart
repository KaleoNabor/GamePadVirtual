import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:gamepadvirtual/models/connection_state.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';

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

  // DENTRO DE: lib/services/connection_service.dart

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

    // Botões (Offset 0, 2 bytes)
    byteData.setUint16(0, buttonFlags, Endian.little);
    // Analógicos (Offset 2, 4 bytes)
    byteData.setInt8(2, ((analogSticks['leftX'] ?? 0.0) * 127).round());
    byteData.setInt8(3, ((analogSticks['leftY'] ?? 0.0) * 127).round());
    byteData.setInt8(4, ((analogSticks['rightX'] ?? 0.0) * 127).round());
    byteData.setInt8(5, ((analogSticks['rightY'] ?? 0.0) * 127).round());
    // Gatilhos (Offset 6, 2 bytes)
    byteData.setUint8(6, ((analogSticks['leftTrigger'] ?? 0.0) * 255).toInt());
    byteData.setUint8(7, ((analogSticks['rightTrigger'] ?? 0.0) * 255).toInt());
    // Giroscópio (Offset 8, 6 bytes)
    final gyroX = (sensors['gyroX'] ?? 0.0) * 100;
    final gyroY = (sensors['gyroY'] ?? 0.0) * 100;
    final gyroZ = (sensors['gyroZ'] ?? 0.0) * 100;
    byteData.setInt16(8, gyroX.round(), Endian.little);
    byteData.setInt16(10, gyroY.round(), Endian.little);
    byteData.setInt16(12, gyroZ.round(), Endian.little);

    // =========================================================================
    // CORREÇÃO: ADICIONANDO OS DADOS DO ACELERÔMETRO QUE FALTAVAM
    // (Offset 14, 6 bytes)
    // =========================================================================
    final accelX = (sensors['accelX'] ?? 0.0) * 100;
    final accelY = (sensors['accelY'] ?? 0.0) * 100;
    final accelZ = (sensors['accelZ'] ?? 0.0) * 100;
    byteData.setInt16(14, accelX.round(), Endian.little);
    byteData.setInt16(16, accelY.round(), Endian.little);
    byteData.setInt16(18, accelZ.round(), Endian.little);
    // =========================================================================

    return byteData.buffer.asUint8List();
}
}

class DiscoveredServer {
  final String name;
  final InternetAddress ipAddress;
  DiscoveredServer({required this.name, required this.ipAddress});
}

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  static const MethodChannel _discoveryChannel = MethodChannel('com.example.gamepadvirtual/discovery');
  static const int discoveryPort = 27016;
  static const int dataPort = 27015;
  static final _discoveryQuery = "DISCOVER_GAMEPAD_VIRTUAL_SERVER".codeUnits;
  static const String _discoveryAckPrefix = "GAMEPAD_VIRTUAL_SERVER_ACK:";

  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _discoveredServersController = StreamController<List<DiscoveredServer>>.broadcast();

  ConnectionState _currentState = ConnectionState.disconnected();
  BluetoothConnection? _bluetoothConnection;
  Socket? _dataSocket;
  RawDatagramSocket? _discoverySocket;
  final List<DiscoveredServer> _foundServers = [];

  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<DiscoveredServer>> get discoveredServersStream => _discoveredServersController.stream;
  ConnectionState get currentState => _currentState;

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

  Future<bool> connectToServer(DiscoveredServer server) async {
    await _disconnectCurrent(updateState: false);
    try {
      // CORREÇÃO: Usar ConnectionService.dataPort
      _dataSocket = await Socket.connect(server.ipAddress, ConnectionService.dataPort, timeout: const Duration(seconds: 5));
      _dataSocket!.setOption(SocketOption.tcpNoDelay, true);
      _updateConnectionState(ConnectionState.wifiDirectConnected(deviceName: '${server.name} (${server.ipAddress.address})'));
      _dataSocket!.listen((data) {}, onDone: disconnect, onError: (e) => disconnect());
      return true;
    } catch (e) {
      print("Erro ao conectar ao servidor TCP: $e");
      await _disconnectCurrent();
      return false;
    }
  }
  
  void sendGamepadData(GamepadInputData data) {
    if (!_currentState.isConnected) return;
    try {
      final Uint8List packet = data.toPacketBytes();
      if (_currentState.type == ConnectionType.bluetooth) {
        _bluetoothConnection?.output.add(packet);
      } else {
        _dataSocket?.add(packet);
      }
    } catch (e) {
      print('Erro ao enviar dados do gamepad: $e');
      disconnect();
    }
  }

  Future<void> disconnect() async {
    await _disconnectCurrent();
  }

  Future<void> _disconnectCurrent({bool updateState = true}) async {
    _bluetoothConnection?.close();
    _bluetoothConnection = null;
    _dataSocket?.destroy();
    _dataSocket = null;
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
  
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try { return await FlutterBluetoothSerial.instance.getBondedDevices(); } 
    catch (e) { return []; }
  }

  Future<bool> connectToBluetooth(BluetoothDevice device) async {
    await _disconnectCurrent(updateState: false);
    try {
      _bluetoothConnection = await BluetoothConnection.toAddress(device.address);
      _updateConnectionState(ConnectionState.bluetoothConnected(deviceName: device.name ?? 'Unknown Device', deviceAddress: device.address));
      _bluetoothConnection!.input!.listen(null, onDone: disconnect);
      return true;
    } catch (e) {
      await _disconnectCurrent();
      return false;
    }
  }
}