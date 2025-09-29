import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepadvirtual/models/custom_layout.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/widgets/analog_stick.dart';

enum ActionButtonStyle { none, xbox, nintendo, playstation }
enum SelectedComponentType { button, leftStick, rightStick }

class CustomLayoutEditorScreen extends StatefulWidget {
  const CustomLayoutEditorScreen({super.key});

  @override
  State<CustomLayoutEditorScreen> createState() =>
      _CustomLayoutEditorScreenState();
}

class _CustomLayoutEditorScreenState extends State<CustomLayoutEditorScreen> {
  // SERVICES
  final StorageService _storageService = StorageService();

  // STATE VARIABLES
  List<CustomLayoutButton> _buttons = [];
  CustomLayoutButton? _selectedButton;
  SelectedComponentType? _selectedComponentType;

  bool _enableVibration = true;
  bool _enableGyroscope = true;
  bool _enableAccelerometer = true;

  bool _leftStickEnabled = true;
  ButtonPosition _leftStickPosition =
      const ButtonPosition(x: 0.15, y: 0.5, size: 0.4);
  bool _rightStickEnabled = true;
  ButtonPosition _rightStickPosition =
      const ButtonPosition(x: 0.85, y: 0.5, size: 0.4);

  static const double _minButtonSize = 30.0;
  static const double _maxButtonSize = 140.0;

  bool _dpadEnabled = false;
  ActionButtonStyle _actionStyle = ActionButtonStyle.none;
  
  BoxConstraints? _canvasConstraints;

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

  // UI & LAYOUT LOGIC
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

