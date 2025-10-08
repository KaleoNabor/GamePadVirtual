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
  final StreamController<String> _serviceStatusController =
      StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get inputStream => _inputController.stream;
  Stream<ConnectionState> get connectionStream => _connectionController.stream;
  Stream<String> get serviceStatusStream => _serviceStatusController.stream;

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
      print('Erro ao inicializar detecção de gamepad: $e');
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

      case 'onServiceStatus':
        final status = call.arguments['status'] ?? '';
        _serviceStatusController.add(status);
        print('Status do serviço: $status');
        break;
    }
  }

  // Método para iniciar manualmente o serviço de gamepad
  Future<void> startGamepadService({required bool hapticsEnabled}) async {
    try {
      // MODIFICADO: Passamos a configuração como um argumento para o lado nativo.
      await _channel.invokeMethod('startGamepadService', {'hapticsEnabled': hapticsEnabled});
      _serviceStatusController.add("STARTED"); 
    } catch (e) {
      print('Erro ao iniciar serviço de gamepad: $e');
    }
  }

  // Método para parar manualmente o serviço de gamepad
  // MODIFICADO: Este método agora é o principal para parar o serviço em Kotlin.
  Future<void> stopGamepadService() async {
    try {
      await _channel.invokeMethod('stopGamepadService');
      // ADICIONADO: Avisa o Dart que o serviço foi parado.
      _serviceStatusController.add("STOPPED");
    } catch (e) {
      print('Erro ao parar serviço de gamepad: $e');
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

  bool get isExternalGamepadConnected =>
      _currentState.isConnected && _currentState.isExternalGamepad;

  void dispose() {
    _inputController.close();
    _connectionController.close();
    _serviceStatusController.close();
  }
}