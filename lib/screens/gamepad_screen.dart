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


// =============================================
// TELA PRINCIPAL DO CONTROLE VIRTUAL
// =============================================

/// Tela que exibe o gamepad virtual e gerencia todas as entradas
class GamepadScreen extends StatefulWidget {
  const GamepadScreen({super.key});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> with WidgetsBindingObserver {
  // =============================================
  // SERVIÇOS DE GERENCIAMENTO
  // =============================================
  
  /// Gerencia conexões com servidores
  final ConnectionService _connectionService = ConnectionService();
  
  /// Gerencia armazenamento local de configurações
  final StorageService _storageService = StorageService();
  
  /// Controla feedback háptico e vibração
  final VibrationService _vibrationService = VibrationService();
  
  /// Captura dados de sensores (giroscópio, acelerômetro)
  final SensorService _sensorService = SensorService();
  
  /// Gerencia entradas de gamepads físicos externos
  final GamepadInputService _gamepadInputService = GamepadInputService();
  
  /// Estado centralizado do gamepad (botões, analógicos, sensores)
  final GamepadStateService _gamepadState = GamepadStateService();

  // =============================================
  // VARIÁVEIS DE ESTADO DA INTERFACE
  // =============================================
  
  /// Estado atual da conexão com servidor
  models.ConnectionState _connectionState = models.ConnectionState.disconnected();
  
  /// Estado de gamepad físico externo (se conectado)
  models.ConnectionState _externalGamepadState = models.ConnectionState.disconnected();
  
  /// Layout visual pré-definido do gamepad (Xbox, PlayStation, Nintendo)
  GamepadLayout _predefinedLayout = GamepadLayout.xbox;
  
  /// Flag de carregamento inicial
  bool _isLoading = true;
  
  /// Tipo de layout selecionado
  GamepadLayoutType _selectedLayoutType = GamepadLayoutType.xbox;
  
  /// Configurações de funcionalidades do usuário
  bool _hapticFeedbackEnabled = true;
  bool _gyroscopeEnabled = true;
  bool _accelerometerEnabled = true;
  bool _rumbleEnabled = true;
  bool _externalDigitalTriggersEnabled = false;

  // =============================================
  // TIMERS E STREAMS
  // =============================================
  
  /// Timer principal do loop do jogo (envio de dados)
  Timer? _gameLoopTimer;
  
  /// Timer para verificação periódica da conexão
  Timer? _connectionCheckTimer;
  
  /// Subscription do estado da conexão
  StreamSubscription<models.ConnectionState>? _connectionStateSubscription;

  // CORREÇÃO: Subscriptions para Gamepad Externo para evitar vazamento de memória
  StreamSubscription<models.ConnectionState>? _externalConnectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _externalInputSubscription;
  StreamSubscription<SensorData>? _gyroscopeSubscription;
  StreamSubscription<SensorData>? _accelerometerSubscription;

  // =============================================
  // MAPEAMENTO DE BOTÕES EXTERNOS
  // =============================================
  
  /// Mapeia botões físicos para tipos internos baseado no layout
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

  // =============================================
  // INICIALIZAÇÃO E CICLO DE VIDA
  // =============================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGamepad();
    // Configura tela em landscape imersivo
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Limpeza completa de recursos
    _stopGameLoop();
    _connectionCheckTimer?.cancel();

    // Cancelamento seguro de subscriptions
    _connectionStateSubscription?.cancel();
    _externalConnectionSubscription?.cancel();
    _externalInputSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription?.cancel();

    // Parar sensores e liberar recursos locais
    _sensorService.dispose(); // SensorService é local, ok descartar
    _gamepadState.dispose();

    // CORREÇÃO: Não descartar singletons (_connectionService, _gamepadInputService)

    _unlockOrientation();

    // CORREÇÃO: Wakelock desativado com segurança
    try {
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("Erro ao desativar Wakelock: $e");
    }

    WidgetsBinding.instance.removeObserver(this);
    // Restaura UI padrão do sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // CORREÇÃO: Economia de bateria - Pausar sensores e loop quando em background
      _sensorService.stopAllSensors();
      _stopGameLoop();
    } else if (state == AppLifecycleState.resumed) {
      // Retomar sensores e loop
      _startEnabledSensors();
      _startGameLoop();
      _connectionService.checkConnectionStatus();
    }
  }

  // =============================================
  // INICIALIZAÇÃO DO GAMEPAD
  // =============================================

  /// Configura todos os serviços e inicia funcionalidades
  Future<void> _initializeGamepad() async {
    await _gamepadInputService.initialize();
    _lockToLandscape();
    WakelockPlus.enable(); // Mantem tela ligada
    _gamepadState.initialize();
    await _loadSettingsAndLayout();

    // Escuta mudanças no estado da conexão
    _connectionStateSubscription = _connectionService.connectionStateStream.listen((newState) {
      if (mounted) {
        setState(() {
          _connectionState = newState;
        });

        if (!newState.isConnected) {
          _stopGameLoop(); // Para envio de dados se desconectado
        } else {
          _startGameLoop();
        }
      }
    });

    // Escuta gamepads físicos externos
    _externalConnectionSubscription = _gamepadInputService.connectionStream.listen((state) {
      if (mounted) setState(() => _externalGamepadState = state);
    });
    _externalInputSubscription = _gamepadInputService.inputStream.listen(_onExternalGamepadInput);

    if (mounted) {
      setState(() {
        _externalGamepadState = _gamepadInputService.currentState;
        _connectionState = _connectionService.currentState;
        _isLoading = false;
      });
    }
    
    _startGameLoop();
    await _startEnabledSensors();
    
    // Configura listeners de sensores
    _gyroscopeSubscription = _sensorService.gyroscopeStream.listen(_updateGyroState);
    _accelerometerSubscription = _sensorService.accelerometerStream.listen(_updateAccelState);

    // Configura verificação periódica de conexão
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _connectionService.checkConnectionStatus();
    });
  }

  // =============================================
  // LOOP PRINCIPAL DO JOGO
  // =============================================

  /// Inicia o timer para envio periódico de dados ao PC
  void _startGameLoop() {
    _stopGameLoop(); // Garante que não existem duplicatas
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 8), (timer) {
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

  /// Atualiza estado do giroscópio no gamepad
  void _updateGyroState(SensorData gyroData) {
    _gamepadState.updateGyroState(gyroData, _gyroscopeEnabled);
  }

  /// Atualiza estado do acelerômetro no gamepad
  void _updateAccelState(SensorData accelData) {
    _gamepadState.updateAccelState(accelData, _accelerometerEnabled);
  }

  /// Envia dados do gamepad para o servidor PC
  void _sendGamepadData() {
    // CORREÇÃO: Tratamento de erro no envio de dados
    try {
      final data = _gamepadState.getGamepadInputData();
      _connectionService.sendGamepadData(data);
    } catch (e) {
      debugPrint("Erro ao enviar dados do gamepad: $e");
      // Opcional: Tentar reconectar ou notificar usuário se o erro persistir
    }
  }

  // =============================================
  // GERENCIAMENTO DE CONFIGURAÇÕES
  // =============================================

  /// Alterna feedback háptico ao tocar botões
  Future<void> _toggleHapticFeedback(bool enabled) async { 
    await _storageService.setHapticFeedbackEnabled(enabled); 
    setState(() => _hapticFeedbackEnabled = enabled); 
  }
  
  /// Alterna vibração recebida do jogo
  Future<void> _toggleRumble(bool enabled) async { 
    await _storageService.setRumbleEnabled(enabled); 
    setState(() => _rumbleEnabled = enabled); 
  }
  
  /// Alterna envio de dados do giroscópio
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
  
  /// Alterna envio de dados do acelerômetro
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

  /// Alterna gatilhos digitais para gamepads externos
  Future<void> _toggleExternalDigitalTriggers(bool enabled) async { 
    await _storageService.setExternalDigitalTriggersEnabled(enabled); 
    setState(() => _externalDigitalTriggersEnabled = enabled); 
  }

  // =============================================
  // CONSTRUÇÃO DA INTERFACE PRINCIPAL
  // =============================================

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
                ? _buildExternalGamepadView() // Modo gamepad físico
                : _buildPredefinedGamepadView(), // Modo gamepad virtual
      ),
    );
  }

  // =============================================
  // PAINEL DE CONFIGURAÇÕES
  // =============================================

  /// Exibe modal com opções de configuração
  void _showSettingsPanel() {
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
                  
                  // Configurações para modo virtual
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
                  
                  // Configurações gerais
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
                  
                  // Configurações específicas para modo externo
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

  // =============================================
  // PROCESSAMENTO DE ENTRADAS EXTERNAS
  // =============================================

  /// Processa entradas de gamepads físicos conectados
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

  // =============================================
  // CARREGAMENTO DE CONFIGURAÇÕES
  // =============================================

  /// Carrega configurações salvas e layout do usuário
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

  /// Inicia sensores que estão habilitados nas configurações
  Future<void> _startEnabledSensors() async {
    if (_gyroscopeEnabled) await _sensorService.startGyroscope();
    if (_accelerometerEnabled) await _sensorService.startAccelerometer();
  }

  // =============================================
  // CONTROLE DE ORIENTAÇÃO DA TELA
  // =============================================

  /// Trava tela em landscape para experiência de gamepad
  void _lockToLandscape() => SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft, 
    DeviceOrientation.landscapeRight
  ]);

  /// Libera orientação da tela
  void _unlockOrientation() => SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  // =============================================
  // INTERFACE DO MODO GAMEPAD EXTERNO
  // =============================================

  /// Constroi interface para quando gamepad físico está conectado
  Widget _buildExternalGamepadView() {
    return Stack(
      children: [
        // Botão voltar
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
        // Botão configurações
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
        // Status da conexão centralizado
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
        // Conteúdo principal do modo externo
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

  // =============================================
  // INTERFACE DO GAMEPAD VIRTUAL PADRÃO
  // =============================================

  /// Constroi interface do gamepad virtual personalizável
  Widget _buildPredefinedGamepadView() {
    return Stack(
      children: [
        // View principal do layout do gamepad
        GamepadLayoutView(
          gamepadState: _gamepadState,
          vibrationService: _vibrationService,
          storageService: _storageService,
          layout: _predefinedLayout,
          hapticFeedbackEnabled: _hapticFeedbackEnabled,
          layoutType: _selectedLayoutType,
          onShowSettings: _showSettingsPanel,
        ),
        // Botão voltar
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
        // Status da conexão centralizado
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
}