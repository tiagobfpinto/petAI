import 'activity_plan.dart';

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
    required this.rewardXp,
    required this.rewardCoins,
    required this.redeemed,
  });

  factory ProgressionMilestone.fromJson(Map<String, dynamic> json) {
    return ProgressionMilestone(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      achieved: json['achieved'] as bool? ?? false,
      reward: json['reward'] as String? ?? '',
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      rewardCoins: (json['reward_coins'] as num?)?.toInt() ?? 0,
      redeemed: json['redeemed'] as bool? ?? false,
    );
  }

  final String id;
  final String label;
  final double progress;
  final bool achieved;
  final String reward;
  final int rewardXp;
  final int rewardCoins;
  final bool redeemed;
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

class ProgressionWeeklyGoal {
  ProgressionWeeklyGoal({
    required this.interest,
    this.goal,
    this.plan,
    this.progress,
    this.progressValue,
    this.progressTarget,
    this.goalId,
    this.completed = false,
    this.redeemed = false,
    this.rewardXp = 0,
    this.rewardCoins = 0,
  });

  factory ProgressionWeeklyGoal.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'];
    final progressTarget = (json['progress_target'] as num?)?.toDouble();
    final progressValue = (json['progress_value'] as num?)?.toDouble();
    double? progress = (json['progress'] as num?)?.toDouble();
    if (progress == null && progressTarget != null && progressTarget > 0) {
      final ratio = (progressValue ?? 0) / progressTarget;
      progress = ratio.isFinite ? ratio : 0;
    }
    int? goalId;
    final rawGoalId = json['goal_id'];
    if (rawGoalId is int) {
      goalId = rawGoalId;
    } else if (rawGoalId is num) {
      goalId = rawGoalId.toInt();
    } else if (rawGoalId is String) {
      goalId = int.tryParse(rawGoalId);
    }
    return ProgressionWeeklyGoal(
      interest: json['interest'] as String? ?? '',
      goal: json['goal'] as String?,
      plan: planJson is Map<String, dynamic>
          ? ActivityPlan.fromJson(planJson)
          : null,
      progress: progress,
      progressValue: progressValue,
      progressTarget: progressTarget,
      goalId: goalId,
      completed: json['completed'] as bool? ?? false,
      redeemed: json['redeemed'] as bool? ?? false,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      rewardCoins: (json['reward_coins'] as num?)?.toInt() ?? 0,
    );
  }

  final String interest;
  final String? goal;
  final ActivityPlan? plan;
  final double? progress;
  final double? progressValue;
  final double? progressTarget;
  final int? goalId;
  final bool completed;
  final bool redeemed;
  final int rewardXp;
  final int rewardCoins;
}

class ProgressionCompletedGoal {
  ProgressionCompletedGoal({
    required this.goalId,
    required this.interest,
    this.activity,
    this.title,
    this.amount,
    this.unit,
    this.progressValue,
    this.completedAt,
    this.redeemedAt,
  });

  factory ProgressionCompletedGoal.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    int goalId = 0;
    final rawGoalId = json['goal_id'];
    if (rawGoalId is int) {
      goalId = rawGoalId;
    } else if (rawGoalId is num) {
      goalId = rawGoalId.toInt();
    } else if (rawGoalId is String) {
      goalId = int.tryParse(rawGoalId) ?? 0;
    }

    return ProgressionCompletedGoal(
      goalId: goalId,
      interest: json['interest'] as String? ?? '',
      activity: json['activity'] as String?,
      title: json['title'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      progressValue: (json['progress_value'] as num?)?.toDouble(),
      completedAt: parseDate(json['completed_at']),
      redeemedAt: parseDate(json['redeemed_at']),
    );
  }

  final int goalId;
  final String interest;
  final String? activity;
  final String? title;
  final double? amount;
  final String? unit;
  final double? progressValue;
  final DateTime? completedAt;
  final DateTime? redeemedAt;

  DateTime? get displayDate => redeemedAt ?? completedAt;
}

class ProgressionCompletedGoals {
  ProgressionCompletedGoals({
    required this.week,
    required this.month,
    required this.year,
  });

  factory ProgressionCompletedGoals.fromJson(Map<String, dynamic> json) {
    List<ProgressionCompletedGoal> parseList(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(ProgressionCompletedGoal.fromJson)
            .toList();
      }
      return const [];
    }

    return ProgressionCompletedGoals(
      week: parseList(json['week']),
      month: parseList(json['month']),
      year: parseList(json['year']),
    );
  }

  final List<ProgressionCompletedGoal> week;
  final List<ProgressionCompletedGoal> month;
  final List<ProgressionCompletedGoal> year;
}

class ProgressionSnapshot {
  ProgressionSnapshot({
    required this.summary,
    required this.today,
    required this.weeklyXp,
    required this.milestones,
    required this.weeklyGoals,
    required this.completedGoals,
    required this.pendingRewards,
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
    final goals = (json['weekly_goals'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProgressionWeeklyGoal.fromJson)
        .toList();
    final completedGoals = ProgressionCompletedGoals.fromJson(
      json['completed_goals'] as Map<String, dynamic>? ?? {},
    );
    return ProgressionSnapshot(
      summary: ProgressionSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      today: ProgressionToday.fromJson(
        json['today'] as Map<String, dynamic>? ?? {},
      ),
      weeklyXp: weekly,
      milestones: milestones,
      weeklyGoals: goals,
      completedGoals: completedGoals,
      pendingRewards: (json['pending_rewards'] as num?)?.toInt() ?? 0,
    );
  }

  final ProgressionSummary summary;
  final ProgressionToday today;
  final List<ProgressionDay> weeklyXp;
  final List<ProgressionMilestone> milestones;
  final List<ProgressionWeeklyGoal> weeklyGoals;
  final ProgressionCompletedGoals completedGoals;
  final int pendingRewards;
}
