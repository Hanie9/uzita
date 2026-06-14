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
    this.pulse = false,
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
              color: const Color(0xFF00D4FF).withValues(alpha: 0.45 * (1 - t)),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }
}

/// Tall cyan triangle on white disc — matches Neshan navigation puck.
class _NeshanNavArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.97),
        width: w * 0.82,
        height: h * 0.14,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.82),
        width: w * 0.72,
        height: h * 0.22,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, h * 0.80),
          w * 0.36,
          [const Color(0xFFFFFFFF), const Color(0xFFE2E8F0)],
        ),
    );

    final body = ui.Path()
      ..moveTo(cx, h * 0.02)
      ..lineTo(cx + w * 0.48, h * 0.72)
      ..lineTo(cx - w * 0.48, h * 0.72)
      ..close();

    canvas.drawPath(
      body,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, h * 0.02),
          Offset(cx, h * 0.74),
          [
            const Color(0xFF7DF9FF),
            const Color(0xFF00D4FF),
            const Color(0xFF00A8E8),
            const Color(0xFF0077B6),
          ],
          [0.0, 0.25, 0.65, 1.0],
        ),
    );

    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
