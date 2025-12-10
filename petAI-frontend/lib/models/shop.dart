import 'package:flutter/material.dart';

import '../utils/test_coins.dart';
import 'cosmetics.dart';

class ShopItem {
  ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.rarity,
    required this.tag,
    required this.description,
    required this.accent,
    this.owned = false,
    this.slot,
    this.imageKey,
    this.equipped = false,
    this.type,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Item',
      price: json['price'] as int? ?? 0,
      rarity: json['rarity'] as String? ?? 'common',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      accent: json['accent'] as String? ?? '#5667FF',
      owned: json['owned'] as bool? ?? false,
      slot: cosmeticSlotFromString(json['slot'] as String?),
      imageKey: json['image'] as String?,
      equipped: json['equipped'] as bool? ?? false,
      type: json['type'] as String?,
    );
  }

  final String id;
  final String name;
  final int price;
  final String rarity;
  final String tag;
  final String description;
  final String accent;
  final bool owned;
  final CosmeticSlot? slot;
  final String? imageKey;
  final bool equipped;
  final String? type;

  Color get accentColor => _colorFromHex(accent) ?? Colors.blueGrey.shade300;

  String get rarityLabel => rarity.toUpperCase();

  bool get isCosmetic => slot != null || (type ?? "").toLowerCase() == "cosmetic";

  String? get slotLabel => slot != null ? cosmeticSlotKey(slot!) : null;
}

class ShopState {
  ShopState({
    required this.balance,
    required this.items,
    this.equippedCosmetics = const PetCosmeticLoadout.empty(),
  });

  factory ShopState.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ShopItem.fromJson)
        .toList();
    return ShopState(
      balance: applyTestCoins(json['balance'] as int? ?? 0),
      items: rawItems,
      equippedCosmetics: PetCosmeticLoadout.fromJson(json['equipped'] as Map<String, dynamic>?),
    );
  }

  final int balance;
  final List<ShopItem> items;
  final PetCosmeticLoadout equippedCosmetics;

  bool isEquipped(ShopItem item) {
    final slot = item.slot;
    if (slot == null) return false;
    return equippedCosmetics.itemForSlot(slot) == item.id;
  }
}

Color? _colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final value = hex.replaceFirst('#', '');
  if (value.length != 6 && value.length != 8) return null;
  final buffer = StringBuffer();
  if (value.length == 6) buffer.write('ff');
  buffer.write(value);
  final intColor = int.tryParse(buffer.toString(), radix: 16);
  if (intColor == null) return null;
  return Color(intColor);
}
