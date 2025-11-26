import 'interest.dart';
import '../data/interest_catalog.dart';

class UserInterest {
  const UserInterest({
    required this.id,
    required this.name,
    required this.level,
    this.goal,
  });

  final int? id;
  final String name;
  final MotivationLevel level;
  final String? goal;

  InterestBlueprint get blueprint => resolveInterestBlueprint(name);

  factory UserInterest.fromJson(Map<String, dynamic> json) {
    return UserInterest(
      id: json["id"] as int?,
      name: json["name"] as String? ?? "",
      level: motivationLevelFromKey(json["level"] as String?),
      goal: json["goal"] as String?,
    );
  }

  Map<String, dynamic> toPayload() {
    final payload = {
      "name": name,
      "level": level.key,
    };
    final trimmedGoal = goal?.trim();
    if (trimmedGoal != null && trimmedGoal.isNotEmpty) {
      payload["goal"] = trimmedGoal;
    }
    return payload;
  }

  UserInterest copyWith({
    int? id,
    String? name,
    MotivationLevel? level,
    String? goal,
  }) {
    return UserInterest(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      goal: goal ?? this.goal,
    );
  }

  String levelLabel() => level.label;
}
