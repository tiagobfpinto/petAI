import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../models/cosmetics.dart';
import '../models/rive_input_value.dart';
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
  final List<RiveInputValue> styleTriggers;
  final PetCosmeticLoadout? cosmetics;
  final rive.Fit fit;
  final bool showCosmetics;
  final Widget? fallback;

  static List<RiveInputValue> _dedupePreserveOrder(Iterable<RiveInputValue> values) {
    final unique = <RiveInputValue>[];
    final signatures = <String>{};
    for (final value in values) {
      final signature = value.signature;
      if (signature.isEmpty) continue;
      if (signatures.contains(signature)) continue;
      signatures.add(signature);
      unique.add(value);
    }
    return unique;
  }

  List<RiveInputValue> _buildTriggers() {
    final resolvedStage = stage.trim().isEmpty ? "egg" : stage.trim();
    final resolvedType = (petType ?? "").trim();
    final resolvedSprite = (currentSprite ?? "").trim();
    return _dedupePreserveOrder([
      RiveInputValue.trigger(resolvedStage),
      if (resolvedType.isNotEmpty) RiveInputValue.trigger(resolvedType),
      if (resolvedSprite.isNotEmpty) RiveInputValue.trigger(resolvedSprite),
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
