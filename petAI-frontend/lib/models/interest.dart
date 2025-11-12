import 'package:flutter/material.dart';

enum MotivationLevel { never, sometimes, usually, always }

extension MotivationLevelMetadata on MotivationLevel {
  String get label {
    switch (this) {
      case MotivationLevel.never:
        return "Never";
      case MotivationLevel.sometimes:
        return "Sometimes";
      case MotivationLevel.usually:
        return "Usually";
      case MotivationLevel.always:
        return "Always";
    }
  }

  String get helper {
    switch (this) {
      case MotivationLevel.never:
        return "I rarely do it";
      case MotivationLevel.sometimes:
        return "I do it on occasion";
      case MotivationLevel.usually:
        return "It's part of my week";
      case MotivationLevel.always:
        return "It's a habit already";
    }
  }
}

class GoalPreset {
  const GoalPreset({
    required this.title,
    required this.description,
    required this.suggestion,
  });

  final String title;
  final String description;
  final String suggestion;
}

class InterestBlueprint {
  const InterestBlueprint({
    required this.id,
    required this.name,
    required this.description,
    required this.suggestedActivities,
    required this.goalPresets,
    required this.accentColor,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final List<String> suggestedActivities;
  final Map<MotivationLevel, GoalPreset> goalPresets;
  final Color accentColor;
  final IconData icon;

  GoalPreset presetFor(MotivationLevel level) =>
      goalPresets[level] ?? goalPresets.values.first;
}

class SelectedInterest {
  const SelectedInterest({
    required this.blueprint,
    required this.level,
    required this.goal,
  });

  final InterestBlueprint blueprint;
  final MotivationLevel level;
  final String goal;

  SelectedInterest copyWith({
    InterestBlueprint? blueprint,
    MotivationLevel? level,
    String? goal,
  }) {
    return SelectedInterest(
      blueprint: blueprint ?? this.blueprint,
      level: level ?? this.level,
      goal: goal ?? this.goal,
    );
  }
}
