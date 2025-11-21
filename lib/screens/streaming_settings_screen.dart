import 'package:flutter/material.dart';
import 'package:gamepadvirtual/services/storage_service.dart';

class StreamingSettingsScreen extends StatefulWidget {
  const StreamingSettingsScreen({super.key});

  @override
  State<StreamingSettingsScreen> createState() => _StreamingSettingsScreenState();
}

class _StreamingSettingsScreenState extends State<StreamingSettingsScreen> {
  final StorageService _storage = StorageService();
  
  bool _isTransparent = true;
  bool _isImmersive = true;
  bool _isTouchpadEnabled = false;
  double _sensitivity = 2.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final transparent = await _storage.isButtonStyleTransparent();
    final immersive = await _storage.isViewModeImmersive();
    final touchpad = await _storage.isTouchpadEnabled();
    final sens = await _storage.getMouseSensitivity();

    if (mounted) {
      setState(() {
        _isTransparent = transparent;
        _isImmersive = immersive;
        _isTouchpadEnabled = touchpad;
        _sensitivity = sens;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurações de Transmissão"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader("Visual"),
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Botões Transparentes"),
                      subtitle: const Text("Exibe apenas o contorno dos botões."),
                      value: _isTransparent,
                      onChanged: (val) {
                        setState(() => _isTransparent = val);
                        _storage.setButtonStyleTransparent(val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Modo Imersivo"),
                      subtitle: const Text("Vídeo em tela cheia com botões por cima."),
                      value: _isImmersive,
                      onChanged: (val) {
                        setState(() => _isImmersive = val);
                        _storage.setViewModeImmersive(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildSectionHeader("Controle Mouse (Touch)"),
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Ativar Touchpad"),
                      subtitle: const Text("Use a área do vídeo como mouse do PC."),
                      value: _isTouchpadEnabled,
                      onChanged: (val) {
                        setState(() => _isTouchpadEnabled = val);
                        _storage.setTouchpadEnabled(val);
                      },
                    ),
                    if (_isTouchpadEnabled) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Sensibilidade do Mouse",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Ajuste a velocidade do cursor: ${_sensitivity.toStringAsFixed(1)}",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Slider(
                              value: _sensitivity,
                              min: 0.5,
                              max: 5.0,
                              divisions: 9,
                              label: _sensitivity.toStringAsFixed(1),
                              onChanged: (val) {
                                setState(() => _sensitivity = val);
                                _storage.setMouseSensitivity(val);
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text("Lenta", style: TextStyle(fontSize: 12)),
                                Text("Rápida", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Nova seção de informações
              const SizedBox(height: 16),
              _buildSectionHeader("Informações"),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoItem(
                        Icons.touch_app,
                        "Touchpad",
                        "Arraste na tela do vídeo para mover o mouse do PC. Toque rápido para cliques.",
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        Icons.visibility,
                        "Modo Imersivo",
                        "Otimizado para jogos em tela cheia. Botões ficam sobrepostos ao vídeo.",
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        Icons.style,
                        "Botões Transparentes",
                        "Reduz a obstrução visual durante o gameplay.",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}