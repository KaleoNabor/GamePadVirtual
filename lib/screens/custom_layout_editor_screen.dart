import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepadvirtual/models/custom_layout.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/widgets/analog_stick.dart';

enum ActionButtonStyle { none, xbox, nintendo, playstation }

class CustomLayoutEditorScreen extends StatefulWidget {
  const CustomLayoutEditorScreen({super.key});

  @override
  State<CustomLayoutEditorScreen> createState() =>
      _CustomLayoutEditorScreenState();
}

class _CustomLayoutEditorScreenState extends State<CustomLayoutEditorScreen> {
  final StorageService _storageService = StorageService();

  List<CustomLayoutButton> _buttons = [];
  CustomLayoutButton? _selectedButton;
  bool _enableVibration = true;
  bool _enableGyroscope = true;
  bool _enableAccelerometer = true;

  bool _leftStickEnabled = true;
  ButtonPosition _leftStickPosition =
      const ButtonPosition(x: 40, y: 140, size: 120);
  bool _rightStickEnabled = true;
  ButtonPosition _rightStickPosition =
      const ButtonPosition(x: 680, y: 140, size: 120);

  static const double _minButtonSize = 44.0;
  static const double _maxButtonSize = 140.0;

  bool _dpadEnabled = false;
  ActionButtonStyle _actionStyle = ActionButtonStyle.none;

  final Map<ButtonType, bool> _availableButtons = {
    ButtonType.leftBumper: false,
    ButtonType.rightBumper: false,
    ButtonType.leftTrigger: false,
    ButtonType.rightTrigger: false,
    ButtonType.leftStickButton: false,
    ButtonType.rightStickButton: false,
    ButtonType.select: false,
    ButtonType.start: false,
  };

  @override
  void initState() {
    super.initState();
    _lockToLandscape();
    _loadExistingLayout();
  }

