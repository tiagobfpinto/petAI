import 'cosmetics.dart';

class FriendSearchResult {
  FriendSearchResult({
    required this.id,
    required this.username,
    required this.petStage,
    required this.petLevel,
    this.petCosmetics = const PetCosmeticLoadout.empty(),
  });

  final int id;
  final String username;
  final String petStage;
  final int petLevel;
  final PetCosmeticLoadout petCosmetics;

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    final cosmeticsJson = json['pet_cosmetics'];
    return FriendSearchResult(
      id: json["id"] as int? ?? 0,
      username: json["username"] as String? ?? "",
      petStage: json["pet_stage"] as String? ?? "egg",
      petLevel: json["pet_level"] as int? ?? 1,
      petCosmetics: (cosmeticsJson is Map<String, dynamic>)
          ? PetCosmeticLoadout.fromJson(cosmeticsJson)
          : const PetCosmeticLoadout.empty(),
    );
  }
}
