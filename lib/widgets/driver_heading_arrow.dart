import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Neshan-style 3D navigation puck (points upward when map rotates with bearing).
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
      size: Size(size * 0.72, size),
      painter: _NeshanNavArrowPainter(),
    );

    if (pulse) {
      arrow = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
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
      duration: const Duration(milliseconds: 2000),
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
          width: widget.size * (0.55 + t * 0.45),
          height: widget.size * (0.22 + t * 0.12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.45 * (1 - t)),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }
}

/// 3D wedge arrow similar to Neshan turn-by-turn navigation puck.
class _NeshanNavArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Ground shadow (ellipse under puck)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.94),
        width: w * 0.72,
        height: h * 0.14,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // Main arrow body — wide base, sharp tip (3D navigation chevron)
    final body = ui.Path()
      ..moveTo(cx, h * 0.04)
      ..lineTo(cx + w * 0.46, h * 0.72)
      ..lineTo(cx + w * 0.14, h * 0.66)
      ..lineTo(cx + w * 0.14, h * 0.88)
      ..lineTo(cx - w * 0.14, h * 0.88)
      ..lineTo(cx - w * 0.14, h * 0.66)
      ..lineTo(cx - w * 0.46, h * 0.72)
      ..close();

    final gradient = ui.Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, h * 0.04),
        Offset(cx, h * 0.9),
        [
          const Color(0xFF7DD3FC),
          const Color(0xFF38BDF8),
          const Color(0xFF0284C7),
        ],
        [0.0, 0.45, 1.0],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(body, gradient);

    // White highlight stripe (3D effect)
    final highlight = ui.Path()
      ..moveTo(cx, h * 0.10)
      ..lineTo(cx + w * 0.06, h * 0.58)
      ..lineTo(cx - w * 0.02, h * 0.55)
      ..close();
    canvas.drawPath(
      highlight,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );

    // White outline
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    // Dark edge for depth
    canvas.drawPath(
      ui.Path()
        ..moveTo(cx - w * 0.46, h * 0.72)
        ..lineTo(cx - w * 0.14, h * 0.66)
        ..lineTo(cx - w * 0.14, h * 0.88),
      Paint()
        ..color = const Color(0xFF0369A1).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
