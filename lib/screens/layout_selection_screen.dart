import 'package:flutter/material.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/storage_service.dart';
import 'package:gamepadvirtual/screens/layout_customization_screen.dart';

class LayoutSelectionScreen extends StatefulWidget {
  const LayoutSelectionScreen({super.key});

  @override
  State<LayoutSelectionScreen> createState() => _LayoutSelectionScreenState();
}

class _LayoutSelectionScreenState extends State<LayoutSelectionScreen> {
  final StorageService _storageService = StorageService();
  GamepadLayoutType _selectedLayout = GamepadLayoutType.xbox;

  @override
  void initState() {
    super.initState();
    _loadSelectedLayout();
  }

  Future<void> _loadSelectedLayout() async {
    final layout = await _storageService.getSelectedLayout();
    setState(() {
      _selectedLayout = layout;
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
                    _buildLayoutOption(
                      layout: GamepadLayout.xbox,
                      layoutType: GamepadLayoutType.xbox,
                      description: 'Layout clássico do Xbox com botões coloridos A, B, X, Y',
                    ),
                    const SizedBox(height: 16),
                    
                    _buildLayoutOption(
                      layout: GamepadLayout.playstation,
                      layoutType: GamepadLayoutType.playstation,
                      description: 'Layout do PlayStation com símbolos △, ○, □, ✕',
                    ),
                    const SizedBox(height: 16),
                    
                    _buildLayoutOption(
                      layout: GamepadLayout.nintendo,
                      layoutType: GamepadLayoutType.nintendo,
                      description: 'Layout do Nintendo com botões A, B, X, Y preto e branco',
                    ),
                    
                    const SizedBox(height: 16),
                    _buildLayoutOption(
                      layout: null,
                      layoutType: GamepadLayoutType.custom,
                      description: 'Abra o editor para arrastar e posicionar os botões.',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
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
    required GamepadLayout? layout, 
    required GamepadLayoutType layoutType,
    required String description,
  }) {
    final isSelected = _selectedLayout == layoutType;
    final String title = layout?.name ?? 'Personalizado';

    return Card(
      elevation: isSelected ? 8 : 2,
      child: InkWell(
        onTap: () {
          if (layoutType == GamepadLayoutType.custom) {
            _handleCustomLayoutSelection();
          } else {
            setState(() {
              _selectedLayout = layoutType;
            });
          }
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
                  // ignore: deprecated_member_use
                  Radio<GamepadLayoutType>(
                    value: layoutType,
                    groupValue: _selectedLayout,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      if (value != null) {
                        if (value == GamepadLayoutType.custom) {
                          _handleCustomLayoutSelection();
                        } else {
                          setState(() {
                            _selectedLayout = value;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
              if (layout != null)
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

  Future<void> _handleCustomLayoutSelection() async {
    final GamepadLayoutType? baseType = await showDialog<GamepadLayoutType>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Escolha um Layout Base"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Xbox (A, B, X, Y)"),
              onTap: () => Navigator.pop(ctx, GamepadLayoutType.xbox),
            ),
            ListTile(
              title: const Text("PlayStation (△, ○, □, ✕)"),
              onTap: () => Navigator.pop(ctx, GamepadLayoutType.playstation),
            ),
            ListTile(
              title: const Text("Nintendo (B, A, Y, X)"),
              onTap: () => Navigator.pop(ctx, GamepadLayoutType.nintendo),
            ),
          ],
        ),
      ),
    );

    // CORREÇÃO: Verificação de mounted após async gap
    if (baseType == null || !mounted) return;

    await _storageService.setCustomLayoutBase(baseType);

    // CORREÇÃO: Verificação de mounted após async gap
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LayoutCustomizationScreen()),
    );

    setState(() {
      _selectedLayout = GamepadLayoutType.custom;
    });
  }

  Color _getTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Future<void> _saveLayout() async {
    await _storageService.setSelectedLayout(_selectedLayout);
    
    // CORREÇÃO: Verificação de mounted após async gap
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout salvo com sucesso!')),
    );
    
    Navigator.pop(context);
  }
}