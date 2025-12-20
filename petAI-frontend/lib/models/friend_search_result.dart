import 'cosmetics.dart';

class FriendSearchResult {
  FriendSearchResult({
    required this.id,
    required this.username,
    required this.petStage,
    required this.petLevel,
    this.petCosmetics = const PetCosmeticLoadout.empty(),
    this.petType = 'sprout',
    this.petCurrentSprite,
    this.petStyleTriggers = const [],
  });

  final int id;
  final String username;
  final String petStage;
  final int petLevel;
  final PetCosmeticLoadout petCosmetics;
  final String petType;
  final String? petCurrentSprite;
  final List<String> petStyleTriggers;

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    final cosmeticsJson = json['pet_cosmetics'];
    final styleRaw = json['pet_style_triggers'];
    final styleTriggers = (styleRaw is List)
        ? styleRaw
            .where((entry) => entry != null)
            .map((entry) => entry.toString().trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : const <String>[];
    return FriendSearchResult(
      id: json["id"] as int? ?? 0,
      username: json["username"] as String? ?? "",
      petStage: json["pet_stage"] as String? ?? "egg",
      petLevel: json["pet_level"] as int? ?? 1,
      petCosmetics: (cosmeticsJson is Map<String, dynamic>)
          ? PetCosmeticLoadout.fromJson(cosmeticsJson)
          : const PetCosmeticLoadout.empty(),
      petType: json["pet_type"] as String? ?? "sprout",
      petCurrentSprite: json["pet_current_sprite"] as String?,
      petStyleTriggers: styleTriggers,
    );
  }
}
