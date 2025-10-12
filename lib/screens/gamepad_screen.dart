import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/models/custom_layout.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';
import 'package:gamepadvirtual/services/sensor_service.dart';
import 'package:gamepadvirtual/services/gamepad_input_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';
import 'package:gamepadvirtual/widgets/analog_stick.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class GamepadScreen extends StatefulWidget {
  const GamepadScreen({super.key});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> {
  // SERVICES
  final ConnectionService _connectionService = ConnectionService();
  final StorageService _storageService = StorageService();
  final VibrationService _vibrationService = VibrationService();
  final SensorService _sensorService = SensorService();
  final GamepadInputService _gamepadInputService = GamepadInputService();

  // STATE
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  models.ConnectionState _externalGamepadState = models.ConnectionState.disconnected();
  GamepadLayout _predefinedLayout = GamepadLayout.xbox;
  CustomLayout? _customLayout;
  bool get _isCustomLayout => _customLayout != null;
  bool _isLoading = true;

  // INPUT STATE
  final Map<ButtonType, bool> _buttonStates = {};
  double _leftStickX = 0, _leftStickY = 0;
  double _rightStickX = 0, _rightStickY = 0;
  double _leftTriggerValue = 0.0, _rightTriggerValue = 0.0;
  
  // SENSOR STATE
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;
  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;
  
  // SETTINGS STATE
  bool _hapticFeedbackEnabled = true;
  bool _gyroscopeEnabled = true;
  bool _accelerometerEnabled = true;
  bool _rumbleEnabled = true;
  bool _isBackgroundServiceRunning = false;

  Timer? _gameLoopTimer;
  bool _hasNewInput = false;

  Map<String, ButtonType> get _externalGamepadMapping {
    final layoutType = _isCustomLayout ? GamepadLayoutType.custom : _predefinedLayout.type;
    switch (layoutType) {
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

  @override
  void initState() {
    super.initState();
    _initializeGamepad();
  }

  Future<void> _initializeGamepad() async {
    await _gamepadInputService.initialize();
    _lockToLandscape();
    WakelockPlus.enable();
    _initializeAllButtonStates();
    await _loadSettingsAndLayout();

    _gamepadInputService.connectionStream.listen((state) {
      if (mounted) setState(() => _externalGamepadState = state);
    });
    _gamepadInputService.inputStream.listen(_onExternalGamepadInput);
    
    _gamepadInputService.serviceStatusStream.listen((status) {
      if(mounted) {
        setState(() => _isBackgroundServiceRunning = (status == "STARTED"));
      }
    });

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
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (_connectionService.currentState.isConnected && (_hasNewInput || _gyroscopeEnabled || _accelerometerEnabled)) {
        _sendGamepadData();
        _hasNewInput = false;
      }
    });
  }
  
  void _updateGyroState(SensorData gyroData) {
    if (_gyroscopeEnabled) {
      _gyroX = gyroData.x; _gyroY = gyroData.y; _gyroZ = gyroData.z;
    }
  }

  void _updateAccelState(SensorData accelData) {
    if (_accelerometerEnabled) {
      _accelX = accelData.x; _accelY = accelData.y; _accelZ = accelData.z;
    }
  }
  
  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _sensorService.stopAllSensors();
    _unlockOrientation();
    WakelockPlus.disable();
    if(_isBackgroundServiceRunning) {
      _gamepadInputService.stopGamepadService();
    }
    super.dispose();
  }
  
  void _onButtonPressed(ButtonType buttonType) {
    if (buttonType == ButtonType.leftTrigger) {
      setState(() => _leftTriggerValue = 1.0);
    } else if (buttonType == ButtonType.rightTrigger) {
      setState(() => _rightTriggerValue = 1.0);
    } else {
      setState(() => _buttonStates[buttonType] = true);
    }
    _hasNewInput = true;
    if (_hapticFeedbackEnabled) _vibrationService.vibrateForButton();
  }

  void _onButtonReleased(ButtonType buttonType) {
    if (buttonType == ButtonType.leftTrigger) {
      setState(() => _leftTriggerValue = 0.0);
    } else if (buttonType == ButtonType.rightTrigger) {
      setState(() => _rightTriggerValue = 0.0);
    } else {
      setState(() => _buttonStates[buttonType] = false);
    }
    _hasNewInput = true;
  }
  
  void _onAnalogStickChanged(bool isLeft, double x, double y) {
    if (isLeft) {
      setState(() { _leftStickX = x; _leftStickY = y; });
    } else {
      setState(() { _rightStickX = x; _rightStickY = y; });
    }
    _hasNewInput = true;
  }
  
  void _sendGamepadData() {
    final data = GamepadInputData(
      buttons: _buttonStates,
      analogSticks: {
        'leftX': _leftStickX, 'leftY': _leftStickY,
        'rightX': _rightStickX, 'rightY': _rightStickY,
        'leftTrigger': _leftTriggerValue, 'rightTrigger': _rightTriggerValue,
      },
      sensors: {
        'gyroX': _gyroX, 'gyroY': _gyroY, 'gyroZ': _gyroZ,
        'accelX': _accelX, 'accelY': _accelY, 'accelZ': _accelZ,
      },
      timestamp: DateTime.now(),
    );
    _connectionService.sendGamepadData(data);
  }

  // ======================================================================
  // --- FUNÇÕES DE TOGGLE QUE VINCULAM AS CHAVES À LÓGICA ---
  // ======================================================================

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
    else { _sensorService.stopGyroscope(); _gyroX = _gyroY = _gyroZ = 0.0;} 
  }
  
  Future<void> _toggleAccelerometer(bool enabled) async { 
    await _storageService.setAccelerometerEnabled(enabled); 
    setState(() => _accelerometerEnabled = enabled); 
    if(enabled) { _sensorService.startAccelerometer(); } 
    else { _sensorService.stopAccelerometer(); _accelX = _accelY = _accelZ = 0.0; } 
  }

  Future<void> _toggleBackgroundMode(bool enabled) async {
    setState(() => _isBackgroundServiceRunning = enabled);
    if(enabled) {
      _gamepadInputService.startGamepadService(hapticsEnabled: _hapticFeedbackEnabled);
    } else {
      _gamepadInputService.stopGamepadService();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isExternalMode = _externalGamepadState.isConnected && _externalGamepadState.isExternalGamepad;
    
    return Scaffold(
      backgroundColor: isExternalMode ? Colors.black : Theme.of(context).colorScheme.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: _showSettingsPanel,
        child: const Icon(Icons.settings),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : isExternalMode
                ? _buildExternalGamepadView()
                : _isCustomLayout
                    ? _buildCustomGamepadView()
                    : _buildPredefinedGamepadView(),
      ),
    );
  }

  void _showSettingsPanel() {
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
                   SwitchListTile(
                    title: const Text('Funcionar em Segundo Plano'),
                    subtitle: const Text('Mantém o controle ativo com o app minimizado.'),
                    value: _isBackgroundServiceRunning,
                    onChanged: (value) {
                      _toggleBackgroundMode(value);
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
  
  void _onExternalGamepadInput(Map<String, dynamic> input) {
    try {
      if (input.containsKey('buttons')) {
        _updateButtonStatesFromExternal(Map<String, bool>.from(input['buttons']));
      }
      if (input.containsKey('analog')) {
        _updateAnalogStatesFromExternal(Map<String, double>.from(input['analog']));
      }
      _hasNewInput = true;
    } catch (e) {
      print('Error processing external gamepad input: $e');
    }
  }

  void _updateButtonStatesFromExternal(Map<String, bool> externalButtons) {
    setState(() {
      externalButtons.forEach((key, isPressed) {
        final buttonType = _externalGamepadMapping[key];
        if (buttonType != null) {
          if (buttonType == ButtonType.leftTrigger) {
            _leftTriggerValue = isPressed ? 1.0 : 0.0;
          } else if (buttonType == ButtonType.rightTrigger) {
            _rightTriggerValue = isPressed ? 1.0 : 0.0;
          } else {
            _buttonStates[buttonType] = isPressed;
          }
        }
      });
    });
  }

  void _updateAnalogStatesFromExternal(Map<String, double> analogData) {
    setState(() {
      _leftStickX = analogData['leftX'] ?? _leftStickX;
      _leftStickY = analogData['leftY'] ?? _leftStickY;
      _rightStickX = analogData['rightX'] ?? _rightStickX;
      _rightStickY = analogData['rightY'] ?? _rightStickY;
      _leftTriggerValue = analogData['leftTrigger'] ?? _leftTriggerValue;
      _rightTriggerValue = analogData['rightTrigger'] ?? _rightTriggerValue;
      
      final dpadX = analogData['dpadX'] ?? 0.0;
      final dpadY = analogData['dpadY'] ?? 0.0;
      _buttonStates[ButtonType.dpadUp] = dpadY < -0.5;
      _buttonStates[ButtonType.dpadDown] = dpadY > 0.5;
      _buttonStates[ButtonType.dpadLeft] = dpadX < -0.5;
      _buttonStates[ButtonType.dpadRight] = dpadX > 0.5;
    });
  }

  Future<void> _loadSettingsAndLayout() async {
    _hapticFeedbackEnabled = await _storageService.isHapticFeedbackEnabled();
    _gyroscopeEnabled = await _storageService.isGyroscopeEnabled();
    _accelerometerEnabled = await _storageService.isAccelerometerEnabled();
    _rumbleEnabled = await _storageService.isRumbleEnabled();
    
    final layoutType = await _storageService.getSelectedLayout();
    if (layoutType == GamepadLayoutType.custom) {
      final customLayouts = await _storageService.getCustomLayouts();
      _customLayout = customLayouts.isNotEmpty ? customLayouts.first : null;
    } else {
      _customLayout = null;
      _predefinedLayout = GamepadLayout.predefinedLayouts.firstWhere((l) => l.type == layoutType, orElse: () => GamepadLayout.xbox);
    }
  }

  Future<void> _startEnabledSensors() async {
    if (_gyroscopeEnabled) await _sensorService.startGyroscope();
    if (_accelerometerEnabled) await _sensorService.startAccelerometer();
  }

  void _initializeAllButtonStates() {
    for (final type in ButtonType.values) { _buttonStates[type] = false; }
  }

  void _lockToLandscape() => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  void _unlockOrientation() => SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  
  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildExternalGamepadView() {
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

  // Os métodos restantes (_buildCustomGamepadView, _buildPredefinedGamepadView, etc.)
  // permanecem exatamente como estavam no código anterior...

  Widget _buildCustomGamepadView() {
    if (_customLayout == null) {
      return const Center(child: Text('Layout customizado não encontrado.'));
    }
    final screenSize = MediaQuery.of(context).size;
    final layout = _customLayout!;
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
            style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(230)),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: ConnectionStatusWidget(connectionState: _connectionState),
          ),
        ),
        if (layout.hasLeftStick)
          Positioned(
            left: layout.leftStickPosition.x * screenSize.width,
            top: layout.leftStickPosition.y * screenSize.height,
            child: AnalogStick(
              size: layout.leftStickPosition.size * screenSize.height,
              label: 'L',
              isLeft: true,
              onChanged: (x, y) => _onAnalogStickChanged(true, x, y),
            ),
          ),
        if (layout.hasRightStick)
          Positioned(
            left: layout.rightStickPosition.x * screenSize.width,
            top: layout.rightStickPosition.y * screenSize.height,
            child: AnalogStick(
              size: layout.rightStickPosition.size * screenSize.height,
              label: 'R',
              isLeft: false,
              onChanged: (x, y) => _onAnalogStickChanged(false, x, y),
            ),
          ),
        ...layout.buttons.map((button) {
          final absolutePosition = ButtonPosition(
            x: button.position.x * screenSize.width,
            y: button.position.y * screenSize.height,
            size: button.position.size * screenSize.height,
            width: button.position.width != null ? button.position.width! * screenSize.height : null,
          );
          return Positioned(
            left: absolutePosition.x,
            top: absolutePosition.y,
            child: _buildDynamicButton(button.copyWith(position: absolutePosition)),
          );
        }),
      ],
    );
  }

  Widget _buildPredefinedGamepadView() {
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
        Positioned(
          left: 40,
          bottom: 40,
          child: AnalogStick(
            size: 120,
            label: 'L',
            isLeft: true,
            onChanged: (x, y) => _onAnalogStickChanged(true, x, y),
          )
        ),
        Positioned(left: 180, bottom: 60, child: _buildDPad()),
        Positioned(left: 60, top: 60, child: _buildTriggerButton('L2', ButtonType.leftTrigger)),
        Positioned(left: 60, top: 95, child: _buildShoulderButton('L1', ButtonType.leftBumper)),
        Positioned(left: 130, bottom: 20, child: _buildStickButton('L3', ButtonType.leftStickButton)),
        Positioned(
          right: 40,
          bottom: 40,
          child: AnalogStick(
            size: 120,
            label: 'R',
            isLeft: false,
            onChanged: (x, y) => _onAnalogStickChanged(false, x, y),
          )
        ),
        Positioned(right: 180, bottom: 60, child: _buildActionButtons()),
        Positioned(right: 60, top: 60, child: _buildTriggerButton('R2', ButtonType.rightTrigger)),
        Positioned(right: 60, top: 95, child: _buildShoulderButton('R1', ButtonType.rightBumper)),
        Positioned(right: 130, bottom: 20, child: _buildStickButton('R3', ButtonType.rightStickButton)),
        Positioned(
          top: 70,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSystemButton('SELECT', ButtonType.select),
              const SizedBox(width: 60),
              _buildSystemButton('START', ButtonType.start),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicButton(CustomLayoutButton button) {
    final isShoulder = _isShoulderButton(button.type);
    final isDpad = _isDpad(button.type);
    final isSystem = button.type == ButtonType.select || button.type == ButtonType.start;
    
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(button.type),
      onTapUp: (_) => _onButtonReleased(button.type),
      onTapCancel: () => _onButtonReleased(button.type),
      child: Container(
        width: button.position.width ?? button.position.size,
        height: button.position.size,
        decoration: BoxDecoration(
          color: isDpad ? Colors.grey.shade800 : Color(button.color),
          borderRadius: BorderRadius.circular(isShoulder || isSystem || isDpad ? 12 : 100),
        ),
        child: Center(
          child: _buildButtonChild(button)
        ),
      ),
    );
  }

  bool _isShoulderButton(ButtonType t) => t == ButtonType.leftBumper || t == ButtonType.rightBumper || t == ButtonType.leftTrigger || t == ButtonType.rightTrigger;
  bool _isDpad(ButtonType t) => t == ButtonType.dpadUp || t == ButtonType.dpadDown || t == ButtonType.dpadLeft || t == ButtonType.dpadRight;
  
  Widget _buildButtonChild(CustomLayoutButton button) {
    Color textColor = _getTextColor(Color(button.color));
    double size = button.position.size;
    
    if (_isDpad(button.type)) {
      IconData icon;
      switch (button.type) {
        case ButtonType.dpadUp: icon = Icons.keyboard_arrow_up; break;
        case ButtonType.dpadDown: icon = Icons.keyboard_arrow_down; break;
        case ButtonType.dpadLeft: icon = Icons.keyboard_arrow_left; break;
        default: icon = Icons.keyboard_arrow_right;
      }
      return Icon(icon, color: Colors.white, size: size * 0.8);
    }
    
    return Text(
      button.label,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.5,
      ),
    );
  }

  Widget _buildDPad() {
    return SizedBox(
      width: 120, 
      height: 120,
      child: Stack(
        children: [
          Positioned(top: 0, left: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_up, ButtonType.dpadUp)),
          Positioned(bottom: 0, left: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_down, ButtonType.dpadDown)),
          Positioned(left: 0, top: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_left, ButtonType.dpadLeft)),
          Positioned(right: 0, top: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_right, ButtonType.dpadRight)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final buttons = _predefinedLayout.buttons;
    return SizedBox(
      width: 120, 
      height: 120,
      child: Stack(
        children: [
          if (buttons.isNotEmpty) Positioned(top: 0, left: 40, child: _buildGamepadButton(buttons[0])),
          if (buttons.length > 1) Positioned(right: 0, top: 40, child: _buildGamepadButton(buttons[1])),
          if (buttons.length > 2) Positioned(bottom: 0, left: 40, child: _buildGamepadButton(buttons[2])),
          if (buttons.length > 3) Positioned(left: 0, top: 40, child: _buildGamepadButton(buttons[3])),
        ],
      ),
    );
  }

  Widget _buildGamepadButton(GamepadButton button) {
    final isPressed = _buttonStates[button.type] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(button.type),
      onTapUp: (_) => _onButtonReleased(button.type),
      onTapCancel: () => _onButtonReleased(button.type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Color(button.color),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: isPressed ? [] : [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 4,
              offset: const Offset(0, 2)
            )
          ],
        ),
        child: Center(
          child: Text(
            button.label,
            style: TextStyle(
              color: _getTextColor(Color(button.color)),
              fontWeight: FontWeight.bold,
              fontSize: 18
            )
          ),
        ),
      ),
    );
  }
  
  Widget _buildDirectionalButton(IconData icon, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildShoulderButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 100,
        height: 40,
        decoration: BoxDecoration(
          color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold
            )
          )
        ),
      ),
    );
  }

  Widget _buildTriggerButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 90,
        height: 30,
        decoration: BoxDecoration(
          color: isPressed ? Colors.grey.shade500 : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold
            )
          )
        ),
      ),
    );
  }

  Widget _buildStickButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPressed ? Colors.blue.shade600 : Colors.grey.shade800,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold
            )
          )
        ),
      ),
    );
  }

  Widget _buildSystemButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 80,
        height: 25,
        decoration: BoxDecoration(
          color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold
            )
          )
        ),
      ),
    );
  }
}