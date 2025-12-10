import 'activity_plan.dart';

class ActivityType {
  const ActivityType({
    required this.id,
    required this.interestId,
    required this.name,
    this.description,
    this.level,
    this.goal,
    this.plan,
    this.area,
    this.rrule,
  });

  final int id;
  final int interestId;
  final String name;
  final String? description;
  final String? level;
  final String? goal;
  final ActivityPlan? plan;
  final String? area;
  final String? rrule;

  String get areaName => (area ?? "").trim();

  factory ActivityType.fromJson(Map<String, dynamic> json) {
    final planJson = json["plan"];
    final rawArea = json["area"] ?? json["interest"];
    return ActivityType(
      id: json["id"] as int? ?? 0,
      interestId: json["interest_id"] as int? ?? 0,
      name: (json["name"] as String? ?? "").trim(),
      description: (json["description"] as String?)?.trim(),
      level: (json["level"] as String?)?.trim(),
      goal: (json["goal"] as String?)?.trim(),
      plan: planJson is Map<String, dynamic> ? ActivityPlan.fromJson(planJson) : null,
      area: rawArea is String ? rawArea.trim() : null,
      rrule: (json["rrule"] as String?)?.trim(),
    );
  }
}
