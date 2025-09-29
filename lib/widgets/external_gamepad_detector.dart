import 'package:flutter/material.dart';
import 'package:gamepadvirtual/models/connection_state.dart' as model;

class ExternalGamepadDetector extends StatefulWidget {
  final model.ConnectionState connectionState;
  final Widget child;

  const ExternalGamepadDetector({
    super.key,
    required this.connectionState,
    required this.child,
  });

  @override
  State<ExternalGamepadDetector> createState() =>
      _ExternalGamepadDetectorState();
}

class _ExternalGamepadDetectorState extends State<ExternalGamepadDetector> {
  @override
  Widget build(BuildContext context) {
    // Apenas retorna o filho, sem adicionar overlays
    return widget.child;
  }
}