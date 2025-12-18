import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

enum CosmeticSlot { head, face, neck, feet, back }

class CosmeticRiveAsset {
  const CosmeticRiveAsset({
    required this.asset,
    this.artboard,
    this.stateMachine,
    this.fit = rive.Fit.contain,
  });

  static CosmeticRiveAsset? fromMap(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final rawAsset = json['asset'] ?? json['path'];
    final asset = rawAsset is String ? rawAsset : rawAsset?.toString() ?? '';
    if (asset.isEmpty) return null;
    final rawStateMachine = json['stateMachine'] ?? json['state_machine'];
    return CosmeticRiveAsset(
      asset: asset,
      artboard: json['artboard'] as String?,
      stateMachine: rawStateMachine is String
          ? rawStateMachine
          : rawStateMachine?.toString(),
      fit: _fitFromString(json['fit']?.toString()) ?? rive.Fit.contain,
    );
  }

  final String asset;
  final String? artboard;
  final String? stateMachine;
  final rive.Fit fit;

  bool get isValid => asset.isNotEmpty;

  rive.ArtboardSelector get artboardSelector =>
      (artboard != null && artboard!.isNotEmpty)
          ? rive.ArtboardSelector.byName(artboard!)
          : const rive.ArtboardDefault();

  rive.StateMachineSelector get stateMachineSelector =>
      (stateMachine != null && stateMachine!.isNotEmpty)
          ? rive.StateMachineSelector.byName(stateMachine!)
          : const rive.StateMachineDefault();
}

CosmeticSlot? cosmeticSlotFromString(String? value) {
  if (value == null || value.isEmpty) return null;
  switch (value.toLowerCase()) {
    case "head":
      return CosmeticSlot.head;
    case "face":
      return CosmeticSlot.face;
    case "neck":
      return CosmeticSlot.neck;
    case "feet":
    case "shoes":
      return CosmeticSlot.feet;
    case "back":
    case "cape":
      return CosmeticSlot.back;
    default:
      return null;
  }
}

String cosmeticSlotKey(CosmeticSlot slot) {
  switch (slot) {
    case CosmeticSlot.head:
      return "head";
    case CosmeticSlot.face:
      return "face";
    case CosmeticSlot.neck:
      return "neck";
    case CosmeticSlot.feet:
      return "feet";
    case CosmeticSlot.back:
      return "back";
  }
}

class PetCosmeticLoadout {
  const PetCosmeticLoadout.empty() : equipped = const {};

  PetCosmeticLoadout({Map<CosmeticSlot, String>? equipped})
      : equipped = Map.unmodifiable(equipped ?? const {});

  factory PetCosmeticLoadout.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const PetCosmeticLoadout.empty();
    final source = (json["equipped"] is Map<String, dynamic>)
        ? json["equipped"] as Map<String, dynamic>
        : json;
    final mapped = <CosmeticSlot, String>{};
    source.forEach((key, value) {
      final slot = cosmeticSlotFromString(key);
      if (slot != null && value is String && value.isNotEmpty) {
        mapped[slot] = value;
      }
    });
    return PetCosmeticLoadout(equipped: mapped);
  }

  final Map<CosmeticSlot, String> equipped;

  bool get isEmpty => equipped.isEmpty;

  String? itemForSlot(CosmeticSlot slot) => equipped[slot];

  PetCosmeticLoadout copyWithSlot(CosmeticSlot slot, String? itemId) {
    final updated = Map<CosmeticSlot, String>.from(equipped);
    if (itemId == null || itemId.isEmpty) {
      updated.remove(slot);
    } else {
      updated[slot] = itemId;
    }
    return PetCosmeticLoadout(equipped: updated);
  }

  Map<String, String> toJson() {
    return {
      for (final entry in equipped.entries) cosmeticSlotKey(entry.key): entry.value,
    };
  }
}

class CosmeticDefinition {
  const CosmeticDefinition({
    required this.id,
    required this.slot,
    required this.accent,
    this.previewKey,
    this.riveAsset,
    this.rivePreview,
  });

  final String id;
  final CosmeticSlot slot;
  final Color accent;
  final String? previewKey;
  final CosmeticRiveAsset? riveAsset;
  final CosmeticRiveAsset? rivePreview;
}

rive.Fit? _fitFromString(String? value) {
  if (value == null || value.isEmpty) return null;
  switch (value.toLowerCase()) {
    case "fill":
      return rive.Fit.fill;
    case "contain":
      return rive.Fit.contain;
    case "cover":
      return rive.Fit.cover;
    case "fitwidth":
    case "fit_width":
      return rive.Fit.fitWidth;
    case "fitheight":
    case "fit_height":
      return rive.Fit.fitHeight;
    case "none":
      return rive.Fit.none;
    case "scale_down":
    case "scaledown":
      return rive.Fit.scaleDown;
    default:
      return null;
  }
}
