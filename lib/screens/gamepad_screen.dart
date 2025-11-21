import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as models;
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/connection_service.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';
import 'package:gamepadvirtual/services/sensor_service.dart';
import 'package:gamepadvirtual/services/gamepad_input_service.dart';
import 'package:gamepadvirtual/services/stream_service.dart';
import 'package:gamepadvirtual/widgets/connection_status.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:gamepadvirtual/services/gamepad_state_service.dart';
import 'package:gamepadvirtual/widgets/gamepad_layout_view.dart';
import 'package:gamepadvirtual/widgets/gamepad_settings_drawer.dart';

class GamepadScreen extends StatefulWidget {
  const GamepadScreen({super.key});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> with WidgetsBindingObserver {
  final ConnectionService _connectionService = ConnectionService();
  final StorageService _storageService = StorageService();
  final VibrationService _vibrationService = VibrationService();
  final SensorService _sensorService = SensorService();
  final GamepadInputService _gamepadInputService = GamepadInputService();
  final GamepadStateService _gamepadState = GamepadStateService();
  final StreamService _streamService = StreamService();
  
  // Estados
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  models.ConnectionState _externalGamepadState = models.ConnectionState.disconnected();
  GamepadLayout _predefinedLayout = GamepadLayout.xbox;
  GamepadLayoutType _selectedLayoutType = GamepadLayoutType.xbox;
  
  // Flags de configuração
  bool _hapticFeedbackEnabled = true;
  bool _gyroscopeEnabled = true;
  bool _accelerometerEnabled = true;
  bool _rumbleEnabled = true;
  bool _externalDigitalTriggersEnabled = false;
  
  // Flags de Streaming e Audio
  bool _isStreaming = false;
  bool _isLoadingStream = false;
  bool _isImmersiveMode = true;
  bool _isTransparentMode = true;
  bool _isTouchpadEnabled = false;
  bool _isAudioEnabled = true; // <--- NOVO
  bool _isServerStreamingEnabled = false; // Estado remoto do PC
  double _mouseSensitivity = 2.0;

  // Timers e Subs
  Timer? _gameLoopTimer;
  Timer? _connectionCheckTimer;
  StreamSubscription? _connSub;
  StreamSubscription? _extConnSub;
  StreamSubscription? _extInputSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _accelSub;
  StreamSubscription? _sigSub;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable(); 
    
    _gamepadState.initialize();
    
    // A BARREIRA: Só inicializa o serviço se precisarmos.
    _streamService.initialize().then((_) {
        if (_streamService.hasVideoStream && mounted) {
            setState(() {
                _isStreaming = true;
                _isLoadingStream = false;
            });
        }
    });
    
    _externalGamepadState = _gamepadInputService.currentState;

    _initializeConnections();
  }

