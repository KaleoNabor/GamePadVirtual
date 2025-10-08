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
import 'package:gamepadvirtual/widgets/external_gamepad_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // Importe o permission_handler
import 'package:disable_battery_optimization/disable_battery_optimization.dart';

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
  bool _isLoading = true;
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  models.ConnectionState _externalGamepadState = models.ConnectionState.disconnected();

  GamepadLayout _predefinedLayout = GamepadLayout.xbox;
  CustomLayout? _customLayout;
  bool get _isCustomLayout => _customLayout != null;

  // SETTINGS STATE
  bool _hapticFeedbackEnabled = true;
  bool _rumbleEnabled = true;
  bool _gyroscopeEnabled = true;
  bool _accelerometerEnabled = true;

  // BACKGROUND MODE STATE
  bool _isBackgroundModeActive = false;
  // NOVO: Estado para saber se o serviço está rodando
  bool _isBackgroundServiceRunning = false; 


  // INPUT STATE
  final Map<ButtonType, bool> _buttonStates = {};
  double _leftStickX = 0, _leftStickY = 0;
  double _rightStickX = 0, _rightStickY = 0;
  double _leftTriggerValue = 0.0, _rightTriggerValue = 0.0;

  Map<String, ButtonType> get _externalGamepadMapping {
    final layoutType = _isCustomLayout ? GamepadLayoutType.custom : _predefinedLayout.type;
    switch (layoutType) {
      case GamepadLayoutType.playstation:
        return { 'BUTTON_A': ButtonType.cross, 'BUTTON_B': ButtonType.circle, 'BUTTON_X': ButtonType.square, 'BUTTON_Y': ButtonType.triangle, 'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper, 'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger, 'BUTTON_LEFT_STICK': ButtonType.leftStickButton, 'BUTTON_RIGHT_STICK': ButtonType.rightStickButton, 'BUTTON_START': ButtonType.start, 'BUTTON_SELECT': ButtonType.select, 'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp, 'DPAD_DOWN': ButtonType.dpadDown, 'DPAD_LEFT': ButtonType.dpadLeft, 'DPAD_RIGHT': ButtonType.dpadRight, };
      case GamepadLayoutType.nintendo:
        return { 'BUTTON_A': ButtonType.b, 'BUTTON_B': ButtonType.a, 'BUTTON_X': ButtonType.y, 'BUTTON_Y': ButtonType.x, 'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper, 'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger, 'BUTTON_LEFT_STICK': ButtonType.leftStickButton, 'BUTTON_RIGHT_STICK': ButtonType.rightStickButton, 'BUTTON_START': ButtonType.start, 'BUTTON_SELECT': ButtonType.select, 'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp, 'DPAD_DOWN': ButtonType.dpadDown, 'DPAD_LEFT': ButtonType.dpadLeft, 'DPAD_RIGHT': ButtonType.dpadRight, };
      case GamepadLayoutType.xbox:
      case GamepadLayoutType.custom:
      default:
        return { 'BUTTON_A': ButtonType.a, 'BUTTON_B': ButtonType.b, 'BUTTON_X': ButtonType.x, 'BUTTON_Y': ButtonType.y, 'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper, 'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger, 'BUTTON_LEFT_STICK': ButtonType.leftStickButton, 'BUTTON_RIGHT_STICK': ButtonType.rightStickButton, 'BUTTON_START': ButtonType.start, 'BUTTON_SELECT': ButtonType.select, 'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp, 'DPAD_DOWN': ButtonType.dpadDown, 'DPAD_LEFT': ButtonType.dpadLeft, 'DPAD_RIGHT': ButtonType.dpadRight, };
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeGamepad();
  }

  @override
  void dispose() {
    _sensorService.stopAllSensors();
    _unlockOrientation();
    WakelockPlus.disable();
    // Garante que o serviço pare se o usuário sair da tela sem desativá-lo
    if (_isBackgroundServiceRunning) {
      _gamepadInputService.stopGamepadService();
    }
    super.dispose();
  }

  Future<void> _initializeGamepad() async {
    try {
      if (!(await _requestPermissions())) {
        if (mounted) Navigator.pop(context);
        return;
      }
      await _checkAndRequestBatteryOptimization();
      await _gamepadInputService.initialize();

      _lockToLandscape();
      _initializeAllButtonStates();
      await _loadSettings();
      
      _connectionService.connectionStateStream.listen((state) {
        if (mounted) setState(() => _connectionState = state);
      });
      if (mounted) setState(() => _connectionState = _connectionService.currentState);
      
      _gamepadInputService.connectionStream.listen((state) {
        if (mounted) setState(() => _externalGamepadState = state);
      });
      if (mounted) setState(() => _externalGamepadState = _gamepadInputService.currentState);

      _gamepadInputService.inputStream.listen(_onExternalGamepadInput);
      
      // NOVO: Ouve o status do serviço para atualizar a UI
      _gamepadInputService.serviceStatusStream.listen((status) {
        if (mounted) {
          setState(() {
            _isBackgroundServiceRunning = (status == "STARTED");
          });
        }
      });

      _sensorService.gyroscopeStream.listen((gyroData) {
        final bool isExternalMode = _externalGamepadState.isConnected && _externalGamepadState.isExternalGamepad;
        if (_gyroscopeEnabled && !isExternalMode) {
          setState(() {
            const double sensitivity = 0.3;
            _rightStickX = (gyroData.y * sensitivity).clamp(-1.0, 1.0);
            _rightStickY = (-gyroData.x * sensitivity).clamp(-1.0, 1.0);
          });
          _sendGamepadData();
        }
      });

      await _startEnabledSensors();

      final layoutType = await _storageService.getSelectedLayout();
      if (layoutType == GamepadLayoutType.custom) {
        final customLayouts = await _storageService.getCustomLayouts();
        if (customLayouts.isNotEmpty) {
          _customLayout = customLayouts.first;
        } else {
          _customLayout = null; 
        }
      } else {
        _customLayout = null;
        _predefinedLayout = GamepadLayout.predefinedLayouts.firstWhere(
          (layout) => layout.type == layoutType,
          orElse: () => GamepadLayout.xbox,
        );
      }
    } catch (e) {
      print('Error initializing gamepad: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; 
        });
      }
    }
  }
  
  // --- LÓGICA DO MODO DE SEGUNDO PLANO ---

  Future<void> _toggleBackgroundMode(bool enable) async {
    if (enable) {
      // Pedir permissão para sobrepor outros apps
      if (await Permission.systemAlertWindow.request().isGranted) {
        // Iniciar o serviço em primeiro plano
        await _gamepadInputService.startGamepadService(hapticsEnabled: _hapticFeedbackEnabled);
        setState(() => _isBackgroundServiceRunning = true);
        

        // Mostrar uma mensagem para o usuário
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Modo de segundo plano ativado. Você pode minimizar o app.'))
          );
        }
      } else {
        // Permissão negada
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de sobreposição é necessária para o modo de segundo plano.'))
          );
        }
        // Desmarca o switch se a permissão for negada
        setState(() => _isBackgroundServiceRunning = false);
      }
    } else {
      // Parar o serviço em primeiro plano
      await _gamepadInputService.stopGamepadService();
      setState(() => _isBackgroundServiceRunning = false);
    }
  }


  Future<void> _checkAndRequestBatteryOptimization() async {
    bool? isBatteryOptimizationDisabled = await DisableBatteryOptimization.isBatteryOptimizationDisabled;
    if (isBatteryOptimizationDisabled == false) {
      await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
    }
  }

   Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }
  
  Future<void> _loadSettings() async {
    _hapticFeedbackEnabled = await _storageService.isHapticFeedbackEnabled();
    _rumbleEnabled = await _storageService.isRumbleEnabled();
    _gyroscopeEnabled = await _storageService.isGyroscopeEnabled();
    _accelerometerEnabled = await _storageService.isAccelerometerEnabled();
  }

  Future<void> _startEnabledSensors() async {
    if (_gyroscopeEnabled) await _sensorService.startGyroscope();
    if (_accelerometerEnabled) await _sensorService.startAccelerometer();
  }

  void _initializeAllButtonStates() {
    for (final type in ButtonType.values) {
      _buttonStates[type] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isExternalMode = _externalGamepadState.isConnected && _externalGamepadState.isExternalGamepad;

    return Stack(
      children: [
        ExternalGamepadDetector(
          connectionState: _externalGamepadState,
          child: Scaffold(
            backgroundColor: isExternalMode ? Colors.black : Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : isExternalMode
                      ? _buildExternalGamepadView()
                      : _isCustomLayout
                          ? _buildCustomGamepadView()
                          : _buildPredefinedGamepadView(),
            ),
          ),
        ),
        if (_isBackgroundModeActive)
          GestureDetector(
            onTap: () {
              setState(() {
                _isBackgroundModeActive = false;
                WakelockPlus.disable();
              });
            },
            child: Container(
              color: Colors.black.withOpacity(0.95),
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, color: Colors.white30, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Modo de economia de tela ativo.\nToque para voltar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white30, fontSize: 16, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  void _onExternalGamepadInput(Map<String, dynamic> input) {
    if (!_externalGamepadState.isExternalGamepad) return;
    try {
      if (input.containsKey('buttons')) {
        _updateButtonStatesFromExternal(Map<String, bool>.from(input['buttons']));
      }
      if (input.containsKey('analog')) {
        _updateAnalogStatesFromExternal(Map<String, double>.from(input['analog']));
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
          final bool wasPressed = _buttonStates[buttonType] ?? false;
          // Só vibra pelo Dart se o serviço de fundo NÃO estiver ativo.
        if (isPressed && !wasPressed && _hapticFeedbackEnabled && !_isBackgroundServiceRunning) {
          _vibrationService.vibrateForButton();
        }
        _buttonStates[buttonType] = isPressed;
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
  
  void _lockToLandscape() { SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]); }
  void _unlockOrientation() { SystemChrome.setPreferredOrientations(DeviceOrientation.values); }

  Widget _buildExternalGamepadView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    _unlockOrientation();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.grey.shade800),
                ),
                // Botão de modo de economia de tela (opcional)
              ],
            ),
            const SizedBox(height: 10),
            ConnectionStatusWidget(connectionState: _connectionState),
            const SizedBox(height: 10),
            ConnectionStatusWidget(connectionState: _externalGamepadState),
            const SizedBox(height: 30),
            const Icon(Icons.sports_esports, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text('Layout Ativo: ${ _isCustomLayout ? "Customizado" : _predefinedLayout.name }', style: TextStyle(fontSize: 18, color: Colors.grey.shade300, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            
            // NOVO: Card de configurações com o modo de segundo plano
            _buildBackgroundModeCard(),

            const SizedBox(height: 30),
            _buildSettingsCard(),
          ],
        ),
      ),
    );
  }

  // NOVO WIDGET: Card para ativar o modo de segundo plano
  Widget _buildBackgroundModeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('Modo de Fundo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Permite que o gamepad funcione mesmo com o app minimizado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Ativar em Segundo Plano', style: TextStyle(color: Colors.white)),
            value: _isBackgroundServiceRunning,
            onChanged: _toggleBackgroundMode,
            secondary: const Icon(Icons.layers, color: Colors.white),
            activeThumbColor: Colors.green,
          ),
          if (_isBackgroundServiceRunning)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Serviço ativo! Você pode sair do app. Para parar, desative aqui ou use a notificação.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green.shade300, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildSettingsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('Configurações de Envio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSettingToggle(Icons.vibration, 'Vibração Tátil', _hapticFeedbackEnabled, _toggleHapticFeedback)),
              const SizedBox(width: 16),
              Expanded(child: _buildSettingToggle(Icons.waves, 'Vibração do Jogo', _rumbleEnabled, _toggleRumble)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSettingToggle(Icons.screen_rotation_alt, 'Giroscópio', _gyroscopeEnabled, _toggleGyroscope)),
              const SizedBox(width: 16),
              Expanded(child: _buildSettingToggle(Icons.drive_eta, 'Acelerômetro', _accelerometerEnabled, _toggleAccelerometer)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingToggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center,),
          ],
        ),
        const SizedBox(height: 4),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.green,
        ),
      ],
    );
  }

  // O resto dos seus métodos de build (_buildCustomGamepadView, _buildPredefinedGamepadView, etc.)
  // permanecem exatamente os mesmos. Apenas os colei abaixo por completude.

  Widget _buildCustomGamepadView() {
    if (_customLayout == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Layout customizado não encontrado.\nVoltando para o padrão.'), ElevatedButton(onPressed: () { _storageService.setSelectedLayout(GamepadLayoutType.xbox); _initializeGamepad(); }, child: const Text("Carregar Layout Padrão"))],));
    }
    final screenSize = MediaQuery.of(context).size;
    final layout = _customLayout!;
    return Stack(
      children: [
        Positioned( top: 10, left: 10, child: IconButton( onPressed: () { _unlockOrientation(); Navigator.pop(context); }, icon: const Icon(Icons.arrow_back), style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(230)), ), ),
        Positioned( top: 10, left: 0, right: 0, child: Center( child: ConnectionStatusWidget(connectionState: _connectionState), ), ),
        if (layout.hasLeftStick)
          Positioned(
            left: layout.leftStickPosition.x * screenSize.width,
            top: layout.leftStickPosition.y * screenSize.height,
            child: AnalogStick( size: layout.leftStickPosition.size * screenSize.height, label: 'L', isLeft: true, onChanged: (x, y) { setState(() { _leftStickX = x; _leftStickY = y; }); _sendGamepadData(); }, ),
          ),
        if (layout.hasRightStick)
          Positioned(
            left: layout.rightStickPosition.x * screenSize.width,
            top: layout.rightStickPosition.y * screenSize.height,
            child: AnalogStick( size: layout.rightStickPosition.size * screenSize.height, label: 'R', isLeft: false, onChanged: (x, y) { 
              if (!_gyroscopeEnabled) {
                setState(() { _rightStickX = x; _rightStickY = y; }); 
                _sendGamepadData();
              }
            }, ),
          ),
        ...layout.buttons.map((button) {
          final absolutePosition = ButtonPosition(
            x: button.position.x * screenSize.width,
            y: button.position.y * screenSize.height,
            size: button.position.size * screenSize.height,
            width: button.position.width != null ? button.position.width! * screenSize.height : null,
          );
          final absoluteButton = button.copyWith(position: absolutePosition);
          return Positioned(
            left: absoluteButton.position.x,
            top: absoluteButton.position.y,
            child: _buildDynamicButton(absoluteButton),
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
        Positioned(left: 60, top: 60, child: _buildTriggerButton('L2', ButtonType.leftTrigger)),
        Positioned(left: 60, top: 95, child: _buildShoulderButton('L1', ButtonType.leftBumper)),
        Positioned(left: 130, bottom: 20, child: _buildStickButton('L3', ButtonType.leftStickButton)),
        Positioned(right: 40, bottom: 40, child: AnalogStick(size: 120, label: 'R', isLeft: false, onChanged: (x, y) {
          if (!_gyroscopeEnabled) {
            setState(() { _rightStickX = x; _rightStickY = y; }); 
            _sendGamepadData();
          }
        },)),
        Positioned(right: 180, bottom: 60, child: _buildActionButtons()),
        Positioned(right: 60, top: 60, child: _buildTriggerButton('R2', ButtonType.rightTrigger)),
        Positioned(right: 60, top: 95, child: _buildShoulderButton('R1', ButtonType.rightBumper)),
        Positioned(right: 130, bottom: 20, child: _buildStickButton('R3', ButtonType.rightStickButton)),
        Positioned( top: 70, left: 0, right: 0, child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ _buildSystemButton('SELECT', ButtonType.select), const SizedBox(width: 60), _buildSystemButton('START', ButtonType.start), ], ), ),
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
        child: Center(child: _buildButtonChild(button)),
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
    return Text( button.label, style: TextStyle( color: textColor, fontWeight: FontWeight.bold, fontSize: size * 0.5, ), );
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
      child: Container( 
        width: 44, 
        height: 44, 
        decoration: BoxDecoration( 
          color: Color(button.color), 
          shape: BoxShape.circle, 
          border: Border.all(color: Colors.white, width: 2), 
          boxShadow: isPressed ? [] : [ BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 4, offset: const Offset(0, 2)) ], 
        ), 
        child: Center( 
          child: Text(
            button.label, 
            style: TextStyle(color: _getTextColor(Color(button.color)), fontWeight: FontWeight.bold, fontSize: 18)
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
      child: Container( 
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
      child: Container( 
        width: 100, 
        height: 40, 
        decoration: BoxDecoration( 
          color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800, 
          borderRadius: BorderRadius.circular(12), 
        ), 
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))), 
      ), 
    ); 
  }

  Widget _buildTriggerButton(String label, ButtonType buttonType) { 
    final isPressed = _buttonStates[buttonType] ?? false; 
    return GestureDetector( 
      onTapDown: (_) => _onButtonPressed(buttonType), 
      onTapUp: (_) => _onButtonReleased(buttonType), 
      onTapCancel: () => _onButtonReleased(buttonType), 
      child: Container( 
        width: 90, 
        height: 30, 
        decoration: BoxDecoration( 
          color: isPressed ? Colors.grey.shade500 : Colors.grey.shade700, 
          borderRadius: BorderRadius.circular(10), 
        ), 
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), 
      ), 
    ); 
  }

  Widget _buildStickButton(String label, ButtonType buttonType) { 
    final isPressed = _buttonStates[buttonType] ?? false; 
    return GestureDetector( 
      onTapDown: (_) => _onButtonPressed(buttonType), 
      onTapUp: (_) => _onButtonReleased(buttonType), 
      onTapCancel: () => _onButtonReleased(buttonType), 
      child: Container( 
        width: 40, 
        height: 40, 
        decoration: BoxDecoration( 
          color: isPressed ? Colors.blue.shade600 : Colors.grey.shade800, 
          shape: BoxShape.circle, 
        ), 
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), 
      ), 
    ); 
  }

  Widget _buildSystemButton(String label, ButtonType buttonType) { 
    final isPressed = _buttonStates[buttonType] ?? false; 
    return GestureDetector( 
      onTapDown: (_) => _onButtonPressed(buttonType), 
      onTapUp: (_) => _onButtonReleased(buttonType), 
      onTapCancel: () => _onButtonReleased(buttonType), 
      child: Container( 
        width: 80, 
        height: 25, 
        decoration: BoxDecoration( 
          color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800, 
          borderRadius: BorderRadius.circular(20), 
        ), 
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), 
      ), 
    ); 
  }

  Color _getTextColor(Color backgroundColor) { 
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white; 
  }

  void _onButtonPressed(ButtonType buttonType) { setState(() => _buttonStates[buttonType] = true); if (_hapticFeedbackEnabled) _vibrationService.vibrateForButton(); _sendGamepadData(); }
  void _onButtonReleased(ButtonType buttonType) { setState(() => _buttonStates[buttonType] = false); _sendGamepadData(); }
  
  Future<void> _toggleHapticFeedback(bool enabled) async { setState(() => _hapticFeedbackEnabled = enabled); await _storageService.setHapticFeedbackEnabled(enabled); }
  Future<void> _toggleRumble(bool enabled) async { setState(() => _rumbleEnabled = enabled); await _storageService.setRumbleEnabled(enabled); }
  Future<void> _toggleGyroscope(bool enabled) async { setState(() => _gyroscopeEnabled = enabled); await _storageService.setGyroscopeEnabled(enabled); if(enabled) {
    _sensorService.startGyroscope();
  } else {
    _sensorService.stopGyroscope();
  } }
  Future<void> _toggleAccelerometer(bool enabled) async { setState(() => _accelerometerEnabled = enabled); await _storageService.setAccelerometerEnabled(enabled); if(enabled) {
    _sensorService.startAccelerometer();
  } else {
    _sensorService.stopAccelerometer();
  } }

  void _sendGamepadData() async {
    try {
      SensorData? accelerometerData;
      SensorData? gyroscopeData;
      if (_accelerometerEnabled) {
        accelerometerData = await _sensorService.getLatestAccelerometerData();
      }
      if (_gyroscopeEnabled) {
        gyroscopeData = await _sensorService.getLatestGyroscopeData();
      }

      final data = GamepadInputData(
        buttons: Map<String, bool>.fromEntries(
            _buttonStates.entries.map((e) => MapEntry(e.key.toString(), e.value))),
        analogSticks: {
          'leftX': _leftStickX,
          'leftY': _leftStickY,
          'rightX': _rightStickX,
          'rightY': _rightStickY,
          'leftTrigger': _leftTriggerValue,
          'rightTrigger': _rightTriggerValue,
        },
        sensors: {
          if (accelerometerData != null) 'accelerometer': accelerometerData.toJson(),
          if (gyroscopeData != null) 'gyroscope': gyroscopeData.toJson(),
        },
        timestamp: DateTime.now(),
      );
      await _connectionService.sendGamepadData(data);
    } catch (e) {
      print('Error sending gamepad data: $e');
    }
  }
}