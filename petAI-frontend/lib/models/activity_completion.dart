import 'pet_state.dart';

class ChestItem {
  const ChestItem({
    required this.id,
    required this.name,
    this.type,
    this.rarity,
    this.assetPath,
    this.trigger,
  });

  final int id;
  final String name;
  final String? type;
  final String? rarity;
  final String? assetPath;
  final String? trigger;

  factory ChestItem.fromJson(Map<String, dynamic> json) {
    return ChestItem(
      id: (json["id"] as num?)?.toInt() ?? 0,
      name: json["name"] as String? ?? "Item",
      type: json["type"] as String?,
      rarity: json["rarity"] as String?,
      assetPath: json["asset_path"] as String?,
      trigger: json["trigger"] as String?,
    );
  }
}

class ChestReward {
  const ChestReward({
    required this.type,
    this.xp,
    this.coins,
    this.item,
  });

  final String type;
  final int? xp;
  final int? coins;
  final ChestItem? item;

  factory ChestReward.fromJson(Map<String, dynamic> json) {
    final itemJson = json["item"];
    return ChestReward(
      type: json["type"] as String? ?? "",
      xp: (json["xp"] as num?)?.toInt(),
      coins: (json["coins"] as num?)?.toInt(),
      item: itemJson is Map<String, dynamic> ? ChestItem.fromJson(itemJson) : null,
    );
  }
}

class ActivityCompletionResult {
  const ActivityCompletionResult({
    required this.pet,
    required this.xpAwarded,
    required this.evolved,
    this.interestId,
    this.streakCurrent,
    this.streakBest,
    this.xpMultiplier,
    this.coinsAwarded,
    this.chest,
    this.nextChestIn,
  });

  final PetState pet;
  final int xpAwarded;
  final bool evolved;
  final int? interestId;
  final int? streakCurrent;
  final int? streakBest;
  final double? xpMultiplier;
  final int? coinsAwarded;
  final ChestReward? chest;
  final int? nextChestIn;

  factory ActivityCompletionResult.fromJson(Map<String, dynamic> json) {
    final petJson = json["pet"] as Map<String, dynamic>? ?? {};
    final chestJson = json["chest"];
    return ActivityCompletionResult(
      pet: PetState.fromJson(petJson),
      xpAwarded: json["xp_awarded"] as int? ?? 0,
      evolved: json["evolved"] as bool? ?? false,
      interestId: json["interest_id"] as int?,
      streakCurrent: json["streak_current"] as int?,
      streakBest: json["streak_best"] as int?,
      xpMultiplier: (json["xp_multiplier"] as num?)?.toDouble(),
      coinsAwarded: json["coins_awarded"] as int?,
      chest: chestJson is Map<String, dynamic> ? ChestReward.fromJson(chestJson) : null,
      nextChestIn: (json["next_chest_in"] as num?)?.toInt(),
    );
  }
}
