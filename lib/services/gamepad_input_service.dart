import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gamepadvirtual/models/connection_state.dart';

class GamepadInputService {
  static const MethodChannel _channel = MethodChannel('gamepad_input_channel');
  static final GamepadInputService _instance = GamepadInputService._internal();

  factory GamepadInputService() => _instance;
  GamepadInputService._internal();

  final StreamController<Map<String, dynamic>> _inputController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<ConnectionState> _connectionController =
      StreamController<ConnectionState>.broadcast();

  Stream<Map<String, dynamic>> get inputStream => _inputController.stream;
  Stream<ConnectionState> get connectionStream => _connectionController.stream;

  bool _isInitialized = false;
  ConnectionState _currentState = ConnectionState.disconnected();

  Future<void> initialize() async {
  if (_isInitialized) return;

  try {
    _channel.setMethodCallHandler(_handleMethodCall);
    await _channel.invokeMethod('initializeGamepadDetection');

    // CORREÇÃO: Pergunta ativamente ao código nativo se um gamepad já está conectado.
    final dynamic initialState = await _channel.invokeMethod('getInitialGamepadState');
    if (initialState != null) {
      final deviceName = initialState['deviceName'] ?? 'Gamepad Externo';
      _currentState =
          ConnectionState.externalGamepadConnected(deviceName: deviceName);
      _connectionController.add(_currentState);
    }
    
    _isInitialized = true;

    print('Gamepad Input Service inicializado');
  } catch (e) {
    print('Erro ao inicializar Gamepad Input Service: $e');
  }
}

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onGamepadConnected':
        final deviceName = call.arguments['deviceName'] ?? 'Gamepad Externo';
        _currentState =
            ConnectionState.externalGamepadConnected(deviceName: deviceName);
        _connectionController.add(_currentState);
        break;

      case 'onGamepadDisconnected':
        _currentState = ConnectionState.disconnected();
        _connectionController.add(_currentState);
        break;

      case 'onGamepadInput':
        final inputData = Map<String, dynamic>.from(call.arguments);
        _inputController.add(inputData);
        break;

      case 'onVibrationCommand':
        final pattern = List<int>.from(call.arguments['pattern'] ?? [100]);
        // TODO: Encaminhar para vibration service
        break;
    }
  }

  Future<void> sendGamepadData(Map<String, dynamic> data) async {
    if (!_currentState.isExternalGamepad) return;

    try {
      await _channel.invokeMethod('sendGamepadData', data);
    } catch (e) {
      print('Erro ao enviar dados do gamepad: $e');
    }
  }

  ConnectionState get currentState => _currentState;

  // MODIFICADO: Removido getter duplicado
  bool get isExternalGamepadConnected =>
      _currentState.isConnected && _currentState.isExternalGamepad;

  void dispose() {
    _inputController.close();
    _connectionController.close();
  }
}