import 'pet_state.dart';

class ProgressionRedeemResult {
  const ProgressionRedeemResult({
    required this.pet,
    required this.rewardXp,
    required this.rewardCoins,
    required this.pendingRewards,
  });

  final PetState pet;
  final int rewardXp;
  final int rewardCoins;
  final int pendingRewards;

  factory ProgressionRedeemResult.fromJson(Map<String, dynamic> json) {
    return ProgressionRedeemResult(
      pet: PetState.fromJson(json["pet"] as Map<String, dynamic>? ?? const {}),
      rewardXp: (json["reward_xp"] as num?)?.toInt() ?? 0,
      rewardCoins: (json["reward_coins"] as num?)?.toInt() ?? 0,
      pendingRewards: (json["pending_rewards"] as num?)?.toInt() ?? 0,
    );
  }
}
