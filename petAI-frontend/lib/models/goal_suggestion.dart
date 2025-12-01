class GoalSuggestion {
  const GoalSuggestion({
    required this.suggestedActivity,
    this.activity,
    this.amount,
    this.unit,
    this.source,
    this.model,
    this.prompt,
    this.age,
    this.gender,
    this.activityLevel,
    this.lastActivities = const [],
    this.fallbackText,
  });

  final String suggestedActivity;
  final String? activity;
  final double? amount;
  final String? unit;
  final String? source;
  final String? model;
  final String? prompt;
  final int? age;
  final String? gender;
  final String? activityLevel;
  final List<String> lastActivities;
  final String? fallbackText;

  factory GoalSuggestion.fromJson(Map<String, dynamic> json) {
    final inputs = json["inputs"] as Map<String, dynamic>? ?? {};
    final last =
        inputs["last_activities"] as List<dynamic>? ??
        json["last_activities"] as List<dynamic>? ??
        <dynamic>[];
    final fallback = json["fallback"] as Map<String, dynamic>? ?? {};
    final activityName =
        json["activity"] as String? ??
        json["activity_name"] as String? ??
        inputs["activity"] as String?;
    final amountRaw = json["amount"] ?? json["weekly_goal_value"];
    double? parsedAmount;
    if (amountRaw is num) {
      parsedAmount = amountRaw.toDouble();
    } else if (amountRaw is String) {
      parsedAmount = double.tryParse(amountRaw);
    }
    final unitValue =
        json["unit"] as String? ??
        json["weekly_goal_unit"] as String? ??
        inputs["last_goal_unit"] as String?;
    return GoalSuggestion(
      suggestedActivity:
          json["suggested_activity"] as String? ??
          json["suggested_text"] as String? ??
          fallback["suggested_text"] as String? ??
          activityName ??
          "",
      activity: activityName,
      amount: parsedAmount,
      unit: unitValue,
      source: json["source"] as String?,
      model: json["model"] as String?,
      prompt: json["prompt"] as String?,
      age: (inputs["age"] as num?)?.toInt() ?? (json["age"] as num?)?.toInt(),
      gender: inputs["gender"] as String? ?? json["gender"] as String?,
      activityLevel:
          inputs["activity_level"] as String? ??
          json["activity_level"] as String?,
      lastActivities: last.map((e) => e.toString()).toList(),
      fallbackText: fallback["suggested_text"] as String?,
    );
  }
}
