import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gamepadvirtual/models/connection_state.dart';
import 'package:flutter/foundation.dart';

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

      final dynamic initialState = await _channel.invokeMethod('getInitialGamepadState');
      if (initialState != null) {
        final deviceName = initialState['deviceName'] ?? 'Gamepad Externo';
        _currentState =
            ConnectionState.externalGamepadConnected(deviceName: deviceName);
        _connectionController.add(_currentState);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Erro ao inicializar detecção de gamepad: $e');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onGamepadConnected':
        final deviceName = call.arguments['deviceName'] ?? 'Gamepad Externo';
        final newState =
            ConnectionState.externalGamepadConnected(deviceName: deviceName);
        _currentState = newState;
        _connectionController.add(newState);
        break;

      case 'onGamepadDisconnected':
        final newState = ConnectionState.disconnected();
        _currentState = newState;
        _connectionController.add(newState);
        break;

      case 'onGamepadInput':
        final inputData = Map<String, dynamic>.from(call.arguments);
        _inputController.add(inputData);
        break;

    }
  }


  // Esta função envia dados PARA um gamepad externo (ex: rumble), não para o PC.
  // A deixamos aqui para usos futuros.
  Future<void> sendRumbleData(Map<String, dynamic> data) async {
    if (!_currentState.isExternalGamepad) return;

    try {
      // O nome do método aqui é um exemplo, teríamos que implementar no lado nativo
      await _channel.invokeMethod('sendRumbleData', data);
    } catch (e) {
      debugPrint('Erro ao enviar dados de rumble: $e');
    }
  }

  ConnectionState get currentState => _currentState;

  bool get isExternalGamepadConnected =>
      _currentState.isConnected && _currentState.isExternalGamepad;

  void dispose() {
    _inputController.close();
    _connectionController.close();
  }
}