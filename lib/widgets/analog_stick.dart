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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _isDragging = true;
              });
            },
            onPanUpdate: (details) {
              final center = Offset(widget.size / 2, widget.size / 2);
              final delta = details.localPosition - center;
              final distance = math.min(delta.distance, widget.size / 2 - 15);
              final angle = math.atan2(delta.dy, delta.dx);
              
              final newX = distance * math.cos(angle);
              final newY = distance * math.sin(angle);
              
              setState(() {
                _x = newX / (widget.size / 2 - 15);
                _y = newY / (widget.size / 2 - 15);
              });
              
              widget.onChanged(_x, _y);
            },
            onPanEnd: (details) {
              setState(() {
                _x = 0;
                _y = 0;
                _isDragging = false;
              });
              widget.onChanged(0, 0);
            },
            child: CustomPaint(
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

    // Draw stick shadow
    final shadowOffset = Offset(stickOffset.dx + 2, stickOffset.dy + 2);
    paint.color = Colors.black.withValues(alpha: 0.3);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(shadowOffset, innerRadius, paint);

    // Draw stick
    paint.color = isDragging ? Colors.blue.shade400 : Colors.grey.shade300;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(stickOffset, innerRadius, paint);

    // Draw stick border
    paint.color = isDragging ? Colors.blue.shade600 : Colors.grey.shade500;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(stickOffset, innerRadius - 1, paint);

    // Draw center dot
    paint.color = Colors.grey.shade700;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(stickOffset, 3, paint);
  }

  @override
  bool shouldRepaint(AnalogStickPainter oldDelegate) {
    return oldDelegate.x != x || 
           oldDelegate.y != y || 
           oldDelegate.isDragging != isDragging;
  }
}