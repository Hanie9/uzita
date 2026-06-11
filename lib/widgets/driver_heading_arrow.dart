import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Navigation-style arrow showing direction of travel (points upward at 0°).
class DriverHeadingArrow extends StatelessWidget {
  final double? headingDegrees;
  final double size;
  final bool pulse;

  const DriverHeadingArrow({
    super.key,
    required this.headingDegrees,
    this.size = 48,
    this.pulse = true,
  });

  @override
  Widget build(BuildContext context) {
    final rotation = (headingDegrees ?? 0) * math.pi / 180;

    Widget arrow = CustomPaint(
      size: Size.square(size),
      painter: _HeadingArrowPainter(),
    );

    if (pulse && headingDegrees != null) {
      arrow = Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(size: size),
          arrow,
        ],
      );
    }

    return AnimatedRotation(
      turns: rotation / (2 * math.pi),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: arrow,
    );
  }
}

class _PulseRing extends StatefulWidget {
  final double size;

  const _PulseRing({required this.size});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          width: widget.size * (0.9 + t * 0.35),
          height: widget.size * (0.9 + t * 0.35),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35 * (1 - t)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class _HeadingArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final w = size.width;
    final h = size.height;

    // Soft shadow under arrow
    canvas.drawCircle(
      center.translate(0, 2),
      w * 0.22,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // White backing circle
    canvas.drawCircle(
      center,
      w * 0.28,
      Paint()..color = Colors.white,
    );

    final path = ui.Path()
      ..moveTo(center.dx, h * 0.14)
      ..lineTo(center.dx + w * 0.22, h * 0.62)
      ..lineTo(center.dx + w * 0.08, h * 0.58)
      ..lineTo(center.dx + w * 0.08, h * 0.86)
      ..lineTo(center.dx - w * 0.08, h * 0.86)
      ..lineTo(center.dx - w * 0.08, h * 0.58)
      ..lineTo(center.dx - w * 0.22, h * 0.62)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
