import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // CORRIGIDO
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
import 'package:gamepadvirtual/widgets/external_gamepad_detector.dart';

class GamepadScreen extends StatefulWidget {
  const GamepadScreen({super.key});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> {
  final ConnectionService _connectionService = ConnectionService();
  final StorageService _storageService = StorageService();
  final VibrationService _vibrationService = VibrationService();
  final SensorService _sensorService = SensorService();
  final GamepadInputService _gamepadInputService = GamepadInputService();

  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  GamepadLayout _predefinedLayout = GamepadLayout.xbox;
  CustomLayout? _customLayout;
  bool get _isCustomLayout => _customLayout != null;
  bool _isInitialized = false;

  final Map<ButtonType, bool> _buttonStates = {};
  double _leftStickX = 0, _leftStickY = 0;
  double _rightStickX = 0, _rightStickY = 0;

  final Map<String, ButtonType> _externalGamepadMapping = {
    'BUTTON_A': ButtonType.a, 'BUTTON_B': ButtonType.b,
    'BUTTON_X': ButtonType.x, 'BUTTON_Y': ButtonType.y,
    'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper,
    'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger,
    'BUTTON_SELECT': ButtonType.select, 'BUTTON_START': ButtonType.start,
    'BUTTON_LEFT_STICK': ButtonType.leftStickButton,
    'BUTTON_RIGHT_STICK': ButtonType.rightStickButton,
    'DPAD_UP': ButtonType.dpadUp, 'DPAD_DOWN': ButtonType.dpadDown,
    'DPAD_LEFT': ButtonType.dpadLeft, 'DPAD_RIGHT': ButtonType.dpadRight,
  };

  @override
  void initState() {
    super.initState();
    _initializeGamepad();
  }

  @override
  void dispose() {
    _sensorService.stopAllSensors();
    _unlockOrientation();
    super.dispose();
  }

  Future<void> _initializeGamepad() async {
    if (_isInitialized) return;
    try {
      _lockToLandscape();

      final layoutType = await _storageService.getSelectedLayout();

      if (layoutType == GamepadLayoutType.custom) {
        final customLayouts = await _storageService.getCustomLayouts();
        if (customLayouts.isNotEmpty && mounted) {
          setState(() {
            _customLayout = customLayouts.first;
          });
        }
      } else if (mounted) {
        setState(() {
          _customLayout = null;
          _predefinedLayout = GamepadLayout.predefinedLayouts.firstWhere(
            (layout) => layout.type == layoutType,
            orElse: () => GamepadLayout.xbox,
          );
        });
      }

      _initializeAllButtonStates();

      _connectionService.connectionStateStream.listen((state) {
        if (mounted) setState(() => _connectionState = state);
      });
      if (mounted) setState(() => _connectionState = _connectionService.currentState);

      // CORRIGIDO
      _gamepadInputService.inputStream.listen(_onExternalGamepadInput);
      await _sensorService.startAllSensors();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing gamepad: $e');
    }
  }

  void _initializeAllButtonStates() {
    for (final type in ButtonType.values) {
      _buttonStates[type] = false;
    }
  }

  void _onExternalGamepadInput(Map<String, dynamic> input) {
    try {
      if (input.containsKey('buttons')) {
        final buttons = Map<String, bool>.from(input['buttons']);
        _updateButtonStatesFromExternal(buttons);
      }
      if (input.containsKey('analog')) {
        final analog = Map<String, double>.from(input['analog']);
        _updateAnalogSticksFromExternal(analog);
      }
      _sendGamepadData();
    } catch (e) {
      print('Error processing external gamepad input: $e');
    }
  }

  void _updateButtonStatesFromExternal(Map<String, bool> externalButtons) {
    setState(() {
      externalButtons.forEach((key, isPressed) {
        final buttonType = _externalGamepadMapping[key];
        if (buttonType != null) {
          _buttonStates[buttonType] = isPressed;
          if (isPressed) _vibrationService.vibrateForButton();
        }
      });
    });
  }

  void _updateAnalogSticksFromExternal(Map<String, double> analog) {
    setState(() {
      _leftStickX = analog['leftX'] ?? _leftStickX;
      _leftStickY = analog['leftY'] ?? _leftStickY;
      _rightStickX = analog['rightX'] ?? _rightStickX;
      _rightStickY = analog['rightY'] ?? _rightStickY;
    });
  }

  void _lockToLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _unlockOrientation() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  Widget build(BuildContext context) {
    return ExternalGamepadDetector(
      connectionState: _connectionState,
      child: Scaffold(
        body: SafeArea(
          child: _connectionState.isExternalGamepad
              ? _buildExternalGamepadView()
              : _isCustomLayout
                  ? _buildCustomGamepadView()
                  : _buildPredefinedGamepadView(),
        ),
      ),
    );
  }

  Widget _buildExternalGamepadView() {
    return Container(
      color: Colors.black87,
      child: Stack(
        children: [
          Positioned( top: 10, left: 10, child: IconButton( onPressed: () { _unlockOrientation(); Navigator.pop(context); }, icon: const Icon(Icons.arrow_back, color: Colors.white), style: IconButton.styleFrom(backgroundColor: Colors.grey.shade800), ), ),
          Positioned( top: 10, left: 0, right: 0, child: Center( child: ConnectionStatusWidget(connectionState: _connectionState, showDetails: true), ), ),
          Center( child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ const Icon(Icons.sports_esports, size: 80, color: Colors.green), const SizedBox(height: 20), Text( 'Gamepad Externo Conectado', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white), textAlign: TextAlign.center, ), const SizedBox(height: 16), const Text( 'Você pode desligar a tela.\nO app continuará em segundo plano.', style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center, ), ], ), ),
        ],
      ),
    );
  }

  Widget _buildCustomGamepadView() {
    if (_customLayout == null) {
      return const Center(child: Text('Erro ao carregar layout customizado'));
    }
    final layout = _customLayout!;
    return Stack(
      children: [
        Positioned( top: 10, left: 10, child: IconButton( onPressed: () { _unlockOrientation(); Navigator.pop(context); }, icon: const Icon(Icons.arrow_back), style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(230)), ), ),
        Positioned( top: 10, left: 0, right: 0, child: Center( child: ConnectionStatusWidget(connectionState: _connectionState), ), ),
        if (layout.hasLeftStick)
          Positioned(
            left: layout.leftStickPosition.x,
            top: layout.leftStickPosition.y,
            child: AnalogStick(
              size: layout.leftStickPosition.size,
              label: 'L',
              isLeft: true,
              onChanged: (x, y) { setState(() { _leftStickX = x; _leftStickY = y; }); _sendGamepadData(); },
            ),
          ),
        if (layout.hasRightStick)
          Positioned(
            left: layout.rightStickPosition.x,
            top: layout.rightStickPosition.y,
            child: AnalogStick(
              size: layout.rightStickPosition.size,
              label: 'R',
              isLeft: false,
              onChanged: (x, y) { setState(() { _rightStickX = x; _rightStickY = y; }); _sendGamepadData(); },
            ),
          ),
        ...layout.buttons.map((button) {
          return Positioned(
            left: button.position.x,
            top: button.position.y,
            child: _buildDynamicButton(button),
          );
        }),
      ],
    );
  }

  Widget _buildPredefinedGamepadView() {
    return Stack(
      children: [
        Positioned( top: 10, left: 10, child: IconButton( onPressed: () { _unlockOrientation(); Navigator.pop(context); }, icon: const Icon(Icons.arrow_back), style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(230)), ), ),
        Positioned( top: 10, left: 0, right: 0, child: Center( child: ConnectionStatusWidget( connectionState: _connectionState, showDetails: false, ), ), ),
        Positioned(left: 40, bottom: 40, child: AnalogStick(size: 120, label: 'L', isLeft: true, onChanged: (x, y) { setState(() { _leftStickX = x; _leftStickY = y; }); _sendGamepadData(); },)),
        Positioned(left: 180, bottom: 60, child: _buildDPad()),
        Positioned(left: 40, top: 10, child: _buildTriggerButton('L2', ButtonType.leftTrigger)),
        Positioned(left: 40, top: 45, child: _buildShoulderButton('L1', ButtonType.leftBumper)),
        Positioned(left: 130, bottom: 20, child: _buildStickButton('L3', ButtonType.leftStickButton)),
        Positioned(right: 40, bottom: 40, child: AnalogStick(size: 120, label: 'R', isLeft: false, onChanged: (x, y) { setState(() { _rightStickX = x; _rightStickY = y; }); _sendGamepadData(); },)),
        Positioned(right: 180, bottom: 60, child: _buildActionButtons()),
        Positioned(right: 40, top: 10, child: _buildTriggerButton('R2', ButtonType.rightTrigger)),
        Positioned(right: 40, top: 45, child: _buildShoulderButton('R1', ButtonType.rightBumper)),
        Positioned(right: 130, bottom: 20, child: _buildStickButton('R3', ButtonType.rightStickButton)),
        Positioned( top: 20, left: 0, right: 0, child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ _buildSystemButton('SELECT', ButtonType.select), const SizedBox(width: 60), _buildSystemButton('START', ButtonType.start), ], ), ),
      ],
    );
  }

  Widget _buildDynamicButton(CustomLayoutButton button) {
    final isPressed = _buttonStates[button.type] ?? false;
    final isShoulder = _isShoulderButton(button.type);
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(button.type),
      onTapUp: (_) => _onButtonReleased(button.type),
      onTapCancel: () => _onButtonReleased(button.type),
      child: Container(
        width: button.position.size * (isShoulder ? 1.5 : 1.0),
        height: button.position.size,
        decoration: BoxDecoration(
          color: isPressed ? Color(button.color).withOpacity(0.7) : Color(button.color),
          borderRadius: BorderRadius.circular(isShoulder ? 20 : 100),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(child: _buildButtonChild(button)),
      ),
    );
  }

  bool _isShoulderButton(ButtonType t) => t == ButtonType.leftBumper || t == ButtonType.rightBumper || t == ButtonType.leftTrigger || t == ButtonType.rightTrigger;

  Widget _buildButtonChild(CustomLayoutButton button) {
    Color textColor = _getTextColor(Color(button.color));
    double size = button.position.size;
    switch (button.type) {
      case ButtonType.dpadUp: return Icon(Icons.arrow_upward, color: textColor, size: size * 0.6);
      case ButtonType.dpadDown: return Icon(Icons.arrow_downward, color: textColor, size: size * 0.6);
      case ButtonType.dpadLeft: return Icon(Icons.arrow_back, color: textColor, size: size * 0.6);
      case ButtonType.dpadRight: return Icon(Icons.arrow_forward, color: textColor, size: size * 0.6);
      default: return Text( button.label, style: TextStyle( color: textColor, fontWeight: FontWeight.bold, fontSize: size * (_isShoulderButton(button.type) ? 0.4 : 0.3), ), );
    }
  }

  Widget _buildDPad() {
    return SizedBox( width: 120, height: 120, child: Stack( children: [ Positioned(top: 0, left: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_up, ButtonType.dpadUp)), Positioned(bottom: 0, left: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_down, ButtonType.dpadDown)), Positioned(left: 0, top: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_left, ButtonType.dpadLeft)), Positioned(right: 0, top: 40, child: _buildDirectionalButton(Icons.keyboard_arrow_right, ButtonType.dpadRight)), ], ), );
  }

  Widget _buildActionButtons() {
    final buttons = _predefinedLayout.buttons;
    return SizedBox( width: 120, height: 120, child: Stack( children: [ if (buttons.isNotEmpty) Positioned(top: 0, left: 40, child: _buildGamepadButton(buttons[0])), if (buttons.length > 1) Positioned(right: 0, top: 40, child: _buildGamepadButton(buttons[1])), if (buttons.length > 2) Positioned(bottom: 0, left: 40, child: _buildGamepadButton(buttons[2])), if (buttons.length > 3) Positioned(left: 0, top: 40, child: _buildGamepadButton(buttons[3])), ], ), );
  }

  Widget _buildGamepadButton(GamepadButton button) {
    final isPressed = _buttonStates[button.type] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(button.type),
      onTapUp: (_) => _onButtonReleased(button.type),
      onTapCancel: () => _onButtonReleased(button.type),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Color(button.color),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: isPressed ? [] : [ BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 4, offset: const Offset(0, 2)) ],
        ),
        child: Center( child: Text(button.label, style: TextStyle(color: _getTextColor(Color(button.color)), fontWeight: FontWeight.bold, fontSize: 18)), ),
      ),
    );
  }

  Widget _buildDirectionalButton(IconData icon, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector( onTapDown: (_) => _onButtonPressed(buttonType), onTapUp: (_) => _onButtonReleased(buttonType), onTapCancel: () => _onButtonReleased(buttonType), child: Container( width: 40, height: 40, decoration: BoxDecoration( color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800, borderRadius: BorderRadius.circular(8), ), child: Icon(icon, color: Colors.white, size: 24), ), );
  }

  Widget _buildShoulderButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector( onTapDown: (_) => _onButtonPressed(buttonType), onTapUp: (_) => _onButtonReleased(buttonType), onTapCancel: () => _onButtonReleased(buttonType), child: Container( width: 100, height: 40, decoration: BoxDecoration( color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800, borderRadius: BorderRadius.circular(12), ), child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))), ), );
  }

  Widget _buildTriggerButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector( onTapDown: (_) => _onButtonPressed(buttonType), onTapUp: (_) => _onButtonReleased(buttonType), onTapCancel: () => _onButtonReleased(buttonType), child: Container( width: 90, height: 30, decoration: BoxDecoration( color: isPressed ? Colors.grey.shade500 : Colors.grey.shade700, borderRadius: BorderRadius.circular(10), ), child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), ), );
  }

  Widget _buildStickButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector( onTapDown: (_) => _onButtonPressed(buttonType), onTapUp: (_) => _onButtonReleased(buttonType), onTapCancel: () => _onButtonReleased(buttonType), child: Container( width: 40, height: 40, decoration: BoxDecoration( color: isPressed ? Colors.blue.shade600 : Colors.grey.shade800, shape: BoxShape.circle, ), child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), ), );
  }

  Widget _buildSystemButton(String label, ButtonType buttonType) {
    final isPressed = _buttonStates[buttonType] ?? false;
    return GestureDetector( onTapDown: (_) => _onButtonPressed(buttonType), onTapUp: (_) => _onButtonReleased(buttonType), onTapCancel: () => _onButtonReleased(buttonType), child: Container( width: 80, height: 25, decoration: BoxDecoration( color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800, borderRadius: BorderRadius.circular(20), ), child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), ), );
  }

  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  void _onButtonPressed(ButtonType buttonType) {
    setState(() => _buttonStates[buttonType] = true);
    _vibrationService.vibrateForButton();
    _sendGamepadData();
  }

  void _onButtonReleased(ButtonType buttonType) {
    setState(() => _buttonStates[buttonType] = false);
    _sendGamepadData();
  }

  void _sendGamepadData() async {
    final data = GamepadInputData(
      buttons: Map<String, bool>.fromEntries(
        _buttonStates.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      ),
      analogSticks: {
        'leftX': _leftStickX, 'leftY': _leftStickY,
        'rightX': _rightStickX, 'rightY': _rightStickY,
      },
      timestamp: DateTime.now(),
    );
    await _connectionService.sendGamepadData(data);
  }
}