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
  final double _topSafeMargin = 70.0;

  // Inicialização e configuração da tela
  @override
  void initState() {
    super.initState();
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

  // Métodos para carregar e salvar layouts
  Future<void> _loadLayout() async {
    final baseType = await _storageService.getCustomLayoutBase();
    final configs = await _storageService.loadCustomLayout(baseType);
    
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
    await _storageService.saveCustomLayout(_layoutConfig!, _gamepadLayout.type);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout salvo!')),
      );
    }
  }

  Future<void> _resetLayout() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetar Layout?'),
        content: const Text('Isso retornará todos os botões às suas posições e tamanhos padrão.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Cancelar')
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Resetar')
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _storageService.resetLayoutToDefault(_gamepadLayout.type);
    
    setState(() {
      _layoutConfig = List.from(defaultGamepadLayout);
      _selectedElement = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout resetado para o padrão.')),
      );
    }
  }

  // --- NOVO MÉTODO: Diálogo de Gerenciamento de Visibilidade ---
  void _showVisibilityManager() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Gerenciar Elementos'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _layoutConfig!.length,
                  itemBuilder: (context, index) {
                    final config = _layoutConfig![index];
                    return SwitchListTile(
                      title: Text(_getElementName(config.element)),
                      value: config.isVisible,
                      onChanged: (bool value) {
                        setModalState(() {
                          _layoutConfig![index] = config.copyWith(isVisible: value);
                        });
                        // Atualiza a tela principal também
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Concluir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Diálogo para editar propriedades dos elementos
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
              title: Text('Editar ${_getElementName(config.element)}'),
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text('Cancelar')
                ),
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

  // Construção da interface principal
  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Scaffold(
        body: _layoutConfig == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  ..._layoutConfig!
                      .where((config) => config.isVisible)
                      .map((config) => _buildDraggableElement(config))
                      ,
                  _buildTopBar(),
                ],
              ),
      ),
    );
  }

  // Barra superior de controle
  Widget _buildTopBar() {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(230), // ~90% opacity
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(102), // ~40% opacity
                blurRadius: 8,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                tooltip: 'Voltar',
                onPressed: () => Navigator.pop(context),
              ),
              const VerticalDivider(color: Colors.white24, indent: 10, endIndent: 10),
              
              // --- NOVO BOTÃO: GERENCIAR VISIBILIDADE ---
              IconButton(
                icon: const Icon(Icons.visibility),
                color: Colors.white,
                tooltip: 'Mostrar/Ocultar Botões',
                onPressed: _showVisibilityManager,
              ),
              
              IconButton(
                icon: const Icon(Icons.tune),
                color: _selectedElement != null ? Colors.white : Colors.white54,
                tooltip: 'Propriedades',
                onPressed: _selectedElement == null ? null : _showPropertiesDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                color: Colors.white,
                tooltip: 'Resetar Layout',
                onPressed: _resetLayout,
              ),
              IconButton(
                icon: const Icon(Icons.save),
                color: Colors.white,
                tooltip: 'Salvar Layout',
                onPressed: _saveLayout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Elementos arrastáveis do gamepad
  Widget _buildDraggableElement(ButtonLayoutConfig config) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSelected = _selectedElement == config.element;

    return Positioned(
      left: config.x * screenSize.width,
      top: config.y * screenSize.height,
      child: Draggable<ButtonLayoutConfig>(
        data: config,
        feedback: _buildElement(config, isFeedback: true),
        onDragStarted: () {
          setState(() => _selectedElement = config.element);
        },
        onDragEnd: (details) {
          setState(() {
            final index = _layoutConfig!
                .indexWhere((c) => c.element == config.element);
            
            if (index != -1) {
              double newX = details.offset.dx.clamp(0, screenSize.width - config.width);
              double newY = details.offset.dy.clamp(_topSafeMargin, screenSize.height - config.height);

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

  // Widgets para os diferentes tipos de elementos do gamepad
  Widget _buildElement(ButtonLayoutConfig config, {bool isFeedback = false, bool isSelected = false}) {
    final child = Material(
      color: Colors.transparent,
      child: _buildElementByType(config),
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
                  BoxShadow(
                    color: Colors.greenAccent.withAlpha(76), // ~30% opacity
                    blurRadius: 4
                  )
                ]
              )
            : null,
        child: child,
      ),
    );
  }

  // Método auxiliar para construir elementos por tipo
  Widget _buildElementByType(ButtonLayoutConfig config) {
    switch (config.element) {
      case ConfigurableElement.analogLeft:
        return AnalogStick(
          size: config.width, 
          label: 'L', 
          isLeft: true, 
          onChanged: (x, y){}
        );
      case ConfigurableElement.analogRight:
        return AnalogStick(
          size: config.width, 
          label: 'R', 
          isLeft: false, 
          onChanged: (x, y){}
        );
      case ConfigurableElement.dpad:
        return _buildDPad(config);
      case ConfigurableElement.actionButtons:
        return _buildActionButtons(config);
      case ConfigurableElement.triggerLeft:
        return _buildTriggerButton('L2', config);
      case ConfigurableElement.triggerRight:
        return _buildTriggerButton('R2', config);
      case ConfigurableElement.bumperLeft:
        return _buildShoulderButton('L1', config);
      case ConfigurableElement.bumperRight:
        return _buildShoulderButton('R1', config);
      case ConfigurableElement.stickButtonLeft:
        return _buildStickButton('L3', config);
      case ConfigurableElement.stickButtonRight:
        return _buildStickButton('R3', config);
      case ConfigurableElement.select:
        return _buildSystemButton('SELECT', config);
      case ConfigurableElement.start:
        return _buildSystemButton('START', config);
      case ConfigurableElement.floatingSettingsButton:
        return FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.blue,
          child: const Icon(Icons.settings, color: Colors.white),
        );
    }
  }

  // Métodos auxiliares para construção de elementos específicos
  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  String _getElementName(ConfigurableElement element) {
    switch (element) {
      case ConfigurableElement.analogLeft:
        return 'Analógico Esquerdo';
      case ConfigurableElement.analogRight:
        return 'Analógico Direito';
      case ConfigurableElement.dpad:
        return 'D-Pad';
      case ConfigurableElement.actionButtons:
        return 'Botões de Ação';
      case ConfigurableElement.triggerLeft:
        return 'Gatilho L2';
      case ConfigurableElement.triggerRight:
        return 'Gatilho R2';
      case ConfigurableElement.bumperLeft:
        return 'Botão L1';
      case ConfigurableElement.bumperRight:
        return 'Botão R1';
      case ConfigurableElement.stickButtonLeft:
        return 'Botão L3';
      case ConfigurableElement.stickButtonRight:
        return 'Botão R3';
      case ConfigurableElement.select:
        return 'Botão Select';
      case ConfigurableElement.start:
        return 'Botão Start';
      case ConfigurableElement.floatingSettingsButton:
        return 'Botão Configurações';
    }
  }

  Widget _buildDPad(ButtonLayoutConfig config) {
    final buttonSize = config.width / 3;
    return SizedBox(
      width: config.width,
      height: config.height,
      child: Stack(
        children: [
          Positioned(
            top: 0, 
            left: buttonSize, 
            child: _buildDirectionalButton(Icons.keyboard_arrow_up, buttonSize)
          ),
          Positioned(
            bottom: 0, 
            left: buttonSize, 
            child: _buildDirectionalButton(Icons.keyboard_arrow_down, buttonSize)
          ),
          Positioned(
            left: 0, 
            top: buttonSize, 
            child: _buildDirectionalButton(Icons.keyboard_arrow_left, buttonSize)
          ),
          Positioned(
            right: 0, 
            top: buttonSize, 
            child: _buildDirectionalButton(Icons.keyboard_arrow_right, buttonSize)
          ),
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
          if (buttons.isNotEmpty) 
            Positioned(
              top: 0, 
              left: buttonSize, 
              child: _buildGamepadButton(buttons[0], buttonSize)
            ),
          if (buttons.length > 1) 
            Positioned(
              right: 0, 
              top: buttonSize, 
              child: _buildGamepadButton(buttons[1], buttonSize)
            ),
          if (buttons.length > 2) 
            Positioned(
              bottom: 0, 
              left: buttonSize, 
              child: _buildGamepadButton(buttons[2], buttonSize)
            ),
          if (buttons.length > 3) 
            Positioned(
              left: 0, 
              top: buttonSize, 
              child: _buildGamepadButton(buttons[3], buttonSize)
            ),
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

  Widget _buildShoulderButton(String label, ButtonLayoutConfig config) {
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
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 14, 
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }

  Widget _buildTriggerButton(String label, ButtonLayoutConfig config) {
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
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 12, 
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }

  Widget _buildStickButton(String label, ButtonLayoutConfig config) {
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
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 12, 
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }

  Widget _buildSystemButton(String label, ButtonLayoutConfig config) {
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
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 10, 
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }
}