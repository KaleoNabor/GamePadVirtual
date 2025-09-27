import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // MODIFICADO
import 'package:gamepadvirtual/models/connection_state.dart' as model;

 // Dando um apelido

class ExternalGamepadDetector extends StatefulWidget {
  final model.ConnectionState connectionState;
  final Widget child;
  final bool enableBackgroundMode;

  const ExternalGamepadDetector({
    super.key,
    required this.connectionState,
    required this.child,
    this.enableBackgroundMode = true,
  });

  @override
  State<ExternalGamepadDetector> createState() =>
      _ExternalGamepadDetectorState();
}

class _ExternalGamepadDetectorState extends State<ExternalGamepadDetector>
    with WidgetsBindingObserver {
  // MODIFICADO: O estado agora é gerenciado pelo pacote wakelock_plus
  // bool _isScreenLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateScreenState();
  }

  @override
  void didUpdateWidget(ExternalGamepadDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionState != widget.connectionState) {
      _updateScreenState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlockScreen();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.connectionState.isExternalGamepad) {
      switch (state) {
        case AppLifecycleState.paused:
          // App em segundo plano - manter conexões ativas
          _lockScreen(); // Mantém a tela acordada mesmo em pausa
          break;
        case AppLifecycleState.resumed:
          // App em primeiro plano - restaurar estado normal
          _updateScreenState();
          break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          break;
      }
    }
  }

  void _updateScreenState() {
    if (widget.connectionState.isExternalGamepad &&
        widget.enableBackgroundMode) {
      _lockScreen();
    } else {
      _unlockScreen();
    }
  }

  Future<void> _lockScreen() async {
    try {
      // Manter tela ativa
      await WakelockPlus.enable();
      print('Tela mantida ativa para modo gamepad externo');
    } catch (e) {
      print('Erro ao ativar wakelock: $e');
    }
  }

  Future<void> _unlockScreen() async {
    try {
      // Permitir que tela desligue
      await WakelockPlus.disable();
      print('Wakelock desativado');
    } catch (e) {
      print('Erro ao desativar wakelock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Impedir voltar quando gamepad externo está conectado
        if (widget.connectionState.isExternalGamepad) {
          // Mostrar diálogo de confirmação
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Gamepad Externo Conectado'),
              content: const Text(
                'Deseja realmente desconectar o gamepad externo e sair?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Sair'),
                ),
              ],
            ),
          );

          return shouldExit ?? false;
        }
        return true;
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (widget.connectionState.isExternalGamepad) {
      return Stack(
        children: [
          widget.child,
          // Overlay para indicar modo externo
          if (widget.enableBackgroundMode)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sports_esports, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'EXTERNO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return widget.child;
  }
}

// MODIFICADO: Classe auxiliar de Wakelock removida pois estamos usando o pacote real.