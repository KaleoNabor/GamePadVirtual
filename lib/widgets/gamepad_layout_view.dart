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
  final bool isTransparent; // NOVO CAMPO

  const GamepadLayoutView({
    super.key,
    required this.gamepadState,
    required this.vibrationService,
    required this.storageService,
    required this.layout,
    required this.hapticFeedbackEnabled,
    required this.layoutType,
    required this.onShowSettings,
    required this.isTransparent, // Recebe no construtor
  });

  @override
  State<GamepadLayoutView> createState() => _GamepadLayoutViewState();
}

class _GamepadLayoutViewState extends State<GamepadLayoutView> {
  List<ButtonLayoutConfig>? _layoutConfig;

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

  Widget _buildPositionedElement(ButtonLayoutConfig config, Size screenSize) {
    Widget child;

    switch (config.element) {
      case ConfigurableElement.analogLeft:
        child = AnalogStick(
          size: config.width,
          label: 'L',
          isLeft: true,
          isTransparent: widget.isTransparent, // Passa a config
          onChanged: (x, y) => _onAnalogStickChanged(true, x, y),
        );
        break;
      case ConfigurableElement.analogRight:
        child = AnalogStick(
          size: config.width,
          label: 'R',
          isLeft: false,
          isTransparent: widget.isTransparent, // Passa a config
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

      // --- CORREÇÃO 3: REMOÇÃO DO BOTÃO AZUL ---
      // Removemos o case ConfigurableElement.floatingSettingsButton
      // Ou fazemos ele retornar um Container vazio caso a configuração antiga ainda exista no cache
      case ConfigurableElement.floatingSettingsButton:
        return const SizedBox.shrink(); // Não desenha nada
    }
    
    // Se por acaso cair num case vazio (como o floatingSettingsButton acima), 
    // retornamos SizedBox para não quebrar o Stack
    // (Mas o ideal é o código acima com break e atribuição de child, 
    // ou return direto no case. Como o switch original atribuía à variável 'child',
    // precisamos garantir que 'child' tenha valor ou retornar aqui).
    
    // Ajuste para garantir compilação segura:
    if (config.element == ConfigurableElement.floatingSettingsButton) {
        return const SizedBox.shrink();
    }

    return Positioned(
      left: config.x * screenSize.width,
      top: config.y * screenSize.height,
      child: child, // A variável child definida no switch acima
    );
  }

  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

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
    
    final Color baseColor = Color(button.color);
    
    final Color fillColor = widget.isTransparent 
        ? (isPressed ? baseColor.withOpacity(0.3) : Colors.transparent)
        : baseColor;
        
    final Color borderColor = widget.isTransparent 
        ? baseColor.withOpacity(0.8)
        : Colors.white;

    return GestureDetector(
      onPanStart: (details) => _onButtonPressed(button.type),
      onPanEnd: (_) => _onButtonReleased(button.type),
      onPanCancel: () => _onButtonReleased(button.type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: (isPressed || widget.isTransparent) ? [] : [
             BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Center(
          child: Text(
            button.label,
            style: TextStyle(
              color: widget.isTransparent ? borderColor : _getTextColor(baseColor),
              fontWeight: FontWeight.bold,
              fontSize: size * 0.4
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDirectionalButton(IconData icon, ButtonType buttonType, double size) {
    final isPressed = widget.gamepadState.buttonStates[buttonType] ?? false;
    
    // Lógica de Transparência para D-Pad
    final Color baseColor = Colors.grey.shade800;
    final Color fillColor = widget.isTransparent 
        ? (isPressed ? baseColor.withOpacity(0.3) : Colors.transparent)
        : (isPressed ? Colors.grey.shade600 : baseColor);
    final Color borderColor = widget.isTransparent 
        ? baseColor.withOpacity(0.8)
        : Colors.white;
    final Color iconColor = widget.isTransparent ? borderColor : Colors.white;

    return GestureDetector(
      onPanStart: (details) => _onButtonPressed(buttonType),
      onPanEnd: (_) => _onButtonReleased(buttonType),
      onPanCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(8),
          border: widget.isTransparent ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.6),
      ),
    );
  }

  Widget _buildShoulderButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    final isPressed = widget.gamepadState.buttonStates[buttonType] ?? false;
    
    // Lógica de Transparência para Shoulder Buttons
    final Color baseColor = Colors.grey.shade800;
    final Color fillColor = widget.isTransparent 
        ? (isPressed ? baseColor.withOpacity(0.3) : Colors.transparent)
        : (isPressed ? Colors.grey.shade600 : baseColor);
    final Color borderColor = widget.isTransparent 
        ? baseColor.withOpacity(0.8)
        : Colors.white;
    final Color textColor = widget.isTransparent ? borderColor : Colors.white;

    return GestureDetector(
      onPanStart: (details) => _onButtonPressed(buttonType),
      onPanEnd: (_) => _onButtonReleased(buttonType),
      onPanCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: widget.isTransparent ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
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
    
    // Lógica de Transparência para Trigger Buttons
    final Color baseColor = Colors.grey.shade700;
    final Color fillColor = widget.isTransparent 
        ? (isPressed ? baseColor.withOpacity(0.3) : Colors.transparent)
        : (isPressed ? Colors.grey.shade500 : baseColor);
    final Color borderColor = widget.isTransparent 
        ? baseColor.withOpacity(0.8)
        : Colors.white;
    final Color textColor = widget.isTransparent ? borderColor : Colors.white;

    return GestureDetector(
      onPanStart: (details) => _onButtonPressed(buttonType),
      onPanEnd: (_) => _onButtonReleased(buttonType),
      onPanCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(10),
          border: widget.isTransparent ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
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
    
    // Lógica de Transparência para Stick Buttons
    final Color baseColor = Colors.grey.shade800;
    final Color pressedColor = Colors.blue.shade600;
    final Color fillColor = widget.isTransparent 
        ? (isPressed ? pressedColor.withOpacity(0.3) : Colors.transparent)
        : (isPressed ? pressedColor : baseColor);
    final Color borderColor = widget.isTransparent 
        ? baseColor.withOpacity(0.8)
        : Colors.white;
    final Color textColor = widget.isTransparent ? borderColor : Colors.white;

    return GestureDetector(
      onPanStart: (details) => _onButtonPressed(buttonType),
      onPanEnd: (_) => _onButtonReleased(buttonType),
      onPanCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: widget.isTransparent ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
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
    
    // Lógica de Transparência para System Buttons
    final Color baseColor = Colors.grey.shade800;
    final Color fillColor = widget.isTransparent 
        ? (isPressed ? baseColor.withOpacity(0.3) : Colors.transparent)
        : (isPressed ? Colors.grey.shade600 : baseColor);
    final Color borderColor = widget.isTransparent 
        ? baseColor.withOpacity(0.8)
        : Colors.white;
    final Color textColor = widget.isTransparent ? borderColor : Colors.white;

    return GestureDetector(
      onPanStart: (details) => _onButtonPressed(buttonType),
      onPanEnd: (_) => _onButtonReleased(buttonType),
      onPanCancel: () => _onButtonReleased(buttonType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: config.width,
        height: config.height,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(20),
          border: widget.isTransparent ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold
            )
          )
        ),
      ),
    );
  }
}