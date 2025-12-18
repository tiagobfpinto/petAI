import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../models/cosmetics.dart';

Color _darken(Color color, [double amount = 0.12]) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

class CosmeticArt {
  static void paint(Canvas canvas, Rect rect, String key, Color color) {
    final normalized = key.toLowerCase();
    if (normalized.contains("hat") || normalized.contains("cap")) {
      _paintHat(canvas, rect, color);
    } else if (normalized.contains("shade") || normalized.contains("glass")) {
      _paintShades(canvas, rect, color);
    } else if (normalized.contains("sneaker") || normalized.contains("shoe") || normalized.contains("feet")) {
      _paintSneakers(canvas, rect, color);
    } else if (normalized.contains("cape") || normalized.contains("cloak") || normalized.contains("back")) {
      _paintCape(canvas, rect, color);
    } else if (normalized.contains("bow") || normalized.contains("tie")) {
      _paintBowtie(canvas, rect, color);
    } else if (normalized.contains("collar") || normalized.contains("neck")) {
      _paintCollar(canvas, rect, color);
    } else {
      _paintSparkles(canvas, rect, color);
    }
  }

  static void _paintHat(Canvas canvas, Rect rect, Color color) {
    final brimRect = Rect.fromLTWH(
      rect.left - rect.width * 0.05,
      rect.top + rect.height * 0.62,
      rect.width * 1.1,
      rect.height * 0.2,
    );
    final crownRect = Rect.fromLTWH(
      rect.left + rect.width * 0.12,
      rect.top + rect.height * 0.18,
      rect.width * 0.76,
      rect.height * 0.55,
    );
    final brimPaint = Paint()..color = _darken(color, 0.08);
    final crownPaint = Paint()..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(crownRect, Radius.circular(rect.height * 0.18)), crownPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(brimRect, Radius.circular(rect.height * 0.12)), brimPaint);
    final stripe = Rect.fromLTWH(
      crownRect.left,
      crownRect.top + crownRect.height * 0.55,
      crownRect.width,
      crownRect.height * 0.16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stripe, Radius.circular(rect.height * 0.08)),
      Paint()..color = _darken(color, 0.18),
    );
  }

  static void _paintShades(Canvas canvas, Rect rect, Color color) {
    final lensWidth = rect.width * 0.38;
    final lensHeight = rect.height * 0.36;
    final frameColor = _darken(color, 0.4);
    final lensColor = color.withValues(alpha: 0.45);
    final leftLens = Rect.fromCenter(
      center: Offset(rect.left + rect.width * 0.32, rect.center.dy),
      width: lensWidth,
      height: lensHeight,
    );
    final rightLens = Rect.fromCenter(
      center: Offset(rect.right - rect.width * 0.32, rect.center.dy),
      width: lensWidth,
      height: lensHeight,
    );
    final bridge = Rect.fromLTWH(
      rect.center.dx - rect.width * 0.08,
      rect.center.dy - lensHeight * 0.2,
      rect.width * 0.16,
      lensHeight * 0.4,
    );
    final armThickness = lensHeight * 0.18;
    canvas.drawRRect(RRect.fromRectAndRadius(leftLens, Radius.circular(lensHeight * 0.35)), Paint()..color = frameColor);
    canvas.drawRRect(RRect.fromRectAndRadius(rightLens, Radius.circular(lensHeight * 0.35)), Paint()..color = frameColor);
    canvas.drawRect(bridge, Paint()..color = frameColor);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.center.dy - armThickness / 2, rect.width * 0.18, armThickness),
      Paint()..color = frameColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - rect.width * 0.18, rect.center.dy - armThickness / 2, rect.width * 0.18, armThickness),
      Paint()..color = frameColor,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(leftLens.deflate(lensHeight * 0.14), Radius.circular(lensHeight * 0.2)), Paint()..color = lensColor);
    canvas.drawRRect(RRect.fromRectAndRadius(rightLens.deflate(lensHeight * 0.14), Radius.circular(lensHeight * 0.2)), Paint()..color = lensColor);
  }

  static void _paintSneakers(Canvas canvas, Rect rect, Color color) {
    final baseHeight = rect.height * 0.42;
    final toeRadius = Radius.circular(rect.height * 0.2);
    final leftShoe = Rect.fromLTWH(
      rect.left + rect.width * 0.05,
      rect.top + rect.height * 0.45,
      rect.width * 0.42,
      baseHeight,
    );
    final rightShoe = Rect.fromLTWH(
      rect.left + rect.width * 0.53,
      rect.top + rect.height * 0.45,
      rect.width * 0.42,
      baseHeight,
    );
    final solePaint = Paint()..color = _darken(color, 0.25);
    final bodyPaint = Paint()..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(leftShoe, toeRadius), bodyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightShoe, toeRadius), bodyPaint);
    final soleHeight = baseHeight * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(leftShoe.left, leftShoe.bottom - soleHeight, leftShoe.width, soleHeight),
        Radius.circular(soleHeight * 0.4),
      ),
      solePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rightShoe.left, rightShoe.bottom - soleHeight, rightShoe.width, soleHeight),
        Radius.circular(soleHeight * 0.4),
      ),
      solePaint,
    );
  }

  static void _paintCape(Canvas canvas, Rect rect, Color color) {
    final path = Path()
      ..moveTo(rect.left + rect.width * 0.1, rect.top)
      ..quadraticBezierTo(rect.left, rect.center.dy, rect.left + rect.width * 0.15, rect.bottom)
      ..quadraticBezierTo(rect.center.dx, rect.bottom + rect.height * 0.18, rect.right - rect.width * 0.15, rect.bottom)
      ..quadraticBezierTo(rect.right + rect.width * 0.05, rect.center.dy, rect.right - rect.width * 0.12, rect.top + rect.height * 0.1)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color, _darken(color, 0.18)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  static void _paintBowtie(Canvas canvas, Rect rect, Color color) {
    final center = rect.center;
    final wingWidth = rect.width * 0.38;
    final wingHeight = rect.height * 0.5;
    final leftWing = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(center.dx - wingWidth * 0.9, center.dy - wingHeight * 0.6, center.dx - wingWidth, center.dy)
      ..quadraticBezierTo(center.dx - wingWidth * 0.9, center.dy + wingHeight * 0.6, center.dx, center.dy)
      ..close();
    final rightWing = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(center.dx + wingWidth * 0.9, center.dy - wingHeight * 0.6, center.dx + wingWidth, center.dy)
      ..quadraticBezierTo(center.dx + wingWidth * 0.9, center.dy + wingHeight * 0.6, center.dx, center.dy)
      ..close();
    final centerCircle = Rect.fromCircle(center: center, radius: rect.width * 0.14);
    final paint = Paint()..color = color;
    canvas.drawPath(leftWing, paint);
    canvas.drawPath(rightWing, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(centerCircle, Radius.circular(centerCircle.width * 0.6)),
      Paint()..color = _darken(color, 0.16),
    );
  }

  static void _paintCollar(Canvas canvas, Rect rect, Color color) {
    final bandHeight = rect.height * 0.28;
    final bandRect = Rect.fromLTWH(rect.left, rect.center.dy - bandHeight / 2, rect.width, bandHeight);
    final bandPaint = Paint()..color = color;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(bandRect.inflate(bandHeight * 0.15), Radius.circular(bandHeight)), glowPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bandRect, Radius.circular(bandHeight * 0.6)), bandPaint);
  }

  static void _paintSparkles(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()..color = color;
    final center = rect.center;
    final small = rect.width * 0.08;
    final big = rect.width * 0.14;
    canvas.drawCircle(center.translate(-rect.width * 0.18, -rect.height * 0.12), big, paint);
    canvas.drawCircle(center.translate(rect.width * 0.25, -rect.height * 0.08), small, paint);
    canvas.drawCircle(center.translate(rect.width * 0.05, rect.height * 0.2), small * 1.1, paint);
  }
}

