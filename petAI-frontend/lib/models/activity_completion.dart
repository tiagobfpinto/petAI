import 'pet_state.dart';

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
  });

  final PetState pet;
  final int xpAwarded;
  final bool evolved;
  final int? interestId;
  final int? streakCurrent;
  final int? streakBest;
  final double? xpMultiplier;
  final int? coinsAwarded;

  factory ActivityCompletionResult.fromJson(Map<String, dynamic> json) {
    final petJson = json["pet"] as Map<String, dynamic>? ?? {};
    return ActivityCompletionResult(
      pet: PetState.fromJson(petJson),
      xpAwarded: json["xp_awarded"] as int? ?? 0,
      evolved: json["evolved"] as bool? ?? false,
      interestId: json["interest_id"] as int?,
      streakCurrent: json["streak_current"] as int?,
      streakBest: json["streak_best"] as int?,
      xpMultiplier: (json["xp_multiplier"] as num?)?.toDouble(),
      coinsAwarded: json["coins_awarded"] as int?,
    );
  }
}
