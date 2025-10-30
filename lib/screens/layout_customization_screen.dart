// lib/screens/layout_customization_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepadvirtual/core/default_layout.dart';
import 'package:gamepadvirtual/models/button_layout_config.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/widgets/analog_stick.dart';

class LayoutCustomizationScreen extends StatefulWidget {
  const LayoutCustomizationScreen({super.key});

  @override
  State<LayoutCustomizationScreen> createState() =>
      _LayoutCustomizationScreenState();
}

class _LayoutCustomizationScreenState extends State<LayoutCustomizationScreen> {
  final StorageService _storageService = StorageService();

  List<ButtonLayoutConfig>? _layoutConfig;
  GamepadLayout _gamepadLayout = GamepadLayout.xbox;
  ConfigurableElement? _selectedElement;

  // (Request 3) Define a altura da "faixa" superior
  final double _topBarHeight = 60.0;

  @override
  void initState() {
    super.initState();
    // Tela cheia imersiva (sem barras)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadLayout();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _loadLayout() async {
    final baseType = await _storageService.getCustomLayoutBase();
    final configs = await _storageService.loadCustomLayout();
    
    if (mounted) {
      setState(() {
        _gamepadLayout = GamepadLayout.predefinedLayouts
            .firstWhere((l) => l.type == baseType);
        _layoutConfig = configs;
      });
    }
  }

