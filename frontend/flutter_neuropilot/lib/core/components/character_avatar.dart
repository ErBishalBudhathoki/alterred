import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum CharacterStyle {
  tech,
  street,
  space,
  mythic,
}

class CharacterAvatar extends StatelessWidget {
  final CharacterStyle style;
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;

  const CharacterAvatar({
    super.key,
    required this.style,
    this.size = 120,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final pColor = primaryColor ?? DesignTokens.primary;
    final sColor = secondaryColor ?? DesignTokens.surface;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: sColor,
        border: Border.all(color: pColor, width: 2),
      ),
      child: ClipOval(
        child: CustomPaint(
          painter: _CharacterPainter(style, pColor),
          size: Size(size, size),
        ),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  final CharacterStyle style;
  final Color color;

  _CharacterPainter(this.style, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Base Head
    // canvas.drawCircle(center, w * 0.35, strokePaint);

    switch (style) {
      case CharacterStyle.tech:
        _drawTech(canvas, size, paint, strokePaint);
        break;
      case CharacterStyle.street:
        _drawStreet(canvas, size, paint, strokePaint);
        break;
      case CharacterStyle.space:
        _drawSpace(canvas, size, paint, strokePaint);
        break;
      case CharacterStyle.mythic:
        _drawMythic(canvas, size, paint, strokePaint);
        break;
    }
  }

  void _drawTech(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Spiky Hair
    final path = Path();
    path.moveTo(w * 0.2, h * 0.4);
    path.lineTo(w * 0.3, h * 0.2);
    path.lineTo(w * 0.4, h * 0.35);
    path.lineTo(w * 0.5, h * 0.15); // Top spike
    path.lineTo(w * 0.6, h * 0.35);
    path.lineTo(w * 0.7, h * 0.2);
    path.lineTo(w * 0.8, h * 0.4);
    canvas.drawPath(path, stroke);

    // Visor Glasses
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.45), width: w * 0.5, height: h * 0.1),
      const Radius.circular(4),
    );
    canvas.drawRRect(visorRect, fill);

    // Hoodie
    final hoodiePath = Path();
    hoodiePath.moveTo(w * 0.2, h * 0.6);
    hoodiePath.quadraticBezierTo(w * 0.5, h * 0.8, w * 0.8, h * 0.6);
    hoodiePath.lineTo(w * 0.9, h * 1.0);
    hoodiePath.lineTo(w * 0.1, h * 1.0);
    hoodiePath.close();
    canvas.drawPath(hoodiePath, stroke);

    // Binary pattern (simplified dots)
    canvas.drawCircle(Offset(w * 0.3, h * 0.8), 2, fill);
    canvas.drawCircle(Offset(w * 0.4, h * 0.85), 2, fill);
    canvas.drawCircle(Offset(w * 0.5, h * 0.8), 2, fill);
  }

  void _drawStreet(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Dreadlocks
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
          Offset(w * (0.2 + i * 0.15), h * 0.3 + (i % 2) * 10), 8, stroke);
    }

    // Face
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5), width: w * 0.5, height: h * 0.5),
      0,
      3.14,
      false,
      stroke,
    );

    // Ice Cream Cone (small icon)
    final conePath = Path();
    conePath.moveTo(w * 0.65, h * 0.65);
    conePath.lineTo(w * 0.7, h * 0.8);
    conePath.lineTo(w * 0.6, h * 0.8);
    conePath.close();
    canvas.drawPath(conePath, stroke);
    canvas.drawCircle(Offset(w * 0.65, h * 0.65), 5, fill);
  }

  void _drawSpace(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Helmet
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.35, stroke);

    // Visor (Silhouette effect - dark fill)
    final visorPath = Path();
    visorPath.addOval(Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.45), width: w * 0.5, height: h * 0.4));
    canvas.drawPath(visorPath, fill);

    // Reflection
    final reflectionPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.6, h * 0.35),
            width: w * 0.1,
            height: h * 0.05),
        reflectionPaint);

    // Suit
    final suitPath = Path();
    suitPath.moveTo(w * 0.2, h * 0.7);
    suitPath.quadraticBezierTo(w * 0.5, h * 0.6, w * 0.8, h * 0.7);
    suitPath.lineTo(w * 0.8, h * 1.0);
    suitPath.lineTo(w * 0.2, h * 1.0);
    suitPath.close();
    canvas.drawPath(suitPath, stroke);
  }

  void _drawMythic(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Curly Hair
    for (int i = 0; i < 8; i++) {
      canvas.drawCircle(
          Offset(w * 0.5 + (i - 3.5) * 15, h * 0.25 + (i % 2 == 0 ? 5 : -5)),
          10,
          stroke);
    }

    // Face
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.5), width: w * 0.5, height: h * 0.6),
        stroke);

    // Beaded Necklace
    for (int i = 0; i < 7; i++) {
      canvas.drawCircle(
          Offset(w * 0.35 + i * 8, h * 0.75 + (i - 3).abs() * 2), 3, fill);
    }

    // Draped Garment
    final drapePath = Path();
    drapePath.moveTo(w * 0.2, h * 0.8);
    drapePath.quadraticBezierTo(w * 0.5, h * 0.9, w * 0.8, h * 0.8);
    drapePath.lineTo(w * 0.9, h * 1.0);
    drapePath.lineTo(w * 0.1, h * 1.0);
    drapePath.close();
    canvas.drawPath(drapePath, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
