import 'package:flutter/material.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/screens/custom_layout_editor_screen.dart';

class LayoutSelectionScreen extends StatefulWidget {
  const LayoutSelectionScreen({super.key});

  @override
  State<LayoutSelectionScreen> createState() => _LayoutSelectionScreenState();
}

class _LayoutSelectionScreenState extends State<LayoutSelectionScreen> {
  final StorageService _storageService = StorageService();
  GamepadLayoutType _selectedLayout = GamepadLayoutType.xbox;
  bool _hasCustomLayout = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedLayout();
    _checkCustomLayout();
  }

  Future<void> _loadSelectedLayout() async {
    final layout = await _storageService.getSelectedLayout();
    setState(() {
      _selectedLayout = layout;
    });
  }

  Future<void> _checkCustomLayout() async {
    final customLayouts = await _storageService.getCustomLayouts();
    setState(() {
      _hasCustomLayout = customLayouts.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layout do Controle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escolha o estilo do seu gamepad',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Xbox Layout
                    _buildLayoutOption(
                      layout: GamepadLayout.xbox,
                      layoutType: GamepadLayoutType.xbox,
                      description: 'Layout clássico do Xbox com botões coloridos A, B, X, Y',
                    ),
                    const SizedBox(height: 16),
                    
                    // PlayStation Layout
                    _buildLayoutOption(
                      layout: GamepadLayout.playstation,
                      layoutType: GamepadLayoutType.playstation,
                      description: 'Layout do PlayStation com símbolos △, ○, □, ✕',
                    ),
                    const SizedBox(height: 16),
                    
                    // Nintendo Layout
                    _buildLayoutOption(
                      layout: GamepadLayout.nintendo,
                      layoutType: GamepadLayoutType.nintendo,
                      description: 'Layout do Nintendo com botões A, B, X, Y preto e branco',
                    ),
                    const SizedBox(height: 16),
                    
                    // Custom Layout
                    _buildCustomLayoutOption(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Save Button
            ElevatedButton(
              onPressed: _saveLayout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Salvar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOption({
    required GamepadLayout layout,
    required GamepadLayoutType layoutType,
    required String description,
  }) {
    final isSelected = _selectedLayout == layoutType;

    return Card(
      elevation: isSelected ? 8 : 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLayout = layoutType;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<GamepadLayoutType>(
                    value: layoutType,
                    groupValue: _selectedLayout,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedLayout = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layout.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Button Preview
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: layout.buttons.map((button) => Container(
                  width: 40,
                  height: 40,
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomLayoutOption() {
    final isSelected = _selectedLayout == GamepadLayoutType.custom;

    return Card(
      elevation: isSelected ? 8 : 2,
      child: InkWell(
        onTap: _hasCustomLayout
            ? () {
                setState(() {
                  _selectedLayout = GamepadLayoutType.custom;
                });
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<GamepadLayoutType>(
                    value: GamepadLayoutType.custom,
                    groupValue: _selectedLayout,
                    onChanged: _hasCustomLayout
                        ? (value) {
                            if (value != null) {
                              setState(() {
                                _selectedLayout = value;
                              });
                            }
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalizado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _hasCustomLayout ? null : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasCustomLayout
                              ? 'Seu layout personalizado'
                              : 'Crie seu próprio layout primeiro',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _hasCustomLayout ? null : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _goToCustomEditor,
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar layout personalizado',
                  ),
                ],
              ),
              if (!_hasCustomLayout) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, 
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Disponível após criar um layout',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getTextColor(Color backgroundColor) {
    // Calculate luminance to determine if text should be white or black
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Future<void> _saveLayout() async {
    await _storageService.setSelectedLayout(_selectedLayout);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout salvo com sucesso!')),
    );
    
    Navigator.pop(context);
  }

  void _goToCustomEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomLayoutEditorScreen(),
      ),
    ).then((_) => _checkCustomLayout());
  }
}