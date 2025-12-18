import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../data/cosmetic_catalog.dart';
import '../models/cosmetics.dart';
import 'cosmetic_art.dart';

class PetSprite extends StatelessWidget {
  const PetSprite({
    super.key,
    required this.stage,
    required this.mood,
    this.cosmetics,
    this.paintBody = true,
  });

  final String stage;
  final int mood;
  final PetCosmeticLoadout? cosmetics;
  final bool paintBody;

  @override
  Widget build(BuildContext context) {
    final loadout = cosmetics;
    final hasCosmetics = loadout != null && !loadout.isEmpty;
    final riveCosmetics = <CosmeticSlot, CosmeticDefinition>{};
    if (hasCosmetics) {
      loadout!.equipped.forEach((slot, itemId) {
        final def = CosmeticCatalog.definitionFor(itemId);
        if (def?.riveAsset != null && def!.riveAsset!.isValid) {
          riveCosmetics[slot] = def;
        }
      });
    }
    final ignoreSlots = riveCosmetics.keys.toSet();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth == double.infinity ? 0 : constraints.maxWidth,
          constraints.maxHeight == double.infinity ? 0 : constraints.maxHeight,
        );
        final bodyRect = _petBodyRect(size);
        final backgroundRive = riveCosmetics.entries
            .where((entry) => entry.key == CosmeticSlot.back)
            .toList();
        final foregroundRive = riveCosmetics.entries
            .where((entry) => entry.key != CosmeticSlot.back)
            .toList();
        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasCosmetics)
              Positioned.fill(
                child: CustomPaint(
                  painter: _PetCosmeticPainter(
                    cosmetics: loadout!,
                    layer: _CosmeticLayer.background,
                    ignoreSlots: ignoreSlots,
                  ),
                ),
              ),
            ...backgroundRive.map(
              (entry) => _RiveCosmeticLayer(
                definition: entry.value,
                slot: entry.key,
                rect: _slotRectForBody(bodyRect, entry.key),
              ),
            ),
            Positioned.fill(
              child: paintBody
                  ? CustomPaint(
                      painter: _PetPainter(stage: stage, mood: mood),
                    )
                  : const SizedBox.shrink(),
            ),
            ...foregroundRive.map(
              (entry) => _RiveCosmeticLayer(
                definition: entry.value,
                slot: entry.key,
                rect: _slotRectForBody(bodyRect, entry.key),
              ),
            ),
            if (hasCosmetics)
              Positioned.fill(
                child: CustomPaint(
                  painter: _PetCosmeticPainter(
                    cosmetics: loadout!,
                    layer: _CosmeticLayer.foreground,
                    ignoreSlots: ignoreSlots,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _CosmeticLayer { background, foreground }

class _PetCosmeticPainter extends CustomPainter {
  const _PetCosmeticPainter({
    required this.cosmetics,
    required this.layer,
    this.ignoreSlots = const {},
  });

  final PetCosmeticLoadout cosmetics;
  final _CosmeticLayer layer;
  final Set<CosmeticSlot> ignoreSlots;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = _petBodyRect(size);

    cosmetics.equipped.forEach((slot, itemId) {
      final isBackground = slot == CosmeticSlot.back;
      if (ignoreSlots.contains(slot)) return;
      if (layer == _CosmeticLayer.background && !isBackground) return;
      if (layer == _CosmeticLayer.foreground && isBackground) return;

      final def = CosmeticCatalog.definitionFor(itemId);
      final artKey = (def?.previewKey ?? cosmeticSlotKey(slot));
      final color = def?.accent ?? Colors.blueGrey.shade400;
      final rect = _slotRectForBody(bodyRect, slot);
      CosmeticArt.paint(canvas, rect, artKey, color);
    });
  }

  @override
  bool shouldRepaint(covariant _PetCosmeticPainter oldDelegate) {
    return oldDelegate.cosmetics != cosmetics ||
        oldDelegate.layer != layer ||
        oldDelegate.ignoreSlots != ignoreSlots;
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

class _RiveCosmeticLayer extends StatefulWidget {
  const _RiveCosmeticLayer({
    required this.definition,
    required this.slot,
    required this.rect,
  });

  final CosmeticDefinition definition;
  final CosmeticSlot slot;
  final Rect rect;

  @override
  State<_RiveCosmeticLayer> createState() => _RiveCosmeticLayerState();
}

class _RiveCosmeticLayerState extends State<_RiveCosmeticLayer> {
  rive.FileLoader? _loader;

  CosmeticRiveAsset? get _asset => widget.definition.riveAsset;

  @override
  void initState() {
    super.initState();
    _setupLoader();
  }

  @override
  void didUpdateWidget(covariant _RiveCosmeticLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition.riveAsset?.asset != _asset?.asset) {
      _loader?.dispose();
      _setupLoader();
    }
  }

  @override
  void dispose() {
    _loader?.dispose();
    super.dispose();
  }

  void _setupLoader() {
    final source = _asset;
    if (source == null || !source.isValid) {
      _loader = null;
      return;
    }
    _loader = rive.FileLoader.fromAsset(source.asset, riveFactory: rive.Factory.rive);
  }

  @override
  Widget build(BuildContext context) {
    final source = _asset;
    final loader = _loader;
    final fallback = CustomPaint(
      painter: _CosmeticStickerPainter(
        artKey: widget.definition.previewKey ?? cosmeticSlotKey(widget.slot),
        accent: widget.definition.accent,
      ),
      child: const SizedBox.expand(),
    );
    if (source == null || loader == null || !source.isValid) {
      return Positioned.fromRect(rect: widget.rect, child: fallback);
    }
    return Positioned(
      left: widget.rect.left,
      top: widget.rect.top,
      width: widget.rect.width,
      height: widget.rect.height,
      child: rive.RiveWidgetBuilder(
        fileLoader: loader,
        artboardSelector: source.artboardSelector,
        stateMachineSelector: source.stateMachineSelector,
        builder: (context, state) => switch (state) {
          rive.RiveLoaded() => rive.RiveWidget(
              controller: state.controller,
              fit: source.fit,
            ),
          rive.RiveLoading() => Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
          rive.RiveFailed() => fallback,
        },
      ),
    );
  }
}

Rect _petBodyRect(Size size) {
  final width = size.width == 0 ? 160.0 : size.width;
  final height = size.height == 0 ? 160.0 : size.height;
  final center = Offset(width / 2, height / 2);
  final baseRadius = width * 0.32;
  return Rect.fromCenter(
    center: center,
    width: baseRadius * 2,
    height: baseRadius * 2.1,
  );
}

Rect _slotRectForBody(Rect bodyRect, CosmeticSlot slot) {
  switch (slot) {
    case CosmeticSlot.head:
      return Rect.fromCenter(
        center: Offset(bodyRect.center.dx, bodyRect.top - bodyRect.height * 0.18),
        width: bodyRect.width * 0.9,
        height: bodyRect.height * 0.35,
      );
    case CosmeticSlot.face:
      return Rect.fromCenter(
        center: Offset(bodyRect.center.dx, bodyRect.center.dy - bodyRect.height * 0.1),
        width: bodyRect.width * 0.82,
        height: bodyRect.height * 0.26,
      );
    case CosmeticSlot.neck:
      return Rect.fromCenter(
        center: Offset(bodyRect.center.dx, bodyRect.bottom - bodyRect.height * 0.22),
        width: bodyRect.width * 0.88,
        height: bodyRect.height * 0.24,
      );
    case CosmeticSlot.feet:
      return Rect.fromCenter(
        center: Offset(bodyRect.center.dx, bodyRect.bottom + bodyRect.height * 0.02),
        width: bodyRect.width * 0.96,
        height: bodyRect.height * 0.32,
      );
    case CosmeticSlot.back:
      return Rect.fromCenter(
        center: Offset(bodyRect.center.dx, bodyRect.center.dy + bodyRect.height * 0.05),
        width: bodyRect.width * 1.16,
        height: bodyRect.height * 1.04,
      );
  }
}

extension on Color {
  Color darken([double amount = 0.2]) {
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
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
