import 'pet_state.dart';

class ActivityCompletionResult {
  const ActivityCompletionResult({
    required this.pet,
    required this.xpAwarded,
    required this.evolved,
    this.interestId,
  });

  final PetState pet;
  final int xpAwarded;
  final bool evolved;
  final int? interestId;

  factory ActivityCompletionResult.fromJson(Map<String, dynamic> json) {
    final petJson = json["pet"] as Map<String, dynamic>? ?? {};
    return ActivityCompletionResult(
      pet: PetState.fromJson(petJson),
      xpAwarded: json["xp_awarded"] as int? ?? 0,
      evolved: json["evolved"] as bool? ?? false,
      interestId: json["interest_id"] as int?,
    );
  }
}
