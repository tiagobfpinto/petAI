import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../models/cosmetics.dart';
import 'pet_rive.dart';
import 'pet_sprite.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    required this.stage,
    required this.level,
    this.petType,
    this.currentSprite,
    this.styleTriggers = const [],
    this.cosmetics,
    this.fit = rive.Fit.cover,
    this.showCosmetics = true,
    this.fallback,
  });

  final String stage;
  final int level;
  final String? petType;
  final String? currentSprite;
  final List<String> styleTriggers;
  final PetCosmeticLoadout? cosmetics;
  final rive.Fit fit;
  final bool showCosmetics;
  final Widget? fallback;

  static List<String> _dedupePreserveOrder(Iterable<String> values) {
    final unique = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (unique.contains(trimmed)) continue;
      unique.add(trimmed);
    }
    return unique;
  }

  List<String> _buildTriggers() {
    final resolvedStage = stage.trim().isEmpty ? "egg" : stage.trim();
    final resolvedType = (petType ?? "").trim();
    final resolvedSprite = (currentSprite ?? "").trim();
    return _dedupePreserveOrder([
      resolvedStage,
      if (resolvedType.isNotEmpty) resolvedType,
      if (resolvedSprite.isNotEmpty) resolvedSprite,
      ...styleTriggers,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final triggers = _buildTriggers();
    final loadout = cosmetics;
    final hasCosmetics = loadout != null && !loadout.isEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        PetRive(
          triggers: triggers,
          fit: fit,
          fallback: fallback,
        ),
        if (showCosmetics && hasCosmetics)
          PetSprite(
            stage: stage.trim().isEmpty ? "egg" : stage.trim(),
            mood: max(1, level),
            cosmetics: loadout,
            paintBody: false,
          ),
      ],
    );
  }
}
