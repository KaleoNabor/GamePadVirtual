import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnalogStick extends StatefulWidget {
  final double size;
  final Function(double x, double y) onChanged;
  final String label;
  final bool isLeft;

  const AnalogStick({
    super.key,
    this.size = 120,
    required this.onChanged,
    required this.label,
    required this.isLeft,
  });

  @override
  State<AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<AnalogStick> {
  double _x = 0;
  double _y = 0;
  bool _isDragging = false;
  
  // Otimização: evitar chamadas desnecessárias
  DateTime _lastUpdate = DateTime.now();
  static const Duration _minUpdateInterval = Duration(milliseconds: 8); // ~120 FPS

  void _updateStick(double newX, double newY, bool isDragging) {
    final now = DateTime.now();
    
    // Limita a taxa de atualização para melhor performance
    if (now.difference(_lastUpdate) < _minUpdateInterval && isDragging) {
      return;
    }

    if (_x != newX || _y != newY || _isDragging != isDragging) {
      setState(() {
        _x = newX;
        _y = newY;
        _isDragging = isDragging;
      });
      
      widget.onChanged(_x, _y);
      _lastUpdate = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              _updateStick(0, 0, true);
              _handlePanUpdate(details.localPosition);
            },
            onPanUpdate: (details) {
              _handlePanUpdate(details.localPosition);
            },
            onPanEnd: (details) {
              _updateStick(0, 0, false);
            },
            onPanCancel: () {
              _updateStick(0, 0, false);
            },
            child: CustomPaint(
              willChange: true, // Otimização para animações
              isComplex: true,  // Otimização para pintura
              painter: AnalogStickPainter(
                x: _x,
                y: _y,
                isDragging: _isDragging,
                size: widget.size,
              ),
              size: Size(widget.size, widget.size),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _handlePanUpdate(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final distance = math.min(delta.distance, widget.size / 2 - 15);
    
    // Evita cálculos desnecessários quando o stick está no centro
    if (distance < 0.1) {
      _updateStick(0, 0, true);
      return;
    }
    
    final angle = math.atan2(delta.dy, delta.dx);
    
    final newX = distance * math.cos(angle);
    final newY = distance * math.sin(angle);
    
    final normalizedX = newX / (widget.size / 2 - 15);
    final normalizedY = newY / (widget.size / 2 - 15);
    
    _updateStick(normalizedX, normalizedY, true);
  }
}

class AnalogStickPainter extends CustomPainter {
  final double x;
  final double y;
  final bool isDragging;
  final double size;

  AnalogStickPainter({
    required this.x,
    required this.y,
    required this.isDragging,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = 15.0;

    // Draw outer circle (base)
    paint.color = Colors.grey.shade800;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, paint);

    // Draw outer border
    paint.color = Colors.grey.shade600;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(center, outerRadius - 1, paint);

    // Calculate stick position
    final maxDistance = outerRadius - innerRadius;
    final stickOffset = Offset(
      center.dx + (x * maxDistance),
      center.dy + (y * maxDistance),
    );

    // Draw stick shadow (apenas se estiver sendo arrastado para performance)
    if (isDragging) {
      final shadowOffset = Offset(stickOffset.dx + 2, stickOffset.dy + 2);
      paint.color = Colors.black.withOpacity(0.3);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(shadowOffset, innerRadius, paint);
    }

    // Draw stick
    paint.color = isDragging ? Colors.blue.shade400 : Colors.grey.shade300;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(stickOffset, innerRadius, paint);

    // Draw stick border
    paint.color = isDragging ? Colors.blue.shade600 : Colors.grey.shade500;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(stickOffset, innerRadius - 1, paint);

    // Draw center dot (apenas se estiver sendo arrastado para performance)
    if (isDragging) {
      paint.color = Colors.grey.shade700;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(stickOffset, 3, paint);
    }
  }

  @override
  bool shouldRepaint(AnalogStickPainter oldDelegate) {
    return oldDelegate.x != x || 
           oldDelegate.y != y || 
           oldDelegate.isDragging != isDragging;
  }
}