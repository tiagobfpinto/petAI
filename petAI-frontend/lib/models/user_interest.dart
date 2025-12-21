import 'interest.dart';
import '../data/interest_catalog.dart';
import 'activity_plan.dart';

class UserInterest {
  const UserInterest({
    required this.id,
    required this.name,
    required this.level,
    this.isSystem = false,
    this.goal,
    this.plan,
  });

  final int? id;
  final String name;
  final MotivationLevel level;
  final bool isSystem;
  final String? goal;
  final ActivityPlan? plan;

  InterestBlueprint get blueprint => resolveInterestBlueprint(name);

  factory UserInterest.fromJson(Map<String, dynamic> json) {
    return UserInterest(
      id: json["id"] as int?,
      name: json["name"] as String? ?? "",
      level: motivationLevelFromKey(json["level"] as String?),
      isSystem: json["is_system"] as bool? ?? false,
      goal: json["goal"] as String?,
      plan: json["plan"] is Map<String, dynamic>
          ? ActivityPlan.fromJson(json["plan"] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toPayload() {
    final Map<String, dynamic> payload = {
      "name": name,
      "level": level.key,
    };
    final trimmedGoal = goal?.trim();
    if (trimmedGoal != null && trimmedGoal.isNotEmpty) {
      payload["goal"] = trimmedGoal;
    }
    if (plan != null) {
      payload["plan"] = plan!.toPayload();
    }
    return payload;
  }

  UserInterest copyWith({
    int? id,
    String? name,
    MotivationLevel? level,
    bool? isSystem,
    String? goal,
    ActivityPlan? plan,
  }) {
    return UserInterest(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      isSystem: isSystem ?? this.isSystem,
      goal: goal ?? this.goal,
      plan: plan ?? this.plan,
    );
  }

  String levelLabel() => level.label;
}