  Future<void> _initializeConnections() async {
    await _gamepadInputService.initialize(); 
    await _loadSettingsAndLayout();

    _connSub = _connectionService.connectionStateStream.listen((newState) {
       if (mounted) setState(() => _connectionState = newState);
       if (!newState.isConnected) {
         _stopGameLoop();
       } else {
         _startGameLoop();
       }
    });

    _extConnSub = _gamepadInputService.connectionStream.listen((state) {
      if (mounted) setState(() => _externalGamepadState = state);
    });
    
    _extInputSub = _gamepadInputService.inputStream.listen(_onExternalGamepadInput);
    
    _sigSub = _connectionService.signalingStream.listen((data) {
      _streamService.handleSignalingMessage(data);
    });
    
    _streamService.onStreamAdded = (renderer) {
      if (mounted) {
        setState(() { 
          _isStreaming = true; 
          _isLoadingStream = false; 
        });
      }
    };

    _streamService.onConnectionLost = () {
      if (mounted) setState(() => _isLoadingStream = true);
    };
    
    _gyroSub = _sensorService.gyroscopeStream.listen(_updateGyroState);
    _accelSub = _sensorService.accelerometerStream.listen(_updateAccelState);
    _startEnabledSensors();
    
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      _connectionService.checkConnectionStatus();
    });
    
    if (mounted) {
      setState(() {
         _connectionState = _connectionService.currentState;
         _externalGamepadState = _gamepadInputService.currentState; 
         _isLoadingStream = false; 
         // Aplica áudio carregado
         _streamService.setAudioEnabled(_isAudioEnabled);
      });
    }
    
    _startGameLoop();
  }

  @override
  void dispose() {
    _stopGameLoop();
    _connectionCheckTimer?.cancel();
    _connSub?.cancel();
    _extConnSub?.cancel();
    _extInputSub?.cancel();
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _sigSub?.cancel();
    
    // Limpeza de callbacks da UI no serviço persistente
    _streamService.onStreamAdded = null;
    _streamService.onConnectionLost = null;

    _sensorService.dispose();
    _gamepadState.dispose();
    _unlockOrientation();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Print Screen ou Background temporário: Não mata o stream
      _stopGameLoop();
    } 
    else if (state == AppLifecycleState.detached) {
      // App fechando de vez
      _streamService.dispose(); // Mata o singleton
      _sensorService.stopAllSensors();
    }
    else if (state == AppLifecycleState.resumed) {
      _lockToLandscape();
      _startEnabledSensors();
      _startGameLoop();
      _connectionService.checkConnectionStatus();
    }
  }

  void _startGameLoop() {
    _stopGameLoop();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 8), (Timer timer) {
      if (_connectionService.currentState.isConnected && 
          (_gamepadState.hasNewInput || _gyroscopeEnabled || _accelerometerEnabled)) {
        _sendGamepadData();
        _gamepadState.clearInputFlag();
      }
    });
  }

  void _stopGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = null;
  }

  void _updateGyroState(SensorData gyroData) {
    _gamepadState.updateGyroState(gyroData, _gyroscopeEnabled);
  }

  void _updateAccelState(SensorData accelData) {
    _gamepadState.updateAccelState(accelData, _accelerometerEnabled);
  }

  void _sendGamepadData() {
    try {
      final data = _gamepadState.getGamepadInputData();
      _connectionService.sendGamepadData(data);
    } catch (e) {
      debugPrint("Erro ao enviar dados do gamepad: $e");
    }
  }

  Future<void> _loadSettingsAndLayout() async {
    _hapticFeedbackEnabled = await _storageService.isHapticFeedbackEnabled();
    _gyroscopeEnabled = await _storageService.isGyroscopeEnabled();
    _accelerometerEnabled = await _storageService.isAccelerometerEnabled();
    _rumbleEnabled = await _storageService.isRumbleEnabled();
    _externalDigitalTriggersEnabled = await _storageService.isExternalDigitalTriggersEnabled();
    
    _isTransparentMode = await _storageService.isButtonStyleTransparent();
    _isImmersiveMode = await _storageService.isViewModeImmersive();
    _isTouchpadEnabled = await _storageService.isTouchpadEnabled();
    _mouseSensitivity = await _storageService.getMouseSensitivity();
    
    // Carrega Áudio
    _isAudioEnabled = await _storageService.isAudioEnabled();

    final layoutType = await _storageService.getSelectedLayout();
    _selectedLayoutType = layoutType;
    if (layoutType == GamepadLayoutType.custom) {
      final baseType = await _storageService.getCustomLayoutBase();
      _predefinedLayout = GamepadLayout.predefinedLayouts.firstWhere((l) => l.type == baseType, orElse: () => GamepadLayout.xbox);
    } else {
      _predefinedLayout = GamepadLayout.predefinedLayouts.firstWhere((l) => l.type == layoutType, orElse: () => GamepadLayout.xbox);
    }
    setState(() {});
  }

  Future<void> _startEnabledSensors() async {
    if (_gyroscopeEnabled) await _sensorService.startGyroscope();
    if (_accelerometerEnabled) await _sensorService.startAccelerometer();
  }

  void _startStreaming() {
    if (!_connectionState.isConnected) {
      _showStreamError("Conecte-se a um servidor primeiro");
      return;
    }
    
    if (_isStreaming || _isLoadingStream) return;
    
    setState(() {
      _isLoadingStream = true;
    });
    
    try {
      _streamService.startConnection();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStream = false;
        });
      }
      _showStreamError("Erro ao iniciar streaming: $e");
    }
  }

  void _stopStreaming() {
    _streamService.stopStream(); // Usa o método que avisa o servidor
    if (mounted) {
      setState(() {
        _isStreaming = false;
        _isLoadingStream = false;
      });
    }
  }

  void _showStreamError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isTouchpadEnabled) return;
    final dx = (details.delta.dx * _mouseSensitivity).round();
    final dy = (details.delta.dy * _mouseSensitivity).round();
    if (dx != 0 || dy != 0) {
      _connectionService.sendMouseData(dx, dy);
    }
  }

  void _handleTap() {
     if (!_isTouchpadEnabled) return;
     _connectionService.sendMouseData(0, 0, leftClick: true);
     Future.delayed(const Duration(milliseconds: 50), () {
        _connectionService.sendMouseData(0, 0, leftClick: false);
     });
  }

  void _handleDoubleTap() {
     if (!_isTouchpadEnabled) return;
     _connectionService.sendMouseData(0, 0, rightClick: true);
     Future.delayed(const Duration(milliseconds: 50), () {
        _connectionService.sendMouseData(0, 0, rightClick: false);
     });
  }

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
    if(enabled) { 
      _sensorService.startGyroscope(); 
    } else { 
      _sensorService.stopGyroscope(); 
      _gamepadState.updateGyroState(SensorData(x:0, y:0, z:0, timestamp: DateTime.now()), false);
    } 
  }
  
  Future<void> _toggleAccelerometer(bool enabled) async { 
    await _storageService.setAccelerometerEnabled(enabled); 
    setState(() => _accelerometerEnabled = enabled); 
    if(enabled) { 
      _sensorService.startAccelerometer(); 
    } else { 
      _sensorService.stopAccelerometer(); 
      _gamepadState.updateAccelState(SensorData(x:0, y:0, z:0, timestamp: DateTime.now()), false);
    } 
  }

  Future<void> _toggleExternalDigitalTriggers(bool enabled) async { 
    await _storageService.setExternalDigitalTriggersEnabled(enabled); 
    setState(() => _externalDigitalTriggersEnabled = enabled); 
  }

  Future<void> _toggleAudio(bool enabled) async {
    await _storageService.setAudioEnabled(enabled);
    setState(() => _isAudioEnabled = enabled);
    _streamService.setAudioEnabled(enabled);
  }

  void _lockToLandscape() => SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft, 
    DeviceOrientation.landscapeRight
  ]);

  void _unlockOrientation() => SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  Map<String, ButtonType> get _externalGamepadMapping {
    switch (_predefinedLayout.type) {
      case GamepadLayoutType.playstation:
        return {
          'BUTTON_A': ButtonType.cross, 'BUTTON_B': ButtonType.circle, 
          'BUTTON_X': ButtonType.square, 'BUTTON_Y': ButtonType.triangle,
          'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper,
          'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger,
          'BUTTON_LEFT_STICK': ButtonType.leftStickButton, 
          'BUTTON_RIGHT_STICK': ButtonType.rightStickButton,
          'BUTTON_START': ButtonType.start, 'BUTTON_SELECT': ButtonType.select,
          'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp,
          'DPAD_DOWN': ButtonType.dpadDown, 'DPAD_LEFT': ButtonType.dpadLeft,
          'DPAD_RIGHT': ButtonType.dpadRight,
        };
      case GamepadLayoutType.nintendo:
        return {
          'BUTTON_A': ButtonType.b, 'BUTTON_B': ButtonType.a,
          'BUTTON_X': ButtonType.y, 'BUTTON_Y': ButtonType.x,
          'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper,
          'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger,
          'BUTTON_LEFT_STICK': ButtonType.leftStickButton,
          'BUTTON_RIGHT_STICK': ButtonType.rightStickButton,
          'BUTTON_START': ButtonType.start, 'BUTTON_SELECT': ButtonType.select,
          'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp,
          'DPAD_DOWN': ButtonType.dpadDown, 'DPAD_LEFT': ButtonType.dpadLeft,
          'DPAD_RIGHT': ButtonType.dpadRight,
        };
      default: // Xbox
        return {
          'BUTTON_A': ButtonType.a, 'BUTTON_B': ButtonType.b,
          'BUTTON_X': ButtonType.x, 'BUTTON_Y': ButtonType.y,
          'BUTTON_L1': ButtonType.leftBumper, 'BUTTON_R1': ButtonType.rightBumper,
          'BUTTON_L2': ButtonType.leftTrigger, 'BUTTON_R2': ButtonType.rightTrigger,
          'BUTTON_LEFT_STICK': ButtonType.leftStickButton,
          'BUTTON_RIGHT_STICK': ButtonType.rightStickButton,
          'BUTTON_START': ButtonType.start, 'BUTTON_SELECT': ButtonType.select,
          'BUTTON_MODE': ButtonType.start, 'DPAD_UP': ButtonType.dpadUp,
          'DPAD_DOWN': ButtonType.dpadDown, 'DPAD_LEFT': ButtonType.dpadLeft,
          'DPAD_RIGHT': ButtonType.dpadRight,
        };
    }
  }

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
      debugPrint('Error processing external gamepad input: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isExternalMode = _externalGamepadState.isConnected && _externalGamepadState.isExternalGamepad;
    final Size screenSize = MediaQuery.of(context).size;

    Widget videoWidget = RTCVideoView(
      _streamService.remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain, 
    );

    Widget mainContent = Stack(
      children: [
        if (_isImmersiveMode) ...[
          if (_isStreaming) Positioned.fill(child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: _handlePanUpdate,
            onTap: _handleTap,
            onDoubleTap: _handleDoubleTap,
            child: videoWidget,
          )),
          Positioned.fill(
            child: isExternalMode ? _buildExternalGamepadView() : _buildPredefinedGamepadView()
          ),
        ] else ...[
          Column(
            children: [
              if (_isStreaming)
                Container(
                  constraints: BoxConstraints(maxHeight: screenSize.height * 0.6),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade900), color: Colors.black),
                      child: videoWidget,
                    ),
                  ),
                )
              else
                Container(
                  height: screenSize.height * 0.4,
                  color: Colors.grey.shade900,
                  child: const Center(child: Icon(Icons.tv_off, color: Colors.grey)),
                ),
              Expanded(
                child: Container(
                  color: const Color(0xFF121212),
                  child: ClipRect(
                    child: isExternalMode ? _buildExternalGamepadView() : _buildPredefinedGamepadView()
                  ),
                ),
              ),
            ],
          ),
        ],

        Positioned(
          top: 20, left: 20,
          child: _buildCircularButton(
            icon: Icons.arrow_back,
            onPressed: () { _unlockOrientation(); Navigator.pop(context); },
          ),
        ),

        if (!_isStreaming)
          Positioned(
            top: 20, left: 0, right: 0,
            child: Center(
              child: ConnectionStatusWidget(
                connectionState: _connectionState,
                showDetails: true,
              ),
            ),
          ),

        Positioned(
          top: 20, right: 20,
          child: Row(
            children: [
              if (!_isStreaming && _connectionState.isConnected)
                _buildCircularButton(
                  icon: Icons.cast,
                  isLoading: _isLoadingStream,
                  onPressed: _startStreaming,
                ),

              if (_isStreaming) ...[
                 _buildCircularButton(
                  icon: _isImmersiveMode ? Icons.vertical_split : Icons.fullscreen,
                  onPressed: () => setState(() => _isImmersiveMode = !_isImmersiveMode),
                ),
                const SizedBox(width: 10),
              ],

              const SizedBox(width: 10),

              _buildCircularButton(
                icon: Icons.menu,
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
        ),

        if (isExternalMode && !_isStreaming)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gamepad, size: 80, color: Colors.white.withOpacity(0.2)),
                    Text("Modo Externo", style: TextStyle(color: Colors.white.withOpacity(0.2))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _unlockOrientation();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        
        endDrawer: GamepadSettingsDrawer(
          hapticFeedbackEnabled: _hapticFeedbackEnabled,
          rumbleEnabled: _rumbleEnabled,
          gyroscopeEnabled: _gyroscopeEnabled,
          accelerometerEnabled: _accelerometerEnabled,
          isExternalMode: isExternalMode,
          externalDigitalTriggersEnabled: _externalDigitalTriggersEnabled,
          isTransparentMode: _isTransparentMode,
          isTouchpadEnabled: _isTouchpadEnabled,
          mouseSensitivity: _mouseSensitivity,
          isImmersiveMode: _isImmersiveMode,
          
          // NOVOS PARÂMETROS
          isStreamingEnabled: _isServerStreamingEnabled,
          isAudioEnabled: _isAudioEnabled,
          
          onHapticChanged: (v) => _toggleHapticFeedback(v).then((_) => setState((){})),
          onRumbleChanged: (v) => _toggleRumble(v).then((_) => setState((){})),
          onGyroChanged: (v) => _toggleGyroscope(v).then((_) => setState((){})),
          onAccelChanged: (v) => _toggleAccelerometer(v).then((_) => setState((){})),
          onExternalTriggerChanged: (v) => _toggleExternalDigitalTriggers(v).then((_) => setState((){})),
          onTransparentChanged: (v) { setState(() => _isTransparentMode = v); _storageService.setButtonStyleTransparent(v); },
          onTouchpadChanged: (v) { setState(() => _isTouchpadEnabled = v); _storageService.setTouchpadEnabled(v); },
          onMouseSensitivityChanged: (v) { setState(() => _mouseSensitivity = v); _storageService.setMouseSensitivity(v); },
          onImmersiveModeChanged: (v) { setState(() => _isImmersiveMode = v); _storageService.setViewModeImmersive(v); },
          
          // NOVOS CALLBACKS
          onStreamingChanged: (enabled) {
             setState(() => _isServerStreamingEnabled = enabled);
             _connectionService.sendSignalingMessage({
                 'type': 'toggle_stream_master',
                 'enabled': enabled
             });
             if (!enabled && _isStreaming) _stopStreaming();
          },
          
          onAudioChanged: _toggleAudio,
          
          onDisconnect: () {
             _unlockOrientation();
             Navigator.pop(context);
          },
        ),
        
        body: SafeArea(
          top: !_isImmersiveMode,
          bottom: false,
          left: false,
          right: false,
          child: mainContent,
        ),
      ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onPressed, bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.6),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: isLoading 
        ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
        : IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
    );
  }

  Widget _buildPredefinedGamepadView() {
    return GamepadLayoutView(
      gamepadState: _gamepadState,
      vibrationService: _vibrationService,
      storageService: _storageService,
      layout: _predefinedLayout,
      hapticFeedbackEnabled: _hapticFeedbackEnabled,
      layoutType: _selectedLayoutType,
      isTransparent: _isTransparentMode,
      onShowSettings: () => _scaffoldKey.currentState?.openEndDrawer(),
    );
  }

  Widget _buildExternalGamepadView() {
    return Container();
  }
}