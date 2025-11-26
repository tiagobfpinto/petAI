import 'package:flutter/material.dart';

class PetSprite extends StatelessWidget {
  const PetSprite({
    super.key,
    required this.stage,
    required this.mood,
  });

  final String stage;
  final int mood;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PetPainter(stage: stage, mood: mood),
    );
  }
}

class _PetPainter extends CustomPainter {
  const _PetPainter({
    required this.stage,
    required this.mood,
  });

  final String stage;
  final int mood;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width == 0 ? 160.0 : size.width;
    final height = size.height == 0 ? 160.0 : size.height;
    final center = Offset(width / 2, height / 2);
    final baseRadius = width * 0.32;

    final bodyPaint = Paint()..color = _bodyColor(stage);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + baseRadius + 12),
        width: width * 0.6,
        height: height * 0.18,
      ),
      shadowPaint,
    );

    final bodyRect = Rect.fromCenter(
      center: center,
      width: baseRadius * 2,
      height: baseRadius * 2.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(baseRadius)),
      bodyPaint,
    );

    _drawFace(canvas, center, baseRadius);
    _drawAccents(canvas, bodyRect);
  }

  void _drawFace(Canvas canvas, Offset center, double radius) {
    final eyeOffsetY = radius * 0.25;
    final eyeOffsetX = radius * 0.45;
    final eyePaint = Paint()..color = Colors.black.withValues(alpha: 0.75);
    final eyeRadius = radius * 0.12;

    canvas.drawCircle(
      Offset(center.dx - eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      eyePaint,
    );

    final smile = Path();
    smile.moveTo(center.dx - radius * 0.35, center.dy + radius * 0.05);
    smile.quadraticBezierTo(
      center.dx,
      center.dy + radius * (mood >= 3 ? 0.3 : 0.15),
      center.dx + radius * 0.35,
      center.dy + radius * 0.05,
    );
    final smilePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(smile, smilePaint);
  }

  void _drawAccents(Canvas canvas, Rect bodyRect) {
    final accentPaint = Paint()..color = _accentColor(stage);
    if (stage == "egg") {
      return;
    }

    if (stage == "sprout" || stage == "bud") {
      final leafPathLeft = Path()
        ..moveTo(bodyRect.left + 30, bodyRect.top - 4)
        ..quadraticBezierTo(
          bodyRect.left,
          bodyRect.top - 40,
          bodyRect.left + 24,
          bodyRect.top - 60,
        )
        ..quadraticBezierTo(
          bodyRect.left + 60,
          bodyRect.top - 32,
          bodyRect.left + 30,
          bodyRect.top - 4,
        );
      final leafPathRight = Path()
        ..moveTo(bodyRect.right - 30, bodyRect.top - 4)
        ..quadraticBezierTo(
          bodyRect.right,
          bodyRect.top - 42,
          bodyRect.right - 24,
          bodyRect.top - 64,
        )
        ..quadraticBezierTo(
          bodyRect.right - 60,
          bodyRect.top - 34,
          bodyRect.right - 30,
          bodyRect.top - 4,
        );
      canvas.drawPath(leafPathLeft, accentPaint);
      canvas.drawPath(leafPathRight, accentPaint);
    } else {
      final stemPaint = Paint()
        ..color = accentPaint.color.darken()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      final topCenter = Offset(bodyRect.center.dx, bodyRect.top - 10);
      canvas.drawLine(
        topCenter + const Offset(0, 4),
        topCenter - Offset(0, bodyRect.height * 0.3),
        stemPaint,
      );
      canvas.drawCircle(
        topCenter - Offset(0, bodyRect.height * 0.35),
        12,
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PetPainter oldDelegate) {
    return oldDelegate.stage != stage || oldDelegate.mood != mood;
  }

  Color _bodyColor(String stage) {
    switch (stage) {
      case "egg":
        return const Color(0xFFE1F5FE);
      case "sprout":
        return const Color(0xFFC8E6C9);
      case "bud":
        return const Color(0xFFB2DFDB);
      case "plant":
        return const Color(0xFFA5D6A7);
      case "tree":
        return const Color(0xFF8BC34A);
      default:
        return const Color(0xFFE1F5FE);
    }
  }

  Color _accentColor(String stage) {
    switch (stage) {
      case "sprout":
        return const Color(0xFF81C784);
      case "bud":
        return const Color(0xFF4DB6AC);
      case "plant":
        return const Color(0xFF66BB6A);
      case "tree":
        return const Color(0xFF43A047);
      default:
        return const Color(0xFFB0BEC5);
    }
  }
}

extension on Color {
  Color darken([double amount = 0.2]) {
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
