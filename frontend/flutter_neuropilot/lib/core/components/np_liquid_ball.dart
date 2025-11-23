import 'package:flutter/material.dart';
import 'dart:math' as math;

enum NpLiquidMode { idle, listening, processing, speaking }

class NpLiquidBall extends StatefulWidget {
  final double size;
  final NpLiquidMode mode;
  final double amplitude;
  final double frequency;
  const NpLiquidBall(
      {super.key,
      this.size = 48,
      required this.mode,
      this.amplitude = 0.0,
      this.frequency = 2.0});

  @override
  State<NpLiquidBall> createState() => _NpLiquidBallState();
}

class _NpLiquidBallState extends State<NpLiquidBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (widget.mode) {
      NpLiquidMode.listening => cs.primary,
      NpLiquidMode.processing => cs.tertiary,
      NpLiquidMode.speaking => cs.secondary,
      _ => cs.surfaceVariant,
    };
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) {
          final t = _ctl.value * 2 * math.pi;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _LiquidPainter(
                color: color,
                t: t,
                amp: widget.amplitude,
                freq: widget.frequency),
          );
        },
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final Color color;
  final double t;
  final double amp;
  final double freq;
  _LiquidPainter(
      {required this.color,
      required this.t,
      required this.amp,
      required this.freq});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final path = Path();
    final steps = 64;
    for (int i = 0; i <= steps; i++) {
      final a = (i / steps) * 2 * math.pi;
      final wobble = (1 +
              amp *
                  0.6 *
                  (math.sin(a * freq + t) + math.sin(a * (freq * 0.5) - t))) *
          r;
      final x = c.dx + wobble * math.cos(a);
      final y = c.dy + wobble * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.amp != amp ||
        oldDelegate.freq != freq ||
        oldDelegate.color != color;
  }
}