  void _selectComponent(dynamic component) {
    setState(() {
      if ((component is CustomLayoutButton && component == _selectedButton) ||
          (component is ButtonPosition &&
              component ==
                  (_selectedComponentType == SelectedComponentType.leftStick
                      ? _leftStickPosition
                      : _rightStickPosition))) {
        _selectedButton = null;
        _selectedComponentType = null;
        return;
      }

      _selectedButton = null;
      _selectedComponentType = null;
      if (component is CustomLayoutButton) {
        _selectedButton = component;
        _selectedComponentType = SelectedComponentType.button;
      } else if (component == _leftStickPosition) {
        _selectedComponentType = SelectedComponentType.leftStick;
      } else if (component == _rightStickPosition) {
        _selectedComponentType = SelectedComponentType.rightStick;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Stack(
          children: [
            Positioned( top: 10, left: 10, child: Row( children: [ IconButton( onPressed: () { _unlockOrientation(); Navigator.pop(context); }, icon: const Icon(Icons.arrow_back), style: IconButton.styleFrom( backgroundColor: Colors.white.withAlpha(230), ), ), const SizedBox(width: 16), Text( 'Editar Layout', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white), ), ], ), ),
            Positioned( top: 10, right: 10, child: Row( children: [ IconButton( onPressed: _showSettingsMenu, icon: const Icon(Icons.menu), style: IconButton.styleFrom( backgroundColor: Colors.white.withAlpha(230), ), tooltip: 'Configurações', ), const SizedBox(width: 8), ElevatedButton( onPressed: _saveLayout, style: ElevatedButton.styleFrom( backgroundColor: Theme.of(context).colorScheme.primary, ), child: const Text('Salvar', style: TextStyle(color: Colors.white)), ), ], ), ),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 110.0),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasConstraints = constraints;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          border: Border.all(color: Colors.grey[700]!, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_leftStickEnabled) _buildDraggableComponent(_leftStickPosition, constraints),
                            if (_rightStickEnabled) _buildDraggableComponent(_rightStickPosition, constraints),
                            ..._buttons.map((button) => _buildDraggableComponent(button, constraints)),
                            if (_selectedComponentType != null) ..._buildSelectionIndicators(),
                          ],
                        ),
                      );
                    }
                  ),
                ),
              ),
            ),
            
            _buildSizeSlider(),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableComponent(dynamic component, BoxConstraints constraints) {
    final bool isButton = component is CustomLayoutButton;
    final ButtonPosition relativePos = isButton ? component.position : component as ButtonPosition;
    
    final double pixelX = relativePos.x * constraints.maxWidth;
    final double pixelY = relativePos.y * constraints.maxHeight;

    return Positioned(
      left: pixelX,
      top: pixelY,
      child: GestureDetector(
        onTap: () => _selectComponent(component),
        onPanUpdate: (details) {
          _selectComponent(component);

          final double dx = details.delta.dx / constraints.maxWidth;
          final double dy = details.delta.dy / constraints.maxHeight;

          if (isButton && (_isDpad(component.type) || _isAction(component.type))) {
            _moveGroupAsUnit(component.type, Offset(dx, dy));
          } else {
            final newX = (relativePos.x + dx);
            final newY = (relativePos.y + dy);
            setState(() {
              if (isButton) {
                final index = _buttons.indexWhere((b) => b == component);
                if (index != -1) _buttons[index] = component.copyWith(position: relativePos.copyWith(x: newX, y: newY));
              } else if (component == _leftStickPosition) {
                _leftStickPosition = _leftStickPosition.copyWith(x: newX, y: newY);
              } else if (component == _rightStickPosition) {
                _rightStickPosition = _rightStickPosition.copyWith(x: newX, y: newY);
              }
            });
          }
        },
        child: AbsorbPointer(child: _buildComponentVisual(component, constraints)),
      ),
    );
  }
  
  Widget _buildComponentVisual(dynamic component, BoxConstraints constraints) {
    final bool isButton = component is CustomLayoutButton;
    final ButtonPosition relativePos = isButton ? component.position : component as ButtonPosition;

    final double pixelSize = relativePos.size * constraints.maxHeight;
    final double? pixelWidth = relativePos.width != null ? relativePos.width! * constraints.maxHeight : null;
    
    if (!isButton) {
      return AnalogStick( size: pixelSize, label: component == _leftStickPosition ? 'L' : 'R', isLeft: component == _leftStickPosition, onChanged: (x,y) {}, );
    }
    
    final button = component as CustomLayoutButton;
    final isShoulder = _isShoulderButton(button.type);
    final isSystem = button.type == ButtonType.select || button.type == ButtonType.start;
    final isDpad = _isDpad(button.type);

    return Container(
      width: pixelWidth ?? pixelSize,
      height: pixelSize,
      decoration: BoxDecoration(
        color: isDpad ? Colors.grey.shade800 : Color(button.color),
        borderRadius: BorderRadius.circular(isShoulder || isSystem || isDpad ? 12 : 100),
      ),
      child: Center(child: _buildButtonChild(button, pixelSize)),
    );
  }

  Widget _buildButtonChild(CustomLayoutButton button, double pixelSize) {
    Color textColor = _getTextColor(Color(button.color));
    
    if (_isDpad(button.type)) {
      IconData icon;
      switch (button.type) {
        case ButtonType.dpadUp: icon = Icons.keyboard_arrow_up; break;
        case ButtonType.dpadDown: icon = Icons.keyboard_arrow_down; break;
        case ButtonType.dpadLeft: icon = Icons.keyboard_arrow_left; break;
        default: icon = Icons.keyboard_arrow_right;
      }
      return Icon(icon, color: Colors.white, size: pixelSize * 0.8);
    }
    return Text( button.label, style: TextStyle( color: textColor, fontWeight: FontWeight.bold, fontSize: pixelSize * 0.5, ), );
  }

  List<Widget> _buildSelectionIndicators() {
    if (_canvasConstraints == null) return [];
    
    List<dynamic> componentsToHighlight = [];
    if (_selectedComponentType == SelectedComponentType.button) {
      final members = _getGroupMembers(_selectedButton!.type);
      componentsToHighlight.addAll(members.isNotEmpty ? members : [_selectedButton!]);
    } else if (_selectedComponentType == SelectedComponentType.leftStick) {
      componentsToHighlight.add(_leftStickPosition);
    } else if (_selectedComponentType == SelectedComponentType.rightStick) {
      componentsToHighlight.add(_rightStickPosition);
    }

    return componentsToHighlight.map((component) {
      final ButtonPosition relativePos = (component is CustomLayoutButton) ? component.position : component as ButtonPosition;
      final bool isCircular = !(component is CustomLayoutButton) || (!_isShoulderButton(component.type) && component.type != ButtonType.select && component.type != ButtonType.start && !_isDpad(component.type));
      
      final pixelX = relativePos.x * _canvasConstraints!.maxWidth;
      final pixelY = relativePos.y * _canvasConstraints!.maxHeight;
      final pixelSize = relativePos.size * _canvasConstraints!.maxHeight;
      final pixelWidth = relativePos.width != null ? relativePos.width! * _canvasConstraints!.maxHeight : pixelSize;

      return Positioned(
        left: pixelX - 5,
        top: pixelY - 5,
        child: IgnorePointer(
          child: Container(
            width: pixelWidth + 10,
            height: pixelSize + 10,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
              borderRadius: BorderRadius.circular(isCircular ? pixelSize : 15),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSizeSlider() {
    bool isSelected = _selectedComponentType != null;
    double currentRelativeSize = 0.2;
    if (isSelected) {
      if (_selectedComponentType == SelectedComponentType.button) { currentRelativeSize = _selectedButton!.position.size; } 
      else if (_selectedComponentType == SelectedComponentType.leftStick) { currentRelativeSize = _leftStickPosition.size; } 
      else { currentRelativeSize = _rightStickPosition.size; }
    }
    
    final minRelativeSize = _minButtonSize / (_canvasConstraints?.maxHeight ?? 400);
    final maxRelativeSize = _maxButtonSize / (_canvasConstraints?.maxHeight ?? 400);

    return Positioned( top: 60, left: 20, right: 20, child: AnimatedOpacity( opacity: isSelected ? 1.0 : 0.0, duration: const Duration(milliseconds: 200), child: Card( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row( children: [ const Text('Tamanho:', style: TextStyle(fontWeight: FontWeight.bold)), Expanded( child: Slider( value: currentRelativeSize.clamp(minRelativeSize, maxRelativeSize), min: minRelativeSize, max: maxRelativeSize, onChanged: isSelected ? (value) {
      setState(() { if (_selectedComponentType == SelectedComponentType.button) { final button = _selectedButton!; final groupTypes = _getGroupTypes(button.type); if (groupTypes.isNotEmpty) { final groupButtons = _getGroupMembers(button.type); double cX = groupButtons.map((b) => b.position.x).reduce((a, b) => a + b) / groupButtons.length; double cY = groupButtons.map((b) => b.position.y).reduce((a, b) => a + b) / groupButtons.length; _repositionGroupFromCenter(groupTypes, Offset(cX, cY), value); } else { final idx = _buttons.indexWhere((b) => b.type == button.type); if (idx != -1) {_buttons[idx] = _buttons[idx].copyWith(position: _buttons[idx].position.copyWith(size: value)); _selectedButton = _buttons[idx];} } } else if (_selectedComponentType == SelectedComponentType.leftStick) { _leftStickPosition = _leftStickPosition.copyWith(size: value); } else if (_selectedComponentType == SelectedComponentType.rightStick) { _rightStickPosition = _rightStickPosition.copyWith(size: value); } }); } : null, ), ), ], ), ), ), ), );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setMenuState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                Text('Configurações do Layout', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                SwitchListTile( title: const Text('Vibração'), subtitle: const Text('Ativa a resposta tátil do controle'), value: _enableVibration, onChanged: (value) => setMenuState(() => _enableVibration = value),),
                SwitchListTile( title: const Text('Giroscópio'), subtitle: const Text('Envia dados de giroscópio'), value: _enableGyroscope, onChanged: (value) => setMenuState(() => _enableGyroscope = value),),
                SwitchListTile( title: const Text('Acelerômetro'), subtitle: const Text('Envia dados de acelerômetro'), value: _enableAccelerometer, onChanged: (value) => setMenuState(() => _enableAccelerometer = value),),
                const Divider(),
                SwitchListTile( title: const Text('Analógico Esquerdo (LS)'), value: _leftStickEnabled, onChanged: (value) { setState(() => _leftStickEnabled = value); setMenuState(() {}); },),
                SwitchListTile( title: const Text('Analógico Direito (RS)'), value: _rightStickEnabled, onChanged: (value) { setState(() => _rightStickEnabled = value); setMenuState(() {}); },),
                const Divider(),
                Text('Conjunto de Ação (exclusivo)', style: Theme.of(context).textTheme.titleMedium),
                Card( child: Column( children: [ RadioListTile<ActionButtonStyle>( title: const Text('Xbox (A, B, X, Y)'), value: ActionButtonStyle.xbox, groupValue: _actionStyle, onChanged: (v) { setMenuState(() => _actionStyle = v ?? ActionButtonStyle.xbox); _setActionStyle(v ?? ActionButtonStyle.xbox); }, ), RadioListTile<ActionButtonStyle>( title: const Text('Nintendo (A, B, X, Y)'), value: ActionButtonStyle.nintendo, groupValue: _actionStyle, onChanged: (v) { setMenuState(() => _actionStyle = v ?? ActionButtonStyle.nintendo); _setActionStyle(v ?? ActionButtonStyle.nintendo); }, ), RadioListTile<ActionButtonStyle>( title: const Text('PlayStation (△ ○ ✕ □)'), value: ActionButtonStyle.playstation, groupValue: _actionStyle, onChanged: (v) { setMenuState(() => _actionStyle = v ?? ActionButtonStyle.playstation); _setActionStyle(v ?? ActionButtonStyle.playstation); }, ), RadioListTile<ActionButtonStyle>( title: const Text('Nenhum'), value: ActionButtonStyle.none, groupValue: _actionStyle, onChanged: (v) { setMenuState(() => _actionStyle = v ?? ActionButtonStyle.none); _setActionStyle(v ?? ActionButtonStyle.none); }, ), ], ), ),
                const Divider(),
                SwitchListTile( title: const Text('D‑Pad (conjunto)'), subtitle: const Text('Habilita as setas como um grupo'), value: _dpadEnabled, onChanged: (value) { setState(() { _dpadEnabled = value; if (value) _addDpadGroup(); else _removeDpadGroup(); }); setMenuState(() {}); },),
                ..._availableButtons.entries.map((entry) {
                  final btnType = entry.key;
                  final isEnabled = _buttons.any((b) => b.type == btnType);
                  return SwitchListTile(
                    title: Text(_getButtonLabel(btnType)),
                    value: isEnabled,
                    onChanged: (value) {
                      setState(() {
                        if (value) _addButton(btnType); else _removeButton(btnType);
                      });
                      setMenuState(() {});
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // HELPER & LOGIC METHODS
  bool _isDpad(ButtonType t) => t == ButtonType.dpadUp || t == ButtonType.dpadDown || t == ButtonType.dpadLeft || t == ButtonType.dpadRight;
  bool _isAction(ButtonType t) => _isXboxAction(t) || _isNintendoAction(t) || _isPlayStationAction(t);
  bool _isXboxAction(ButtonType t) => t == ButtonType.a || t == ButtonType.b || t == ButtonType.x || t == ButtonType.y;
  bool _isNintendoAction(ButtonType t) => t == ButtonType.a || t == ButtonType.b || t == ButtonType.x || t == ButtonType.y;
  bool _isPlayStationAction(ButtonType t) => t == ButtonType.square || t == ButtonType.triangle || t == ButtonType.circle || t == ButtonType.cross;
  bool _isShoulderButton(ButtonType t) => t == ButtonType.leftBumper || t == ButtonType.rightBumper || t == ButtonType.leftTrigger || t == ButtonType.rightTrigger;
  
  List<ButtonType> _getGroupTypes(ButtonType memberType) { if (_isDpad(memberType)) { return const [ButtonType.dpadUp, ButtonType.dpadRight, ButtonType.dpadDown, ButtonType.dpadLeft]; } else if (_isAction(memberType)) { return _actionTypesFor(_actionStyle); } return []; }
  List<CustomLayoutButton> _getGroupMembers(ButtonType memberType) { final groupTypes = _getGroupTypes(memberType); if (groupTypes.isEmpty) return []; return _buttons.where((b) => groupTypes.contains(b.type)).toList(); }
  Color _getTextColor(Color backgroundColor) { return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white; }

  void _moveGroupAsUnit(ButtonType memberType, Offset proportionalDelta) { if (_canvasConstraints == null) return; final groupTypes = _getGroupTypes(memberType); final groupButtons = _getGroupMembers(memberType); if (groupButtons.isEmpty) return; double currentCenterX = groupButtons.map((b) => b.position.x).reduce((a, b) => a + b) / groupButtons.length; double currentCenterY = groupButtons.map((b) => b.position.y).reduce((a, b) => a + b) / groupButtons.length; final newCenterX = currentCenterX + proportionalDelta.dx; final newCenterY = currentCenterY + proportionalDelta.dy; _repositionGroupFromCenter(groupTypes, Offset(newCenterX, newCenterY), groupButtons.first.position.size); }
  void _repositionGroupFromCenter(List<ButtonType> groupTypes, Offset newCenter, double relSize) {
    if (_canvasConstraints == null) return;
    final double relOffset = relSize * 0.9; 
    if (groupTypes.isEmpty || groupTypes.length < 4) return;
    final Map<ButtonType, Offset> relativeOffsets = {
      ButtonType.dpadUp: Offset(0, -relOffset), ButtonType.dpadRight: Offset(relOffset, 0), ButtonType.dpadDown: Offset(0, relOffset), ButtonType.dpadLeft: Offset(-relOffset, 0),
      ButtonType.y: Offset(0, -relOffset), ButtonType.b: Offset(relOffset, 0), ButtonType.a: Offset(0, relOffset), ButtonType.x: Offset(-relOffset, 0),
      ButtonType.triangle: Offset(0, -relOffset), ButtonType.circle: Offset(relOffset, 0), ButtonType.cross: Offset(0, relOffset), ButtonType.square: Offset(-relOffset, 0),
    };
    setState(() {
      for (var type in groupTypes) {
        final index = _buttons.indexWhere((b) => b.type == type);
        if (index != -1) {
          final button = _buttons[index];
          final relativeOffset = relativeOffsets[type]!;
          final newRelX = newCenter.dx + (relativeOffset.dx / _canvasConstraints!.maxHeight);
          final newRelY = newCenter.dy + (relativeOffset.dy / _canvasConstraints!.maxHeight);
          _buttons[index] = button.copyWith( position: button.position.copyWith(x: newRelX, y: newRelY, size: relSize), );
          if (_selectedComponentType == SelectedComponentType.button && _selectedButton?.type == type) { _selectedButton = _buttons[index]; }
        }
      }
    });
  }

  void _setActionStyle(ActionButtonStyle style) { setState(() { _removeActionButtons(); _actionStyle = style; if (style != ActionButtonStyle.none) _addActionButtons(style); }); }
  void _addActionButtons(ActionButtonStyle style) { final types = _actionTypesFor(style); final actionButtons = _getActionButtonsForStyle(style); const relSize = 0.18; for (var gb in actionButtons) { if (!_buttons.any((b) => b.type == gb.type)) { _buttons.add( CustomLayoutButton( type: gb.type, label: gb.label, color: gb.color, position: ButtonPosition(x: 0, y: 0, size: relSize), hasVibration: _enableVibration, isVisible: true, ) ); } } _repositionGroupFromCenter(types, const Offset(0.8, 0.5), relSize); }
  void _removeActionButtons() { setState(() { _buttons.removeWhere((b) => _isAction(b.type)); }); }
  void _addDpadGroup() { const types = [ ButtonType.dpadUp, ButtonType.dpadRight, ButtonType.dpadDown, ButtonType.dpadLeft, ]; final labels = types.map(_getButtonLabel).toList(); const color = 0xFF616161; const relSize = 0.16; for (int i = 0; i < types.length; i++) { if (!_buttons.any((b) => b.type == types[i])) { _buttons.add( CustomLayoutButton( type: types[i], label: labels[i], color: color, position: ButtonPosition(x: 0, y: 0, size: relSize), hasVibration: _enableVibration, isVisible: true, ), ); } } _repositionGroupFromCenter(types, const Offset(0.25, 0.5), relSize); }
  void _removeDpadGroup() { setState(() { _buttons.removeWhere((b) => _isDpad(b.type)); }); }

  void _addButton(ButtonType buttonType) { if (_buttons.any((button) => button.type == buttonType)) return; final Map<ButtonType, ButtonPosition> defaultPositions = { ButtonType.leftTrigger: const ButtonPosition(x: 0.1, y: 0.05, size: 0.1, width: 0.2), ButtonType.leftBumper: const ButtonPosition(x: 0.1, y: 0.2, size: 0.12, width: 0.25), ButtonType.leftStickButton: const ButtonPosition(x: 0.2, y: 0.8, size: 0.15), ButtonType.rightTrigger: const ButtonPosition(x: 0.7, y: 0.05, size: 0.1, width: 0.2), ButtonType.rightBumper: const ButtonPosition(x: 0.65, y: 0.2, size: 0.12, width: 0.25), ButtonType.rightStickButton: const ButtonPosition(x: 0.8, y: 0.8, size: 0.15), ButtonType.select: const ButtonPosition(x: 0.4, y: 0.1, size: 0.08, width: 0.18), ButtonType.start: const ButtonPosition(x: 0.6, y: 0.1, size: 0.08, width: 0.18), }; final position = defaultPositions[buttonType] ?? const ButtonPosition(x: 0.5, y: 0.5, size: 0.2); final newButton = CustomLayoutButton( type: buttonType, label: _getButtonLabel(buttonType), color: _getButtonColor(buttonType), position: position, hasVibration: _enableVibration, isVisible: true, ); setState(() => _buttons.add(newButton)); }
  void _removeButton(ButtonType buttonType) { setState(() { _buttons.removeWhere((button) => button.type == buttonType); if (_selectedComponentType == SelectedComponentType.button && _selectedButton?.type == buttonType) { _selectedComponentType = null; _selectedButton = null; } }); }
  
  List<ButtonType> _actionTypesFor(ActionButtonStyle style) { switch (style) { case ActionButtonStyle.xbox: return [ButtonType.y, ButtonType.b, ButtonType.a, ButtonType.x]; case ActionButtonStyle.nintendo: return [ButtonType.x, ButtonType.a, ButtonType.b, ButtonType.y]; case ActionButtonStyle.playstation: return [ButtonType.triangle, ButtonType.circle, ButtonType.cross, ButtonType.square]; default: return const []; } }
  List<GamepadButton> _getActionButtonsForStyle(ActionButtonStyle style) { switch (style) { case ActionButtonStyle.xbox: return GamepadLayout.xbox.buttons; case ActionButtonStyle.nintendo: return GamepadLayout.nintendo.buttons; case ActionButtonStyle.playstation: return GamepadLayout.playstation.buttons; default: return const []; } }
  String _getButtonLabel(ButtonType buttonType) { switch (buttonType) { case ButtonType.a: return 'A'; case ButtonType.b: return 'B'; case ButtonType.x: return 'X'; case ButtonType.y: return 'Y'; case ButtonType.square: return '□'; case ButtonType.triangle: return '△'; case ButtonType.circle: return '○'; case ButtonType.cross: return '✕'; case ButtonType.dpadUp: return '↑'; case ButtonType.dpadDown: return '↓'; case ButtonType.dpadLeft: return '←'; case ButtonType.dpadRight: return '→'; case ButtonType.leftBumper: return 'L1'; case ButtonType.rightBumper: return 'R1'; case ButtonType.leftTrigger: return 'L2'; case ButtonType.rightTrigger: return 'R2'; case ButtonType.leftStickButton: return 'L3'; case ButtonType.rightStickButton: return 'R3'; case ButtonType.select: return 'SELECT'; case ButtonType.start: return 'START'; case ButtonType.leftStick: return 'LS'; case ButtonType.rightStick: return 'RS'; } }
  int _getButtonColor(ButtonType buttonType) { if (_isAction(buttonType)) { List<GamepadButton> source; switch (_actionStyle) { case ActionButtonStyle.playstation: source = GamepadLayout.playstation.buttons; break; case ActionButtonStyle.nintendo: source = GamepadLayout.nintendo.buttons; break; default: source = GamepadLayout.xbox.buttons; break; } final found = source.firstWhere((b) => b.type == buttonType, orElse: () => const GamepadButton(type: ButtonType.a, label: '', color: 0xFF616161)); return found.color; } return 0xFF616161; }
  
  Future<void> _saveLayout() async {
    if (_canvasConstraints == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aguarde a área de edição carregar.')));
      return;
    }

    if (_buttons.isEmpty && !_leftStickEnabled && !_rightStickEnabled) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Adicione pelo menos um botão ou analógico ao layout')), ); return; } 
    final layoutName = 'Meu Layout'; 
    await _storageService.deleteCustomLayout(layoutName); 
    final customLayout = CustomLayout( name: layoutName, buttons: _buttons, enableVibration: _enableVibration, enableGyroscope: _enableGyroscope, enableAccelerometer: _enableAccelerometer, createdAt: DateTime.now(), updatedAt: DateTime.now(), hasLeftStick: _leftStickEnabled, leftStickPosition: _leftStickPosition, hasRightStick: _rightStickEnabled, rightStickPosition: _rightStickPosition, ); 
    await _storageService.saveCustomLayout(customLayout); 
    if (!mounted) return; 
    ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Layout personalizado salvo com sucesso!')), ); 
    Navigator.pop(context); 
  }
}
