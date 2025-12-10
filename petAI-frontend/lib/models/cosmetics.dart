import 'package:flutter/material.dart';

enum CosmeticSlot { head, face, neck, feet, back }

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
  });

  final String id;
  final CosmeticSlot slot;
  final Color accent;
  final String? previewKey;
}
