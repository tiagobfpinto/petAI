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

  String get key {
    switch (this) {
      case MotivationLevel.never:
        return "never";
      case MotivationLevel.sometimes:
        return "sometimes";
      case MotivationLevel.usually:
        return "usually";
      case MotivationLevel.always:
        return "always";
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

MotivationLevel motivationLevelFromKey(String? value) {
  final normalized = (value ?? "").toLowerCase().trim();
  switch (normalized) {
    case "never":
      return MotivationLevel.never;
    case "usually":
      return MotivationLevel.usually;
    case "always":
      return MotivationLevel.always;
    case "sometimes":
    default:
      return MotivationLevel.sometimes;
  }
}
