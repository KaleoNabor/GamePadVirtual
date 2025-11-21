import 'package:flutter/material.dart';

class GamepadSettingsDrawer extends StatefulWidget {
  // Configurações existentes
  final bool hapticFeedbackEnabled;
  final bool rumbleEnabled;
  final bool gyroscopeEnabled;
  final bool accelerometerEnabled;
  final bool isExternalMode;
  final bool externalDigitalTriggersEnabled;

  // --- NOVOS PARÂMETROS QUE FALTAVAM ---
  final bool isTransparentMode;
  final bool isTouchpadEnabled;
  final double mouseSensitivity;
  final bool isImmersiveMode;
  
  // --- NOVO CAMPO ---
  final bool isStreamingEnabled; // Estado atual do stream no servidor

  // --- NOVO CAMPO DE ÁUDIO ---
  final bool isAudioEnabled;

  // Callbacks existentes
  final Function(bool) onHapticChanged;
  final Function(bool) onRumbleChanged;
  final Function(bool) onGyroChanged;
  final Function(bool) onAccelChanged;
  final Function(bool) onExternalTriggerChanged;
  final VoidCallback onDisconnect;

  // --- NOVOS CALLBACKS QUE FALTAVAM ---
  final Function(bool) onTransparentChanged;
  final Function(bool) onTouchpadChanged;
  final Function(double) onMouseSensitivityChanged;
  final Function(bool) onImmersiveModeChanged;
  
  // --- NOVO CALLBACK ---
  final Function(bool) onStreamingChanged; // Ação ao mudar o switch

  // --- NOVO CALLBACK DE ÁUDIO ---
  final Function(bool) onAudioChanged;

  const GamepadSettingsDrawer({
    super.key,
    required this.hapticFeedbackEnabled,
    required this.rumbleEnabled,
    required this.gyroscopeEnabled,
    required this.accelerometerEnabled,
    required this.isExternalMode,
    required this.externalDigitalTriggersEnabled,
    // Novos campos no construtor
    required this.isTransparentMode,
    required this.isTouchpadEnabled,
    required this.mouseSensitivity,
    required this.isImmersiveMode,
    // Novo campo de streaming
    required this.isStreamingEnabled,
    // Novo campo de áudio
    required this.isAudioEnabled,
    
    required this.onHapticChanged,
    required this.onRumbleChanged,
    required this.onGyroChanged,
    required this.onAccelChanged,
    required this.onExternalTriggerChanged,
    required this.onDisconnect,
    // Novos callbacks no construtor
    required this.onTransparentChanged,
    required this.onTouchpadChanged,
    required this.onMouseSensitivityChanged,
    required this.onImmersiveModeChanged,
    // Novo callback de streaming
    required this.onStreamingChanged,
    // Novo callback de áudio
    required this.onAudioChanged,
  });

  @override
  State<GamepadSettingsDrawer> createState() => _GamepadSettingsDrawerState();
}

class _GamepadSettingsDrawerState extends State<GamepadSettingsDrawer> {
  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isExternalMode 
        ? const Color(0xFF1E1E1E) 
        : Theme.of(context).colorScheme.surface;
    
    final textColor = widget.isExternalMode 
        ? Colors.white 
        : Theme.of(context).colorScheme.onSurface;

    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              // CORREÇÃO: withOpacity -> withValues
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings, size: 48, color: Colors.white),
                  const SizedBox(height: 10),
                  const Text(
                    "Configurações",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  if (widget.isExternalMode)
                    const Text("(Modo Externo)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader("Transmissão & Visual", textColor),

                // --- SWITCH DE CONTROLE MESTRE ---
                SwitchListTile(
                  title: Text("Habilitar Transmissão (PC)", style: TextStyle(color: textColor)),
                  subtitle: Text(
                    widget.isStreamingEnabled ? "O PC está pronto para transmitir" : "Transmissão desligada no PC",
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)
                  ),
                  value: widget.isStreamingEnabled,
                  activeThumbColor: Colors.green, // Verde para indicar "Ligado"
                  onChanged: widget.onStreamingChanged,
                ),

                // --- NOVO SWITCH DE ÁUDIO ---
                SwitchListTile(
                  title: Text("Áudio da Transmissão", style: TextStyle(color: textColor)),
                  subtitle: Text(
                    widget.isAudioEnabled ? "Som ativado" : "Som mutado (Conexão mantida)",
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)
                  ),
                  secondary: Icon(
                    widget.isAudioEnabled ? Icons.volume_up : Icons.volume_off, 
                    color: textColor
                  ),
                  value: widget.isAudioEnabled,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: widget.onAudioChanged,
                ),
                // ----------------------------

                const Divider(),

                // Configuração de Transparência
                if (!widget.isExternalMode)
                  SwitchListTile(
                    title: Text("Botões Transparentes", style: TextStyle(color: textColor)),
                    value: widget.isTransparentMode,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: widget.onTransparentChanged,
                  ),
                
                // Configuração de Modo Imersivo (Tela cheia vs Split)
                SwitchListTile(
                  title: Text("Modo Imersivo", style: TextStyle(color: textColor)),
                  subtitle: Text("Vídeo em tela cheia", style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
                  value: widget.isImmersiveMode,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: widget.onImmersiveModeChanged,
                ),

                _buildSectionHeader("Mouse & Touch", textColor),
                
                // Configuração do Touchpad
                SwitchListTile(
                  title: Text("Usar Touch como Mouse", style: TextStyle(color: textColor)),
                  value: widget.isTouchpadEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: widget.onTouchpadChanged,
                ),
                
                if (widget.isTouchpadEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      "Sensibilidade: ${widget.mouseSensitivity.toStringAsFixed(1)}", 
                      style: TextStyle(color: textColor)
                    ),
                  ),
                  Slider(
                    value: widget.mouseSensitivity,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: widget.onMouseSensitivityChanged,
                  ),
                ],

                _buildSectionHeader("Geral", textColor),
                
                SwitchListTile(
                  title: Text("Vibração do Jogo (Rumble)", style: TextStyle(color: textColor)),
                  subtitle: Text("Receber feedback do PC", style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
                  value: widget.rumbleEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: widget.onRumbleChanged,
                ),

                _buildSectionHeader("Sensores", textColor),
                
                SwitchListTile(
                  title: Text("Giroscópio", style: TextStyle(color: textColor)),
                  value: widget.gyroscopeEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: widget.onGyroChanged,
                ),
                SwitchListTile(
                  title: Text("Acelerômetro", style: TextStyle(color: textColor)),
                  value: widget.accelerometerEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: widget.onAccelChanged,
                ),

                if (!widget.isExternalMode) ...[
                  _buildSectionHeader("Virtual", textColor),
                  SwitchListTile(
                    title: Text("Resposta Tátil", style: TextStyle(color: textColor)),
                    subtitle: Text("Vibrar ao tocar na tela", style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
                    value: widget.hapticFeedbackEnabled,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: widget.onHapticChanged,
                  ),
                ],

                if (widget.isExternalMode) ...[
                   _buildSectionHeader("Controle Físico", textColor),
                   SwitchListTile(
                    title: Text("Gatilhos Digitais", style: TextStyle(color: textColor)),
                    subtitle: Text("L2/R2 viram botões simples", style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
                    value: widget.externalDigitalTriggersEnabled,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: widget.onExternalTriggerChanged,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                 Navigator.pop(context); 
                 widget.onDisconnect(); 
              },
              icon: const Icon(Icons.exit_to_app),
              label: const Text("Desconectar"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          // CORREÇÃO: withOpacity -> withValues
          color: color.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}