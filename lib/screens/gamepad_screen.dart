// lib/screens/gamepad_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';
import 'package:gamepadvirtual/services/sensor_service.dart';
import 'package:gamepadvirtual/services/gamepad_input_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:gamepadvirtual/services/gamepad_state_service.dart';
import 'package:gamepadvirtual/widgets/gamepad_layout_view.dart';

class GamepadScreen extends StatefulWidget {
  const GamepadScreen({super.key});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> {
  //region Serviços
  /// Instâncias dos serviços utilizados pela tela para gerenciar estado, conexões e hardware.
  final ConnectionService _connectionService = ConnectionService();
  final StorageService _storageService = StorageService();
  final VibrationService _vibrationService = VibrationService();
  final SensorService _sensorService = SensorService();
  final GamepadInputService _gamepadInputService = GamepadInputService();
  final GamepadStateService _gamepadState = GamepadStateService();
  //endregion

  //region Estado da Tela
  /// Variáveis que controlam o estado da interface, como status de conexão e layout.
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  models.ConnectionState _externalGamepadState = models.ConnectionState.disconnected();
  GamepadLayout _predefinedLayout = GamepadLayout.xbox;
  bool _isLoading = true;
  GamepadLayoutType _selectedLayoutType = GamepadLayoutType.xbox;
  bool _hapticFeedbackEnabled = true;
  bool _gyroscopeEnabled = true;
  bool _accelerometerEnabled = true;
  bool _rumbleEnabled = true;
  bool _externalDigitalTriggersEnabled = false;
  Timer? _gameLoopTimer;
  //endregion

  //region Mapeamento de Botões Externos
  /// Mapeia os botões de um gamepad físico para os tipos de botões internos do app,
  /// adaptando-se ao layout selecionado (Xbox, PlayStation, etc.).
  Map<String, ButtonType> get _externalGamepadMapping {
    switch (_predefinedLayout.type) {
      case GamepadLayoutType.playstation:
        return {
          'BUTTON_A': ButtonType.cross, 'BUTTON_B': ButtonType.circle, 'BUTTON_X': ButtonType.square, 'BUTTON_Y': ButtonType.triangle,
          'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper, 'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger,
          'BUTTON_LEFT_STICK': ButtonType.leftStickButton, 'BUTTON_RIGHT_STICK': ButtonType.rightStickButton, 'BUTTON_START': ButtonType.start,
          'BUTTON_SELECT': ButtonType.select, 'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp, 'DPAD_DOWN': ButtonType.dpadDown,
          'DPAD_LEFT': ButtonType.dpadLeft, 'DPAD_RIGHT': ButtonType.dpadRight,
        };
      case GamepadLayoutType.nintendo:
        return {
          'BUTTON_A': ButtonType.b, 'BUTTON_B': ButtonType.a, 'BUTTON_X': ButtonType.y, 'BUTTON_Y': ButtonType.x,
          'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper, 'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger,
          'BUTTON_LEFT_STICK': ButtonType.leftStickButton, 'BUTTON_RIGHT_STICK': ButtonType.rightStickButton, 'BUTTON_START': ButtonType.start,
          'BUTTON_SELECT': ButtonType.select, 'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp, 'DPAD_DOWN': ButtonType.dpadDown,
          'DPAD_LEFT': ButtonType.dpadLeft, 'DPAD_RIGHT': ButtonType.dpadRight,
        };
      default:
        return {
          'BUTTON_A': ButtonType.a, 'BUTTON_B': ButtonType.b, 'BUTTON_X': ButtonType.x, 'BUTTON_Y': ButtonType.y,
          'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper, 'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger,
          'BUTTON_LEFT_STICK': ButtonType.leftStickButton, 'BUTTON_RIGHT_STICK': ButtonType.rightStickButton, 'BUTTON_START': ButtonType.start,
          'BUTTON_SELECT': ButtonType.select, 'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp, 'DPAD_DOWN': ButtonType.dpadDown,
          'DPAD_LEFT': ButtonType.dpadLeft, 'DPAD_RIGHT': ButtonType.dpadRight,
        };
    }
  }
  //endregion

  //region Ciclo de Vida do Widget

  @override
  void initState() {
    super.initState();
    _initializeGamepad();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _sensorService.stopAllSensors();
    _unlockOrientation();
    WakelockPlus.disable();
    _gamepadState.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  //endregion

  //region Inicialização e Game Loop
  /// Métodos responsáveis por configurar a tela, iniciar o loop de envio de dados
  /// e gerenciar os sensores.

  Future<void> _initializeGamepad() async {
    await _gamepadInputService.initialize();
    _lockToLandscape();
    WakelockPlus.enable();
    _gamepadState.initialize();
    await _loadSettingsAndLayout();

    _gamepadInputService.connectionStream.listen((state) {
      if (mounted) setState(() => _externalGamepadState = state);
    });
    _gamepadInputService.inputStream.listen(_onExternalGamepadInput);

    if (mounted) {
      setState(() {
        _externalGamepadState = _gamepadInputService.currentState;
        _connectionState = _connectionService.currentState;
        _isLoading = false;
      });
    }
    
    _startGameLoop();
    await _startEnabledSensors();
    _sensorService.gyroscopeStream.listen(_updateGyroState);
    _sensorService.accelerometerStream.listen(_updateAccelState);
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 8), (timer) {
      if (_connectionService.currentState.isConnected && (_gamepadState.hasNewInput || _gyroscopeEnabled || _accelerometerEnabled)) {
        _sendGamepadData();
        _gamepadState.clearInputFlag();
      }
    });
  }
  