class CosmeticPreview extends StatelessWidget {
  const CosmeticPreview({
    super.key,
    required this.artKey,
    required this.color,
    this.size = 94,
    this.riveAsset,
  });

  final String artKey;
  final Color color;
  final double size;
  final CosmeticRiveAsset? riveAsset;

  @override
  Widget build(BuildContext context) {
    final fallback = _PaintedCosmeticSticker(artKey: artKey, accent: color);
    final riveSource = riveAsset;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: riveSource != null && riveSource.isValid
          ? _RiveCosmeticPreview(
              asset: riveSource,
              fallback: fallback,
            )
          : fallback,
    );
  }
}

class _PaintedCosmeticSticker extends StatelessWidget {
  const _PaintedCosmeticSticker({required this.artKey, required this.accent});

  final String artKey;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CosmeticStickerPainter(artKey: artKey, accent: accent),
      child: const SizedBox.expand(),
    );
  }
}

class _RiveCosmeticPreview extends StatefulWidget {
  const _RiveCosmeticPreview({
    required this.asset,
    required this.fallback,
  });

  final CosmeticRiveAsset asset;
  final Widget fallback;

  @override
  State<_RiveCosmeticPreview> createState() => _RiveCosmeticPreviewState();
}

class _RiveCosmeticPreviewState extends State<_RiveCosmeticPreview> {
  late rive.FileLoader _loader;

  @override
  void initState() {
    super.initState();
    _loader = _buildLoader(widget.asset);
  }

  @override
  void didUpdateWidget(covariant _RiveCosmeticPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.asset != widget.asset.asset) {
      _loader.dispose();
      _loader = _buildLoader(widget.asset);
    }
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  rive.FileLoader _buildLoader(CosmeticRiveAsset asset) {
    return rive.FileLoader.fromAsset(asset.asset, riveFactory: rive.Factory.rive);
  }

  @override
  Widget build(BuildContext context) {
    return rive.RiveWidgetBuilder(
      fileLoader: _loader,
      artboardSelector: widget.asset.artboardSelector,
      stateMachineSelector: widget.asset.stateMachineSelector,
      builder: (context, state) => switch (state) {
        rive.RiveLoading() => Stack(
            fit: StackFit.expand,
            children: [
              widget.fallback,
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
        rive.RiveFailed() => widget.fallback,
        rive.RiveLoaded() => rive.RiveWidget(
            controller: state.controller,
            fit: widget.asset.fit,
          ),
      },
    );
  }
}

class _CosmeticStickerPainter extends CustomPainter {
  _CosmeticStickerPainter({required this.artKey, required this.accent});

  final String artKey;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paddedRect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.12,
      size.width * 0.76,
      size.height * 0.76,
    );
    CosmeticArt.paint(canvas, paddedRect, artKey, accent);
  }

  @override
  bool shouldRepaint(covariant _CosmeticStickerPainter oldDelegate) {
    return oldDelegate.artKey != artKey || oldDelegate.accent != accent;
  }
}
