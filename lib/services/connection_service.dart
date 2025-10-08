import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:gamepadvirtual/models/connection_state.dart';
import 'package:gamepadvirtual/services/gamepad_input_service.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';

class GamepadInputData {
  final Map<String, bool> buttons;
  final Map<String, double> analogSticks;
  final Map<String, dynamic> sensors;
  final DateTime timestamp;

  GamepadInputData({
    required this.buttons,
    required this.analogSticks,
    required this.sensors,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'buttons': buttons,
      'analogSticks': analogSticks,
      'sensors': sensors,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal() {
    _initialize();
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices;
    } catch (e) {
      print('Erro ao obter dispositivos pareados: $e');
      return [];
    }
  }

  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  final GamepadInputService _gamepadInputService = GamepadInputService();
  final VibrationService _vibrationService = VibrationService();

  final StreamController<bool> _externalGamepadStatusController =
      StreamController<bool>.broadcast();

  ConnectionState _currentState = ConnectionState.disconnected();
  BluetoothConnection? _bluetoothConnection;
  UsbPort? _usbPort;
  Timer? _heartbeatTimer;
  bool _isInitialized = false;

  Stream<bool> get externalGamepadStatusStream =>
      _externalGamepadStatusController.stream;

  Stream<ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  ConnectionState get currentState => _currentState;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    await _gamepadInputService.initialize();
    _isInitialized = true;
  }

  void _onExternalGamepadStateChanged(ConnectionState state) {
    if (state.isExternalGamepad && state.isConnected) {
      // Em vez de desconectar, apenas notificamos que o modo gamepad externo está ATIVO
      _externalGamepadStatusController.add(true);
    } else if (!state.isConnected) {
      // Notificamos que o modo gamepad externo está INATIVO
      _externalGamepadStatusController.add(false);
    }
  }

  Future<List<BluetoothDevice>> getBluetoothDevices() async {
    try {
      final isEnabled =
          await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      final devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices
          .where((device) => device.name != null && device.name!.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error getting Bluetooth devices: $e');
      return [];
    }
  }

  Future<bool> connectToBluetooth(BluetoothDevice device) async {
    try {
      await _disconnectCurrent();

      _bluetoothConnection =
          await BluetoothConnection.toAddress(device.address);

      _updateConnectionState(ConnectionState.bluetoothConnected(
        deviceName: device.name ?? 'Unknown Device',
        deviceAddress: device.address,
      ));

      _startHeartbeat();
      _setupBluetoothListeners();
      return true;
    } catch (e) {
      print('Error connecting to Bluetooth: $e');
      _updateConnectionState(ConnectionState.disconnected());
      return false;
    }
  }

  void _setupBluetoothListeners() {
    _bluetoothConnection?.input?.listen((Uint8List data) {
      try {
        final command = utf8.decode(data);
        final json = jsonDecode(command);

        if (json['type'] == 'vibration') {
          final pattern = List<int>.from(json['pattern'] ?? [100]);
          _vibrationService.vibratePattern(pattern);
        }
      } catch (e) {
        print('Error parsing Bluetooth data: $e');
      }
    }).onError((error) {
      print('Bluetooth connection error: $error');
      disconnect();
    });
  }

  Future<bool> connectToUSB() async {
    try {
      await _disconnectCurrent();

      List<UsbDevice> devices = await UsbSerial.listDevices();

      if (devices.isEmpty) {
        throw Exception('Nenhum dispositivo USB encontrado');
      }

      UsbDevice device = devices.first;
      _usbPort = await device.create();

      if (!await _usbPort!.open()) {
        throw Exception('Falha ao abrir porta USB');
      }

      await _usbPort!.setDTR(true);
      await _usbPort!.setRTS(true);
      await _usbPort!
          .setPortParameters(115200, 8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

      _updateConnectionState(ConnectionState.usbConnected(
        deviceName: device.productName ?? 'Dispositivo USB',
      ));

      _startHeartbeat();
      _startUSBListening();
      return true;
    } catch (e) {
      print('Error connecting to USB: $e');
      _updateConnectionState(ConnectionState.disconnected());
      return false;
    }
  }
  
  void _startUSBListening() {
    _usbPort?.inputStream?.listen((Uint8List data) {
      try {
        final command = utf8.decode(data);
        final json = jsonDecode(command);

        if (json['type'] == 'vibration') {
          final pattern = List<int>.from(json['pattern'] ?? [100]);
          _vibrationService.vibratePattern(pattern);
        }
      } catch (e) {
        print('Error parsing USB data: $e');
      }
    });
  }

  Future<void> sendGamepadData(GamepadInputData data) async {
    if (!_currentState.isConnected) return;

    try {
      final jsonData = jsonEncode(data.toJson());
      
      switch (_currentState.type) {
        case ConnectionType.bluetooth:
          if (_bluetoothConnection != null && _bluetoothConnection!.isConnected) {
            _bluetoothConnection!.output
                .add(Uint8List.fromList(utf8.encode(jsonData)));
            await _bluetoothConnection!.output.allSent;
          }
          break;
        case ConnectionType.usb:
          if (_usbPort != null) {
            _usbPort!.write(Uint8List.fromList(utf8.encode('$jsonData\n')));
          }
          break;
        case ConnectionType.externalGamepad:
          break;
        // CORRIGIDO: Adicionado case para wifiDirect
        case ConnectionType.wifiDirect:
          break;
        case ConnectionType.none:
          break;
      }
    } catch (e) {
      print('Error sending gamepad data: $e');
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    await _disconnectCurrent();
    _updateConnectionState(ConnectionState.disconnected());
  }

  Future<void> _disconnectCurrent() async {
    _stopHeartbeat();

    if (_bluetoothConnection != null) {
      try {
        await _bluetoothConnection!.close();
      } catch (e) {
        print('Error closing Bluetooth connection: $e');
      } finally {
        _bluetoothConnection = null;
      }
    }

    if (_usbPort != null) {
      try {
        await _usbPort!.close();
      } catch (e) {
        print('Error closing USB connection: $e');
      } finally {
        _usbPort = null;
      }
    }
  }

  void _updateConnectionState(ConnectionState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnection();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _checkConnection() async {
    if (!_currentState.isConnected) return;

    bool isConnected = false;
    
    // CORRIGIDO: Adicionado case para wifiDirect
    switch (_currentState.type) {
      case ConnectionType.bluetooth:
        isConnected = _bluetoothConnection?.isConnected ?? false;
        break;
      case ConnectionType.usb:
        isConnected = _usbPort != null;
        break;
      case ConnectionType.externalGamepad:
        isConnected = _gamepadInputService.isExternalGamepadConnected;
        break;
      case ConnectionType.wifiDirect:
        isConnected = true; // Simulação
        break;
      case ConnectionType.none:
        isConnected = false;
        break;
    }
    if (!isConnected) {
      await disconnect();
    }
  }

  Future<void> openBluetoothSettings() async {
    try {
      await FlutterBluetoothSerial.instance.openSettings();
    } catch (e) {
      print('Error opening Bluetooth settings: $e');
    }
  }

  void dispose() {
    _disconnectCurrent();
    _connectionStateController.close();
    _gamepadInputService.dispose();
  }
}