class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.userId,
    required this.interestId,
    required this.xpEarned,
    required this.timestamp,
    required this.activity,
    required this.interest,
  });

  final int id;
  final int userId;
  final int interestId;
  final int xpEarned;
  final DateTime? timestamp;
  final String activity;
  final String interest;

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json["id"] as int? ?? 0,
      userId: json["user_id"] as int? ?? 0,
      interestId: json["interest_id"] as int? ?? 0,
      xpEarned: json["xp_earned"] as int? ?? 0,
      timestamp: _parseDate(json["timestamp"] as String?),
      activity: (json["activity"] as String? ?? "").trim(),
      interest: (json["interest"] as String? ?? "").trim(),
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }
}
