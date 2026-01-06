import 'activity_completion.dart';
import 'pet_state.dart';

class ChestOpenResult {
  const ChestOpenResult({
    required this.reward,
    required this.remainingQuantity,
    required this.pet,
    required this.coinsBalance,
  });

  final ChestReward reward;
  final int remainingQuantity;
  final PetState pet;
  final int coinsBalance;

  factory ChestOpenResult.fromJson(Map<String, dynamic> json) {
    final rewardJson = json["reward"] as Map<String, dynamic>? ?? {};
    final petJson = json["pet"] as Map<String, dynamic>? ?? {};
    return ChestOpenResult(
      reward: ChestReward.fromJson(rewardJson),
      remainingQuantity: (json["remaining_quantity"] as num?)?.toInt() ?? 0,
      pet: PetState.fromJson(petJson),
      coinsBalance: (json["coins_balance"] as num?)?.toInt() ?? 0,
    );
  }
}