  void _updateGyroState(SensorData gyroData) {
    _gamepadState.updateGyroState(gyroData, _gyroscopeEnabled);
  }

  void _updateAccelState(SensorData accelData) {
    _gamepadState.updateAccelState(accelData, _accelerometerEnabled);
  }

  void _sendGamepadData() {
    final data = _gamepadState.getGamepadInputData();
    _connectionService.sendGamepadData(data);
  }
  //endregion

  //region Funções de Configuração (Toggles)
  /// Métodos para ativar/desativar funcionalidades e persistir a escolha no armazenamento.
  Future<void> _toggleHapticFeedback(bool enabled) async { 
    await _storageService.setHapticFeedbackEnabled(enabled); 
    setState(() => _hapticFeedbackEnabled = enabled); 
  }
  
  Future<void> _toggleRumble(bool enabled) async { 
    await _storageService.setRumbleEnabled(enabled); 
    setState(() => _rumbleEnabled = enabled); 
  }
  
  Future<void> _toggleGyroscope(bool enabled) async { 
    await _storageService.setGyroscopeEnabled(enabled); 
    setState(() => _gyroscopeEnabled = enabled); 
    if(enabled) { _sensorService.startGyroscope(); } 
    else { 
      _sensorService.stopGyroscope(); 
      _gamepadState.updateGyroState(SensorData(x:0, y:0, z:0, timestamp: DateTime.now()), false);
    } 
  }
  
  Future<void> _toggleAccelerometer(bool enabled) async { 
    await _storageService.setAccelerometerEnabled(enabled); 
    setState(() => _accelerometerEnabled = enabled); 
    if(enabled) { _sensorService.startAccelerometer(); } 
    else { 
      _sensorService.stopAccelerometer(); 
      _gamepadState.updateAccelState(SensorData(x:0, y:0, z:0, timestamp: DateTime.now()), false);
    } 
  }

  Future<void> _toggleExternalDigitalTriggers(bool enabled) async { 
    await _storageService.setExternalDigitalTriggersEnabled(enabled); 
    setState(() => _externalDigitalTriggersEnabled = enabled); 
  }
  //endregion

  //region Construção da UI