  Future<void> _saveLayout() async {
    if (_layoutConfig == null) return;
    await _storageService.saveCustomLayout(_layoutConfig!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout salvo!')),
      );
    }
  }

  Future<void> _resetLayout() async {
    // Pede confirmação
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetar Layout?'),
        content: const Text('Isso retornará todos os botões às suas posições e tamanhos padrão.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resetar')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _storageService.resetLayoutToDefault();
    final configs = await _storageService.loadCustomLayout();
    if (mounted) {
      setState(() {
        _layoutConfig = configs;
        _selectedElement = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout resetado para o padrão.')),
      );
    }
  }

  void _showPropertiesDialog() {
    if (_selectedElement == null) return;
    
    final config = _layoutConfig!
        .firstWhere((c) => c.element == _selectedElement);

    double tempWidth = config.width;
    double tempHeight = config.height;
    bool tempIsVisible = config.isVisible;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Editar ${config.element.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Largura (${tempWidth.toInt()})'),
                  Slider(
                    value: tempWidth,
                    min: 40,
                    max: 250,
                    divisions: 21,
                    label: tempWidth.toInt().toString(),
                    onChanged: (value) => setDialogState(() => tempWidth = value),
                  ),
                  if (config.element != ConfigurableElement.analogLeft &&
                      config.element != ConfigurableElement.analogRight &&
                      config.element != ConfigurableElement.dpad &&
                      config.element != ConfigurableElement.actionButtons &&
                      config.element != ConfigurableElement.stickButtonLeft &&
                      config.element != ConfigurableElement.stickButtonRight &&
                      config.element != ConfigurableElement.floatingSettingsButton) ...[
                        Text('Altura (${tempHeight.toInt()})'),
                        Slider(
                          value: tempHeight,
                          min: 20,
                          max: 100,
                          divisions: 16,
                          label: tempHeight.toInt().toString(),
                          onChanged: (value) => setDialogState(() => tempHeight = value),
                        ),
                  ],
                  SwitchListTile(
                    title: const Text('Visível'),
                    value: tempIsVisible,
                    onChanged: (value) => setDialogState(() => tempIsVisible = value),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    setState(() {
                      final index = _layoutConfig!
                          .indexWhere((c) => c.element == _selectedElement);
                      if (index != -1) {
                        bool isSquare = [
                          ConfigurableElement.analogLeft,
                          ConfigurableElement.analogRight,
                          ConfigurableElement.dpad,
                          ConfigurableElement.actionButtons,
                          ConfigurableElement.stickButtonLeft,
                          ConfigurableElement.stickButtonRight,
                          ConfigurableElement.floatingSettingsButton
                        ].contains(config.element);

                        _layoutConfig![index] = _layoutConfig![index].copyWith(
                          width: tempWidth,
                          height: isSquare ? tempWidth : tempHeight,
                          isVisible: tempIsVisible,
                        );
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Remove o padding da barra de status
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Scaffold(
        // (Request 6) Remove a AppBar
        body: _layoutConfig == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Constrói todos os elementos arrastáveis
                  ..._layoutConfig!
                      .where((config) => config.isVisible)
                      .map((config) => _buildDraggableElement(config))
                      .toList(),
                  
                  // (Request 2) Adiciona a "faixa" superior
                  _buildTopBar(),
                ],
              ),
      ),
    );
  }

  // (Request 2) Widget da "faixa" superior
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: _topBarHeight,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botão Voltar
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              tooltip: 'Voltar',
              onPressed: () => Navigator.pop(context),
            ),
            const Text(
              'Arraste para mover, toque para selecionar',
              style: TextStyle(color: Colors.white70),
            ),
            Row(
              children: [
                // Botão de Propriedades
                IconButton(
                  icon: const Icon(Icons.tune),
                  color: _selectedElement != null ? Colors.white : Colors.grey,
                  tooltip: 'Propriedades',
                  onPressed: _selectedElement == null ? null : _showPropertiesDialog,
                ),
                // Botão de Resetar
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: Colors.white,
                  tooltip: 'Resetar Layout',
                  onPressed: _resetLayout,
                ),
                // Botão de Salvar
                IconButton(
                  icon: const Icon(Icons.save),
                  color: Colors.white,
                  tooltip: 'Salvar Layout',
                  onPressed: _saveLayout,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableElement(ButtonLayoutConfig config) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSelected = _selectedElement == config.element;

    return Positioned(
      // Multiplica as coordenadas relativas pelo tamanho da tela
      left: config.x * screenSize.width,
      top: config.y * screenSize.height,
      child: Draggable<ButtonLayoutConfig>(
        data: config,
        feedback: _buildElement(config, isFeedback: true),
        // (Request 4) Remove o "salto" ao não deixar um "childWhenDragging"
        onDragStarted: () {
          setState(() => _selectedElement = config.element);
        },
        onDragEnd: (details) {
          setState(() {
            final index = _layoutConfig!
                .indexWhere((c) => c.element == config.element);
            
            if (index != -1) {
              // (Request 3 & 7) Prende na tela e abaixo da "faixa"
              double newX = details.offset.dx.clamp(0, screenSize.width - config.width);
              double newY = details.offset.dy.clamp(_topBarHeight, screenSize.height - config.height);

              // Converte de volta para relativo (0.0-1.0) antes de salvar
              _layoutConfig![index] = config.copyWith(
                x: newX / screenSize.width, 
                y: newY / screenSize.height
              );
            }
          });
        },
        child: _buildElement(config, isSelected: isSelected),
      ),
    );
  }

  Widget _buildElement(ButtonLayoutConfig config, {bool isFeedback = false, bool isSelected = false}) {
    final child = Material(
      color: Colors.transparent,
      child: switch (config.element) {
        ConfigurableElement.analogLeft => AnalogStick(size: config.width, label: 'L', isLeft: true, onChanged: (x,y){}),
        ConfigurableElement.analogRight => AnalogStick(size: config.width, label: 'R', isLeft: false, onChanged: (x,y){}),
        ConfigurableElement.dpad => _buildDPad(config),
        ConfigurableElement.actionButtons => _buildActionButtons(config),
        ConfigurableElement.triggerLeft => _buildTriggerButton('L2', ButtonType.leftTrigger, config),
        ConfigurableElement.triggerRight => _buildTriggerButton('R2', ButtonType.rightTrigger, config),
        ConfigurableElement.bumperLeft => _buildShoulderButton('L1', ButtonType.leftBumper, config),
        ConfigurableElement.bumperRight => _buildShoulderButton('R1', ButtonType.rightBumper, config),
        ConfigurableElement.stickButtonLeft => _buildStickButton('L3', ButtonType.leftStickButton, config),
        ConfigurableElement.stickButtonRight => _buildStickButton('R3', ButtonType.rightStickButton, config),
        ConfigurableElement.select => _buildSystemButton('SELECT', ButtonType.select, config),
        ConfigurableElement.start => _buildSystemButton('START', ButtonType.start, config),
        // (Request 4) Renderiza o botão de Configurações
        ConfigurableElement.floatingSettingsButton => FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.settings),
        ),
      },
    );

    if (isFeedback) return child;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedElement = config.element);
      },
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 4)
                ]
              )
            : null,
        child: child,
      ),
    );
  }

  // --- Métodos de Build (Sem callbacks de input) ---
  // (O resto deste arquivo contém os métodos _build... que você já tem)
  // (Eles não precisam de alteração)
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
          Positioned(top: 0, left: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_up, buttonSize)),
          Positioned(bottom: 0, left: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_down, buttonSize)),
          Positioned(left: 0, top: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_left, buttonSize)),
          Positioned(right: 0, top: buttonSize, child: _buildDirectionalButton(Icons.keyboard_arrow_right, buttonSize)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ButtonLayoutConfig config) {
    final buttons = _gamepadLayout.buttons;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(button.color),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          button.label,
          style: TextStyle(
            color: _getTextColor(Color(button.color)),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
  
  Widget _buildDirectionalButton(IconData icon, double size) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    );
  }

  Widget _buildShoulderButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: config.width,
      height: config.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTriggerButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: config.width,
      height: config.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStickButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: config.width,
      height: config.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSystemButton(String label, ButtonType buttonType, ButtonLayoutConfig config) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: config.width,
      height: config.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}