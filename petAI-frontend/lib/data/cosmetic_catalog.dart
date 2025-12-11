import 'package:flutter/material.dart';

import '../models/cosmetics.dart';

class CosmeticCatalog {
  static final Map<String, CosmeticDefinition> _definitions = {
    "cozy-cap": CosmeticDefinition(
      id: "cozy-cap",
      slot: CosmeticSlot.head,
      accent: const Color(0xFFFFB74D),
      previewKey: "hat",
    ),
    "sunny-shades": CosmeticDefinition(
      id: "sunny-shades",
      slot: CosmeticSlot.face,
      accent: const Color(0xFF6DD5ED),
      previewKey: "shades",
    ),
    "trail-sneakers": CosmeticDefinition(
      id: "trail-sneakers",
      slot: CosmeticSlot.feet,
      accent: const Color(0xFF00BFA6),
      previewKey: "sneakers",
    ),
    "leafy-cape": CosmeticDefinition(
      id: "leafy-cape",
      slot: CosmeticSlot.back,
      accent: const Color(0xFF4CAF50),
      previewKey: "cape",
    ),
    "starlit-bowtie": CosmeticDefinition(
      id: "starlit-bowtie",
      slot: CosmeticSlot.neck,
      accent: const Color(0xFFCE93D8),
      previewKey: "bowtie",
    ),
    "glow-collar": CosmeticDefinition(
      id: "glow-collar",
      slot: CosmeticSlot.neck,
      accent: const Color(0xFF4AC2F7),
      previewKey: "collar",
    ),
  };

  static CosmeticDefinition? definitionFor(String? id) {
    if (id == null || id.isEmpty) return null;
    return _definitions[id];
  }

  static Color resolveAccent(String? id, {Color? fallback}) {
    final def = definitionFor(id);
    if (def != null) return def.accent;
    return fallback ?? Colors.grey.shade400;
  }
}