  @override
  void dispose() {
    _unlockOrientation();
    super.dispose();
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

  Future<void> _loadExistingLayout() async {
    final customLayouts = await _storageService.getCustomLayouts();
    if (customLayouts.isNotEmpty) {
      final layout = customLayouts.first;
      setState(() {
        _buttons = List.from(layout.buttons);
        _enableVibration = layout.enableVibration;
        _enableGyroscope = layout.enableGyroscope;
        _enableAccelerometer = layout.enableAccelerometer;
        _leftStickEnabled = layout.hasLeftStick;
        _leftStickPosition = layout.leftStickPosition;
        _rightStickEnabled = layout.hasRightStick;
        _rightStickPosition = layout.rightStickPosition;
        _dpadEnabled = _buttons.any((b) => _isDpad(b.type));
        if (_buttons.any((b) => _isXboxAction(b.type))) {
          _actionStyle = ActionButtonStyle.xbox;
        } else if (_buttons.any((b) => _isNintendoAction(b.type))) {
          _actionStyle = ActionButtonStyle.nintendo;
        } else if (_buttons.any((b) => _isPlayStationAction(b.type))) {
          _actionStyle = ActionButtonStyle.playstation;
        } else {
          _actionStyle = ActionButtonStyle.none;
        }
        for (final button in _buttons) {
          if (_availableButtons.containsKey(button.type)) {
            _availableButtons[button.type] = true;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface.withAlpha(204),
                  ],
                ),
              ),
            ),
            Positioned( top: 10, left: 10, child: Row( children: [ IconButton( onPressed: () { _unlockOrientation(); Navigator.pop(context); }, icon: const Icon(Icons.arrow_back), style: IconButton.styleFrom( backgroundColor: Colors.white.withAlpha(230), ), ), const SizedBox(width: 16), Text( 'Editar Layout', style: Theme.of(context).textTheme.titleLarge, ), ], ), ),
            Positioned( top: 10, right: 10, child: Row( children: [ IconButton( onPressed: _showSettingsMenu, icon: const Icon(Icons.menu), style: IconButton.styleFrom( backgroundColor: Colors.white.withAlpha(230), ), tooltip: 'Configurações', ), const SizedBox(width: 8), ElevatedButton( onPressed: _saveLayout, style: ElevatedButton.styleFrom( backgroundColor: Theme.of(context).colorScheme.primary, ), child: const Text('Salvar', style: TextStyle(color: Colors.white)), ), ], ), ),
            if (_leftStickEnabled)
              Positioned(
                left: _leftStickPosition.x,
                top: _leftStickPosition.y,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final newX = (_leftStickPosition.x + details.delta.dx).clamp(0.0, screenSize.width - _leftStickPosition.size);
                      final newY = (_leftStickPosition.y + details.delta.dy).clamp(60.0, screenSize.height - _leftStickPosition.size - 20);
                      _leftStickPosition = _leftStickPosition.copyWith(x: newX, y: newY);
                    });
                  },
                  child: AbsorbPointer(
                    child: AnalogStick(
                      size: _leftStickPosition.size,
                      label: 'L',
                      isLeft: true,
                      onChanged: (x, y) {},
                    ),
                  ),
                ),
              ),
            if (_rightStickEnabled)
              Positioned(
                left: _rightStickPosition.x,
                top: _rightStickPosition.y,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final newX = (_rightStickPosition.x + details.delta.dx).clamp(0.0, screenSize.width - _rightStickPosition.size);
                      final newY = (_rightStickPosition.y + details.delta.dy).clamp(60.0, screenSize.height - _rightStickPosition.size - 20);
                      _rightStickPosition = _rightStickPosition.copyWith(x: newX, y: newY);
                    });
                  },
                  child: AbsorbPointer(
                    child: AnalogStick(
                      size: _rightStickPosition.size,
                      label: 'R',
                      isLeft: false,
                      onChanged: (x, y) {},
                    ),
                  ),
                ),
              ),
            ..._buttons.map((button) => _buildDraggableButton(button, screenSize)),
            if (_selectedButton != null)
              Positioned(
                left: _selectedButton!.position.x - 5,
                top: _selectedButton!.position.y - 5,
                child: IgnorePointer(
                  child: Container(
                    width: _selectedButton!.position.size * (_isShoulderButton(_selectedButton!.type) ? 1.5 : 1.0) + 10,
                    height: _selectedButton!.position.size + 10,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(_isShoulderButton(_selectedButton!.type) ? 20 : _selectedButton!.position.size / 2 + 5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isDpad(ButtonType t) => t == ButtonType.dpadUp || t == ButtonType.dpadDown || t == ButtonType.dpadLeft || t == ButtonType.dpadRight;
  bool _isAction(ButtonType t) => _isXboxAction(t) || _isNintendoAction(t) || _isPlayStationAction(t);
  bool _isXboxAction(ButtonType t) => t == ButtonType.a || t == ButtonType.b || t == ButtonType.x || t == ButtonType.y;
  bool _isNintendoAction(ButtonType t) => t == ButtonType.a || t == ButtonType.b || t == ButtonType.x || t == ButtonType.y;
  bool _isPlayStationAction(ButtonType t) => t == ButtonType.square || t == ButtonType.triangle || t == ButtonType.circle || t == ButtonType.cross;
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

  Widget _buildDraggableButton(CustomLayoutButton button, Size screenSize) {
    final isGroupMember = _isDpad(button.type) || _isAction(button.type);
    return Positioned(
      left: button.position.x,
      top: button.position.y,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedButton = _selectedButton == button ? null : button;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            if (isGroupMember) {
              _moveGroupAsUnit(button.type, details.delta, screenSize);
            } else {
              final newWidth = button.position.size * (_isShoulderButton(button.type) ? 1.5 : 1.0);
              final newX = (button.position.x + details.delta.dx).clamp(0.0, screenSize.width - newWidth);
              final newY = (button.position.y + details.delta.dy).clamp(60.0, screenSize.height - button.position.size - 20);
              final updatedButton = button.copyWith(position: button.position.copyWith(x: newX, y: newY));
              final index = _buttons.indexWhere((b) => b.type == button.type);
              if (index != -1) {
                _buttons[index] = updatedButton;
                if (_selectedButton?.type == button.type) {
                  _selectedButton = updatedButton;
                }
              }
            }
          });
        },
        child: Container(
          width: button.position.size * (_isShoulderButton(button.type) ? 1.5 : 1.0),
          height: button.position.size,
          decoration: BoxDecoration(
            color: Color(button.color),
            borderRadius: BorderRadius.circular(_isShoulderButton(button.type) ? 20 : 100),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [ BoxShadow( color: Colors.black.withAlpha(77), blurRadius: 4, offset: const Offset(0, 2), ), ],
          ),
          child: Center(child: _buildButtonChild(button)),
        ),
      ),
    );
  }

  void _moveGroupAsUnit(ButtonType memberType, Offset delta, Size screenSize) {
    List<ButtonType> groupTypes;
    if (_isDpad(memberType)) {
      groupTypes = const [ButtonType.dpadUp, ButtonType.dpadDown, ButtonType.dpadLeft, ButtonType.dpadRight];
    } else {
      groupTypes = _actionTypesFor(_actionStyle);
    }
    final groupButtons = _buttons.where((b) => groupTypes.contains(b.type)).toList();
    if (groupButtons.isEmpty) return;
    double currentCenterX = groupButtons.map((b) => b.position.x).reduce((a, b) => a + b) / groupButtons.length;
    double currentCenterY = groupButtons.map((b) => b.position.y).reduce((a, b) => a + b) / groupButtons.length;
    final newCenterX = currentCenterX + delta.dx;
    final newCenterY = currentCenterY + delta.dy;
    _repositionGroupFromCenter(groupTypes, Offset(newCenterX, newCenterY), groupButtons.first.position.size, screenSize);
  }

  void _repositionGroupFromCenter(List<ButtonType> groupTypes, Offset newCenter, double size, Size screenSize) {
      final double offset = size * 0.8; 
      if (groupTypes.length < 4) return;
      final Map<ButtonType, Offset> relativeOffsets = {
        groupTypes[0]: Offset(0, -offset),       
        groupTypes[1]: Offset(offset, 0),        
        groupTypes[2]: Offset(0, offset),       
        groupTypes[3]: Offset(-offset, 0),       
      };
      for (var type in groupTypes) {
        final index = _buttons.indexWhere((b) => b.type == type);
        if (index != -1) {
          final relativeOffset = relativeOffsets[type]!;
          final newX = (newCenter.dx + relativeOffset.dx).clamp(0.0, screenSize.width - size);
          final newY = (newCenter.dy + relativeOffset.dy).clamp(60.0, screenSize.height - size - 20);
          _buttons[index] = _buttons[index].copyWith(
            position: _buttons[index].position.copyWith(x: newX, y: newY, size: size),
          );
           if (_selectedButton?.type == type) {
            _selectedButton = _buttons[index];
           }
        }
      }
  }

  void _showSettingsMenu() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setMenuState) {
          return Container(
            height:
                MediaQuery.of(context).size.height * (isLandscape ? 0.9 : 0.8),
            padding: const EdgeInsets.all(20),
            child: isLandscape
                ? Row(
                    children: [
                      Expanded(child: _buildSettingsLeft(setMenuState)),
                      const VerticalDivider(width: 24),
                      Expanded(child: _buildSettingsRight(setMenuState)),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSettingsLeft(setMenuState,
                            heightConstrained: false),
                        const Divider(),
                        _buildSettingsRight(setMenuState),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsLeft(void Function(void Function()) setMenuState,
      {bool heightConstrained = true}) {
    final itemsOrder = <ButtonType>[
      ButtonType.start,
      ButtonType.select,
      ButtonType.leftBumper,
      ButtonType.leftTrigger,
      ButtonType.leftStickButton,
      ButtonType.rightBumper,
      ButtonType.rightTrigger,
      ButtonType.rightStickButton,
    ];
    final listChild = ListView(
      shrinkWrap: !heightConstrained,
      children: [
        Text('Configurações do Layout', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SwitchListTile( title: const Text('Vibração'), subtitle: const Text('Ativa a resposta tátil do controle'), value: _enableVibration, onChanged: (value) { setMenuState(() { _enableVibration = value; }); }, ),
        SwitchListTile( title: const Text('Giroscópio'), subtitle: const Text('Envia dados de giroscópio'), value: _enableGyroscope, onChanged: (value) { setMenuState(() { _enableGyroscope = value; }); }, ),
        SwitchListTile( title: const Text('Acelerômetro'), subtitle: const Text('Envia dados de acelerômetro'), value: _enableAccelerometer, onChanged: (value) { setMenuState(() { _enableAccelerometer = value; }); }, ),
        const Divider(),
        SwitchListTile( title: const Text('Analógico Esquerdo (LS)'), value: _leftStickEnabled, onChanged: (value) { setState(() { _leftStickEnabled = value; }); setMenuState(() {}); }, ),
        SwitchListTile( title: const Text('Analógico Direito (RS)'), value: _rightStickEnabled, onChanged: (value) { setState(() { _rightStickEnabled = value; }); setMenuState(() {}); }, ),
        const Divider(),
        SwitchListTile( title: const Text('D‑Pad (conjunto)'), subtitle: const Text('Habilita as setas como um grupo'), value: _dpadEnabled, onChanged: (value) { setState(() { _dpadEnabled = value; if (value) { _addDpadGroup(); } else { _removeDpadGroup(); } }); setMenuState(() {}); }, ),
        ...itemsOrder.map((btnType) {
          final selected = _availableButtons[btnType] ?? false;
          return SwitchListTile(
            title: Text(_getButtonLabel(btnType)),
            value: selected,
            onChanged: (value) {
              setState(() {
                _availableButtons[btnType] = value;
                if (value) { _addButton(btnType); } else { _removeButton(btnType); }
              });
              setMenuState(() {});
            },
          );
        }),
      ],
    );
    return heightConstrained ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: listChild)]) : listChild;
  }

  Widget _buildSettingsRight(void Function(void Function()) setMenuState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conjunto de Ação (exclusivo)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              RadioListTile<ActionButtonStyle>( title: const Text('Xbox (A, B, X, Y)'), value: ActionButtonStyle.xbox, groupValue: _actionStyle, onChanged: (v) { setMenuState(() => _actionStyle = v ?? ActionButtonStyle.xbox); _setActionStyle(v ?? ActionButtonStyle.xbox); }, ),
              RadioListTile<ActionButtonStyle>( title: const Text('Nintendo (A, B, X, Y)'), value: ActionButtonStyle.nintendo, groupValue: _actionStyle, onChanged: (v) { setMenuState(() => _actionStyle = v ?? ActionButtonStyle.nintendo); _setActionStyle(v ?? ActionButtonStyle.nintendo); }, ),
              RadioListTile<ActionButtonStyle>( title: const Text('PlayStation (△ ○ ✕ □)'), value: ActionButtonStyle.playstation, groupValue: _actionStyle, onChanged: (v) { setMenuState( () => _actionStyle = v ?? ActionButtonStyle.playstation); _setActionStyle(v ?? ActionButtonStyle.playstation); }, ),
              RadioListTile<ActionButtonStyle>( title: const Text('Nenhum'), value: ActionButtonStyle.none, groupValue: _actionStyle, onChanged: (v) { setMenuState(() => _actionStyle = v ?? ActionButtonStyle.none); _setActionStyle(v ?? ActionButtonStyle.none); }, ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedButton != null) ...[
          Text('Tamanho do item selecionado', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _selectedButton!.position.size.clamp(_minButtonSize, _maxButtonSize),
            min: _minButtonSize,
            max: _maxButtonSize,
            divisions: ((_maxButtonSize - _minButtonSize) / 4).round(),
            label: _selectedButton!.position.size.round().toString(),
            onChanged: (value) {
              setState(() {
                final memberType = _selectedButton!.type;
                List<ButtonType> groupTypes = [];
                if (_isDpad(memberType)) {
                  groupTypes = const [ButtonType.dpadUp, ButtonType.dpadDown, ButtonType.dpadLeft, ButtonType.dpadRight];
                } else if (_isAction(memberType)) {
                  groupTypes = _actionTypesFor(_actionStyle);
                }
                if (groupTypes.isNotEmpty) {
                    final groupButtons = _buttons.where((b) => groupTypes.contains(b.type)).toList();
                    if (groupButtons.isEmpty) return;
                    double currentCenterX = groupButtons.map((b) => b.position.x).reduce((a, b) => a + b) / groupButtons.length;
                    double currentCenterY = groupButtons.map((b) => b.position.y).reduce((a, b) => a + b) / groupButtons.length;
                    _repositionGroupFromCenter(groupTypes, Offset(currentCenterX, currentCenterY), value, MediaQuery.of(context).size);
                } else {
                  final idx = _buttons.indexWhere((b) => b.type == _selectedButton!.type);
                  if (idx != -1) {
                    _buttons[idx] = _buttons[idx].copyWith(position: _buttons[idx].position.copyWith(size: value));
                    _selectedButton = _buttons[idx];
                  }
                }
              });
            },
          ),
        ],
      ],
    );
  }

  void _setActionStyle(ActionButtonStyle style) {
    setState(() {
      _removeActionButtons();
      _actionStyle = style;
      if (style != ActionButtonStyle.none) {
        _addActionButtons(style);
      }
    });
  }

  void _addActionButtons(ActionButtonStyle style) {
    final screen = MediaQuery.of(context).size;
    final centerX = screen.width - 180 - 60;
    final centerY = screen.height / 2 - 60;
    final types = _actionTypesFor(style);
    final actionButtons = _getActionButtonsForStyle(style);
    for (var gb in actionButtons) {
      if (!_buttons.any((b) => b.type == gb.type)) {
        _buttons.add( CustomLayoutButton( type: gb.type, label: gb.label, color: gb.color, position: const ButtonPosition(x: 0, y: 0, size: 60), hasVibration: _enableVibration, isVisible: true, ) );
      }
    }
    _repositionGroupFromCenter(types, Offset(centerX, centerY), 60.0, screen);
  }

  void _removeActionButtons() {
    _buttons.removeWhere((b) => _isAction(b.type)); // CORRIGIDO
  }

  void _addDpadGroup() {
    final screen = MediaQuery.of(context).size;
    final centerX = 180.0 + 60.0;
    final centerY = screen.height / 2 - 60;
    const types = [ ButtonType.dpadUp, ButtonType.dpadRight, ButtonType.dpadDown, ButtonType.dpadLeft, ];
    final labels = types.map(_getButtonLabel).toList();
    const color = 0xFF616161;
    for (int i = 0; i < types.length; i++) {
      if (!_buttons.any((b) => b.type == types[i])) {
        _buttons.add( CustomLayoutButton( type: types[i], label: labels[i], color: color, position: const ButtonPosition(x: 0, y: 0, size: 48), hasVibration: _enableVibration, isVisible: true, ), );
      }
    }
    _repositionGroupFromCenter(types, Offset(centerX, centerY), 48.0, screen);
  }

  void _removeDpadGroup() {
    _buttons.removeWhere((b) => _isDpad(b.type));
  }

  void _addButton(ButtonType buttonType) {
    if (_buttons.any((button) => button.type == buttonType)) return;
    final screenSize = MediaQuery.of(context).size;
    final newButton = CustomLayoutButton(
      type: buttonType,
      label: _getButtonLabel(buttonType),
      color: _getButtonColor(buttonType),
      position: ButtonPosition(
        x: screenSize.width / 2 - 30,
        y: screenSize.height / 2 - 30,
        size: 60,
      ),
      hasVibration: _enableVibration,
      isVisible: true,
    );
    setState(() {
      _buttons.add(newButton);
    });
  }

  void _removeButton(ButtonType buttonType) {
    setState(() {
      _buttons.removeWhere((button) => button.type == buttonType);
      if (_selectedButton?.type == buttonType) {
        _selectedButton = null;
      }
    });
  }
  
  List<ButtonType> _actionTypesFor(ActionButtonStyle style) { switch (style) { case ActionButtonStyle.xbox: return [ButtonType.y, ButtonType.b, ButtonType.a, ButtonType.x]; case ActionButtonStyle.nintendo: return [ButtonType.x, ButtonType.a, ButtonType.b, ButtonType.y]; case ActionButtonStyle.playstation: return [ButtonType.triangle, ButtonType.circle, ButtonType.cross, ButtonType.square]; case ActionButtonStyle.none: return const []; } }
  
  List<GamepadButton> _getActionButtonsForStyle(ActionButtonStyle style) { switch (style) { case ActionButtonStyle.xbox: return GamepadLayout.xbox.buttons; case ActionButtonStyle.nintendo: return GamepadLayout.nintendo.buttons; case ActionButtonStyle.playstation: return GamepadLayout.playstation.buttons; case ActionButtonStyle.none: return const []; } }
  
  String _getButtonLabel(ButtonType buttonType) {
    switch (buttonType) {
      case ButtonType.a: return 'A';
      case ButtonType.b: return 'B';
      case ButtonType.x: return 'X';
      case ButtonType.y: return 'Y';
      case ButtonType.square: return '□';
      case ButtonType.triangle: return '△';
      case ButtonType.circle: return '○';
      case ButtonType.cross: return '✕';
      case ButtonType.dpadUp: return '↑';
      case ButtonType.dpadDown: return '↓';
      case ButtonType.dpadLeft: return '←';
      case ButtonType.dpadRight: return '→';
      case ButtonType.leftBumper: return 'L1';
      case ButtonType.rightBumper: return 'R1';
      case ButtonType.leftTrigger: return 'L2';
      case ButtonType.rightTrigger: return 'R2';
      case ButtonType.leftStickButton: return 'L3';
      case ButtonType.rightStickButton: return 'R3';
      case ButtonType.select: return 'SELECT';
      case ButtonType.start: return 'START';
      case ButtonType.leftStick: return 'LS';
      case ButtonType.rightStick: return 'RS';
    }
  }

  int _getButtonColor(ButtonType buttonType) { if (_isAction(buttonType)) { List<GamepadButton> source; switch (_actionStyle) { case ActionButtonStyle.playstation: source = GamepadLayout.playstation.buttons; break; case ActionButtonStyle.nintendo: source = GamepadLayout.nintendo.buttons; break; case ActionButtonStyle.xbox: case ActionButtonStyle.none: source = GamepadLayout.xbox.buttons; break; } final found = source.where((b) => b.type == buttonType).toList(); if (found.isNotEmpty) return found.first.color; } return 0xFF616161; }
  
  Color _getTextColor(Color backgroundColor) { final luminance = backgroundColor.computeLuminance(); return luminance > 0.5 ? Colors.black : Colors.white; }
  
  Future<void> _saveLayout() async { if (_buttons.isEmpty && !_leftStickEnabled && !_rightStickEnabled) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Adicione pelo menos um botão ou analógico ao layout')), ); return; } final layoutName = 'Meu Layout'; await _storageService.deleteCustomLayout(layoutName); final customLayout = CustomLayout( name: layoutName, buttons: _buttons, enableVibration: _enableVibration, enableGyroscope: _enableGyroscope, enableAccelerometer: _enableAccelerometer, createdAt: DateTime.now(), updatedAt: DateTime.now(), hasLeftStick: _leftStickEnabled, leftStickPosition: _leftStickPosition, hasRightStick: _rightStickEnabled, rightStickPosition: _rightStickPosition, ); await _storageService.saveCustomLayout(customLayout); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Layout personalizado salvo com sucesso!')), ); Navigator.pop(context); }
}