  @override
  Widget build(BuildContext context) {
    final bool isExternalMode = _externalGamepadState.isConnected && _externalGamepadState.isExternalGamepad;
    
    return Scaffold(
      backgroundColor: isExternalMode ? Colors.black : Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : isExternalMode
                ? _buildExternalGamepadView()
                : _buildPredefinedGamepadView(),
      ),
    );
  }

  void _showSettingsPanel() {
    /// Determina se o modo de gamepad externo está ativo para customizar o painel.
    final bool isExternalMode = _externalGamepadState.isConnected && _externalGamepadState.isExternalGamepad;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text('Configurações', style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(),
                  /// Só mostra a opção de "Resposta Tátil" se não estiver em modo de gamepad externo.
                  if (!isExternalMode)
                    SwitchListTile(
                      title: const Text('Resposta Tátil'),
                      subtitle: const Text('Vibra ao tocar nos botões virtuais.'),
                      value: _hapticFeedbackEnabled,
                      onChanged: (value) {
                        _toggleHapticFeedback(value);
                        setModalState(() {});
                      },
                    ),
                  SwitchListTile(
                    title: const Text('Vibração do Jogo (Rumble)'),
                    subtitle: const Text('Recebe e reproduz a vibração enviada pelo jogo.'),
                    value: _rumbleEnabled,
                    onChanged: (value) {
                       _toggleRumble(value);
                       setModalState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Giroscópio'),
                    subtitle: const Text('Envia os dados de rotação para o PC.'),
                    value: _gyroscopeEnabled,
                    onChanged: (value) {
                       _toggleGyroscope(value);
                       setModalState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Acelerômetro'),
                    subtitle: const Text('Envia os dados de movimento para o PC.'),
                    value: _accelerometerEnabled,
                    onChanged: (value) {
                      _toggleAccelerometer(value);
                      setModalState(() {});
                    },
                  ),
                  const Divider(),
                  /// Mostra a opção de gatilhos digitais apenas quando um gamepad externo está conectado.
                  if (isExternalMode)
                    SwitchListTile(
                      title: const Text('Gatilhos Digitais (Externo)'),
                      subtitle: const Text('Qualquer pressão ( > 10%) ativa 100% do gatilho.'),
                      value: _externalDigitalTriggersEnabled,
                      onChanged: (value) {
                        _toggleExternalDigitalTriggers(value);
                        setModalState(() {});
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  //endregion

  //region Manipulação de Entradas
  /// Processa os dados recebidos de um gamepad físico externo.
  void _onExternalGamepadInput(Map<String, dynamic> input) {
    try {
      if (input.containsKey('buttons')) {
        _gamepadState.updateButtonsFromExternal(
          Map<String, bool>.from(input['buttons']),
          _externalGamepadMapping
        );
      }
      if (input.containsKey('analog')) {
        _gamepadState.updateAnalogsFromExternal(
          Map<String, double>.from(input['analog']),
          digitalTriggersEnabled: _externalDigitalTriggersEnabled,
        );
      }
    } catch (e) {
      print('Error processing external gamepad input: $e');
    }
  }
  //endregion

  //region Carregamento de Configurações
  /// Carrega as configurações salvas e o layout do controle ao iniciar a tela.
  Future<void> _loadSettingsAndLayout() async {
    _hapticFeedbackEnabled = await _storageService.isHapticFeedbackEnabled();
    _gyroscopeEnabled = await _storageService.isGyroscopeEnabled();
    _accelerometerEnabled = await _storageService.isAccelerometerEnabled();
    _rumbleEnabled = await _storageService.isRumbleEnabled();
    _externalDigitalTriggersEnabled = await _storageService.isExternalDigitalTriggersEnabled();
    
    final layoutType = await _storageService.getSelectedLayout();
    _selectedLayoutType = layoutType; 

    if (layoutType == GamepadLayoutType.custom) {
      final baseType = await _storageService.getCustomLayoutBase();
      _predefinedLayout = GamepadLayout.predefinedLayouts
          .firstWhere((l) => l.type == baseType, orElse: () => GamepadLayout.xbox);
    } else {
      _predefinedLayout = GamepadLayout.predefinedLayouts.firstWhere(
        (l) => l.type == layoutType, 
        orElse: () => GamepadLayout.xbox
      );
    }
  }

  Future<void> _startEnabledSensors() async {
    if (_gyroscopeEnabled) await _sensorService.startGyroscope();
    if (_accelerometerEnabled) await _sensorService.startAccelerometer();
  }
  //endregion

  //region Utilitários de Orientação
  void _lockToLandscape() => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  void _unlockOrientation() => SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  //endregion

  //region Widgets da Tela
  Widget _buildExternalGamepadView() {
    /// Constrói a interface para o modo de gamepad externo, que é mais informativa.
    return Stack(
      children: [
        Positioned(
          top: 10,
          left: 10,
          child: IconButton(
            onPressed: () { 
              _unlockOrientation(); 
              Navigator.pop(context); 
            },
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withAlpha(200),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            onPressed: _showSettingsPanel,
            icon: const Icon(Icons.settings),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withAlpha(200),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: ConnectionStatusWidget(
              connectionState: _connectionState,
              showDetails: true,
            ),
          ),
        ),
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConnectionStatusWidget(connectionState: _externalGamepadState),
                  const SizedBox(height: 24),
                  const Icon(Icons.sports_esports, size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'Modo Gamepad Externo Ativo', 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os inputs do seu controle físico estão sendo enviados para o PC.', 
                    textAlign: TextAlign.center, 
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[400])
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredefinedGamepadView() {
    /// Constrói a interface do gamepad virtual padrão.
    return Stack(
      children: [
        GamepadLayoutView(
          gamepadState: _gamepadState,
          vibrationService: _vibrationService,
          storageService: _storageService,
          layout: _predefinedLayout,
          hapticFeedbackEnabled: _hapticFeedbackEnabled,
          layoutType: _selectedLayoutType,
          onShowSettings: _showSettingsPanel,
        ),
        Positioned(
          top: 10,
          left: 10,
          child: IconButton(
            onPressed: () {
              _unlockOrientation();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(230)),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: ConnectionStatusWidget(
              connectionState: _connectionState,
              showDetails: false,
            ),
          ),
        ),
      ],
    );
  }
  //endregion
}