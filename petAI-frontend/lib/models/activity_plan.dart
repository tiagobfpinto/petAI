class ActivityPlan {
  const ActivityPlan({
    required this.weeklyGoalValue,
    required this.weeklyGoalUnit,
    required this.days,
    this.perDayGoalValue,
  });

  final double weeklyGoalValue;
  final String weeklyGoalUnit;
  final List<String> days;
  final double? perDayGoalValue;

  factory ActivityPlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json["days"];
    final days = rawDays is List
        ? rawDays.map((e) => e?.toString() ?? "").where((e) => e.isNotEmpty).toList()
        : <String>[];
    return ActivityPlan(
      weeklyGoalValue: (json["weekly_goal_value"] as num?)?.toDouble() ?? 0,
      weeklyGoalUnit: json["weekly_goal_unit"] as String? ?? "km",
      days: days,
      perDayGoalValue: (json["per_day_goal_value"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      "weekly_goal_value": weeklyGoalValue,
      "weekly_goal_unit": weeklyGoalUnit,
      "days": days,
    };
  }

  double perDayGoal() {
    if (days.isEmpty) return 0;
    return weeklyGoalValue / days.length;
  }
}
