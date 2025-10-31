// lib/widgets/gamepad_layout_view.dart

import 'package:flutter/material.dart';
import 'package:gamepadvirtual/models/button_layout_config.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/gamepad_state_service.dart';
import 'package:gamepadvirtual/core/default_layout.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/services/vibration_service.dart';
import 'package:gamepadvirtual/widgets/analog_stick.dart';

class GamepadLayoutView extends StatefulWidget {
  final GamepadStateService gamepadState;
  final VibrationService vibrationService;
  final StorageService storageService;
  final GamepadLayout layout;
  final bool hapticFeedbackEnabled;
  final GamepadLayoutType layoutType;
  final VoidCallback onShowSettings; 

  const GamepadLayoutView({
    super.key,
    required this.gamepadState,
    required this.vibrationService,
    required this.storageService,
    required this.layout,
    required this.hapticFeedbackEnabled,
    required this.layoutType,
    required this.onShowSettings,
  });

  @override
  State<GamepadLayoutView> createState() => _GamepadLayoutViewState();
}

class _GamepadLayoutViewState extends State<GamepadLayoutView> {
  List<ButtonLayoutConfig>? _layoutConfig;

  // Inicialização e atualização do widget
  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  @override
  void didUpdateWidget(covariant GamepadLayoutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutType != widget.layoutType) {
      _loadLayout();
    }
  }

  // Carrega layout personalizado ou padrão conforme seleção
  Future<void> _loadLayout() async {
    List<ButtonLayoutConfig> loadedLayout;

    if (widget.layoutType == GamepadLayoutType.custom) {
      final baseType = await widget.storageService.getCustomLayoutBase();
      loadedLayout = await widget.storageService.loadCustomLayout(baseType);
    } else {
      loadedLayout = defaultGamepadLayout;
    }

    if (mounted) {
      setState(() {
        _layoutConfig = loadedLayout;
      });
    }
  }

  // Métodos para controle de estado dos botões
  void _onButtonPressed(ButtonType buttonType) {
    widget.gamepadState.onButtonPressed(buttonType);
    if (widget.hapticFeedbackEnabled) widget.vibrationService.vibrateForButton();
  }

  void _onButtonReleased(ButtonType buttonType) {
    widget.gamepadState.onButtonReleased(buttonType);
  }

  void _onAnalogStickChanged(bool isLeft, double x, double y) {
    widget.gamepadState.onAnalogStickChanged(isLeft, x, y);
  }

  // Construção da interface principal do gamepad
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: widget.gamepadState,
      builder: (context, child) {
        if (_layoutConfig == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: _layoutConfig!
              .where((config) => config.isVisible)
              .map((config) => _buildPositionedElement(config, screenSize))
              .toList(),
        );
      },
    );
  }

  // Constrói elemento posicionado baseado na configuração
  Widget _buildPositionedElement(ButtonLayoutConfig config, Size screenSize) {
    Widget child;

    switch (config.element) {
      case ConfigurableElement.analogLeft:
        child = AnalogStick(
          size: config.width,
          label: 'L',
          isLeft: true,
          onChanged: (x, y) => _onAnalogStickChanged(true, x, y),
        );
        break;
      case ConfigurableElement.analogRight:
        child = AnalogStick(
          size: config.width,
          label: 'R',
          isLeft: false,
          onChanged: (x, y) => _onAnalogStickChanged(false, x, y),
        );
        break;
      case ConfigurableElement.dpad:
        child = _buildDPad(config);
        break;
      case ConfigurableElement.actionButtons:
        child = _buildActionButtons(config);
        break;
      case ConfigurableElement.triggerLeft:
        child = _buildTriggerButton('L2', ButtonType.leftTrigger, config);
        break;
      case ConfigurableElement.triggerRight:
        child = _buildTriggerButton('R2', ButtonType.rightTrigger, config);
        break;
      case ConfigurableElement.bumperLeft:
        child = _buildShoulderButton('L1', ButtonType.leftBumper, config);
        break;
      case ConfigurableElement.bumperRight:
        child = _buildShoulderButton('R1', ButtonType.rightBumper, config);
        break;
      case ConfigurableElement.stickButtonLeft:
        child = _buildStickButton('L3', ButtonType.leftStickButton, config);
        break;
      case ConfigurableElement.stickButtonRight:
        child = _buildStickButton('R3', ButtonType.rightStickButton, config);
        break;
      case ConfigurableElement.select:
        child = _buildSystemButton('SELECT', ButtonType.select, config);
        break;
      case ConfigurableElement.start:
        child = _buildSystemButton('START', ButtonType.start, config);
        break;
      case ConfigurableElement.floatingSettingsButton:
        child = FloatingActionButton(
          onPressed: widget.onShowSettings,
          child: const Icon(Icons.settings),
        );
        break;
    }

    return Positioned(
      left: config.x * screenSize.width,
      top: config.y * screenSize.height,
      child: child,
    );
  }

  // Métodos auxiliares para cálculo de cores
  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  // Métodos de construção de elementos específicos do gamepad
  Widget _buildDPad(ButtonLayoutConfig config) {
    final buttonSize = config.width / 3;
    
    return SizedBox(
      width: config.width,
      height: config.height,
      child: Stack(
        children: [
          Positioned(top: 0, left: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_up, ButtonType.dpadUp, buttonSize)),
          Positioned(bottom: 0, left: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_down, ButtonType.dpadDown, buttonSize)),
          Positioned(left: 0, top: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_left, ButtonType.dpadLeft, buttonSize)),
          Positioned(right: 0, top: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_right, ButtonType.dpadRight, buttonSize)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ButtonLayoutConfig config) {
    final buttons = widget.layout.buttons;
    final buttonSize = config.width / 3;
    
    return SizedBox(
      width: config.width,
      height: config.height,
      child: Stack(
        children: [
          if (buttons.isNotEmpty) Positioned(top: 0, left: buttonSize, child: _buildGamepadButton(buttons[0], buttonSize)),
          if (buttons.length > 1) Positioned(right: 0, top: buttonSize, child: _buildGamepadButton(buttons[1], buttonSize)),
          if (buttons.length > 2) Positioned(bottom: 0, left: buttonSize, child: _buildGamepadButton(buttons[2], buttonSize)),
          if (buttons.length > 3) Positioned(left: 0, top: buttonSize, child: _buildGamepadButton(buttons[3], buttonSize)),
        ],
      ),
    );
  }

  Widget _buildGamepadButton(GamepadButton button, double size) {
    final isPressed = widget.gamepadState.buttonStates[button.type] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(button.type),
      onTapUp: (_) => _onButtonReleased(button.type),
      onTapCancel: () => _onButtonReleased(button.type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: size,
        height: size,
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
              fontSize: size * 0.4
            )
          ),
        ),
      ),
    );
  }
  
  Widget _buildDirectionalButton(IconData icon, ButtonType buttonType, double size) {
    final isPressed = widget.gamepadState.buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPressed ? Colors.grey.shade600 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.6),
      ),
    );
  }

  Widget _buildShoulderButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    final isPressed = widget.gamepadState.buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
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

  Widget _buildTriggerButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    final isPressed = widget.gamepadState.buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
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

  Widget _buildStickButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    final isPressed = widget.gamepadState.buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
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

  Widget _buildSystemButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    final isPressed = widget.gamepadState.buttonStates[buttonType] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonType),
      onTapUp: (_) => _onButtonReleased(buttonType),
      onTapCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
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