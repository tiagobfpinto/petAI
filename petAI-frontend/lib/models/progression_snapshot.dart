class ProgressionSummary {
  ProgressionSummary({
    required this.level,
    required this.stage,
    required this.xp,
    required this.nextEvolutionXp,
    required this.streakCurrent,
    required this.streakBest,
    required this.interests,
    required this.activities,
  });

  factory ProgressionSummary.fromJson(Map<String, dynamic> json) {
    return ProgressionSummary(
      level: json['level'] as int? ?? 1,
      stage: json['stage'] as String? ?? 'egg',
      xp: json['xp'] as int? ?? 0,
      nextEvolutionXp: json['next_evolution_xp'] as int? ?? 1,
      streakCurrent: json['streak_current'] as int? ?? 0,
      streakBest: json['streak_best'] as int? ?? 0,
      interests: json['interests'] as int? ?? 0,
      activities: json['activities'] as int? ?? 0,
    );
  }

  final int level;
  final String stage;
  final int xp;
  final int nextEvolutionXp;
  final int streakCurrent;
  final int streakBest;
  final int interests;
  final int activities;

  double get xpProgress =>
      nextEvolutionXp <= 0 ? 0 : (xp / nextEvolutionXp).clamp(0, 1).toDouble();
}

class ProgressionToday {
  ProgressionToday({required this.completed, required this.xp});

  factory ProgressionToday.fromJson(Map<String, dynamic> json) {
    return ProgressionToday(
      completed: json['completed'] as int? ?? 0,
      xp: json['xp'] as int? ?? 0,
    );
  }

  final int completed;
  final int xp;
}

class ProgressionMilestone {
  ProgressionMilestone({
    required this.id,
    required this.label,
    required this.progress,
    required this.achieved,
    required this.reward,
  });

  factory ProgressionMilestone.fromJson(Map<String, dynamic> json) {
    return ProgressionMilestone(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      achieved: json['achieved'] as bool? ?? false,
      reward: json['reward'] as String? ?? '',
    );
  }

  final String id;
  final String label;
  final double progress;
  final bool achieved;
  final String reward;
}

class ProgressionDay {
  ProgressionDay({required this.day, required this.xp, required this.count});

  factory ProgressionDay.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    final rawDay = json['day'];
    if (rawDay is String && rawDay.isNotEmpty) {
      parsed = DateTime.tryParse(rawDay);
    }
    return ProgressionDay(
      day: parsed ?? DateTime.now(),
      xp: json['xp'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }

  final DateTime day;
  final int xp;
  final int count;
}

class ProgressionSnapshot {
  ProgressionSnapshot({
    required this.summary,
    required this.today,
    required this.weeklyXp,
    required this.milestones,
  });

  factory ProgressionSnapshot.fromJson(Map<String, dynamic> json) {
    final weekly = (json['weekly_xp'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProgressionDay.fromJson)
        .toList();
    final milestones = (json['milestones'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProgressionMilestone.fromJson)
        .toList();
    return ProgressionSnapshot(
      summary: ProgressionSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      today: ProgressionToday.fromJson(
        json['today'] as Map<String, dynamic>? ?? {},
      ),
      weeklyXp: weekly,
      milestones: milestones,
    );
  }

  final ProgressionSummary summary;
  final ProgressionToday today;
  final List<ProgressionDay> weeklyXp;
  final List<ProgressionMilestone> milestones;
}
