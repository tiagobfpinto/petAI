class DailyActivity {
  const DailyActivity({
    required this.id,
    required this.interestId,
    required this.activityTypeId,
    required this.title,
    required this.scheduledFor,
    required this.status,
    this.goalId,
    this.goalUnit,
    this.completedAt,
    this.xpAwarded,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      id: json['id'] as int? ?? 0,
      interestId: json['interest_id'] as int? ?? 0,
      activityTypeId: json['activity_type_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      scheduledFor:
          DateTime.tryParse(json['scheduled_for'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      goalId: json['goal_id'] as int?,
      goalUnit: (json['goal_unit'] as String?)?.trim(),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
      xpAwarded: json['xp_awarded'] as int?,
    );
  }

  final int id;
  final int interestId;
  final int activityTypeId;
  final int? goalId;
  final String? goalUnit;
  final String title;
  final DateTime scheduledFor;
  final String status;
  final DateTime? completedAt;
  final int? xpAwarded;

  bool get isCompleted => status.toLowerCase() == 'completed';
}
