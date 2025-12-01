class UserSession {
  const UserSession({
    required this.id,
    required this.username,
    required this.email,
    required this.isGuest,
    this.createdAt,
    this.fullName,
    this.plan,
    this.trialDaysLeft,
    this.streakCurrent,
    this.streakBest,
    this.streakMultiplier,
    this.lastActivityAt,
    this.age,
    this.gender,
  });

  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String? plan;
  final bool isGuest;
  final DateTime? createdAt;
  final int? trialDaysLeft;
  final int? streakCurrent;
  final int? streakBest;
  final double? streakMultiplier;
  final DateTime? lastActivityAt;
  final int? age;
  final String? gender;

  String get displayName {
    final candidate = (fullName ?? username).trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
    if (email.isNotEmpty) {
      return email;
    }
    return "Guest";
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json["id"] as int,
      username: json["username"] as String? ?? "",
      email: json["email"] as String? ?? "",
      isGuest: json["is_guest"] as bool? ?? false,
      createdAt: _parseDate(json["created_at"] as String?),
      fullName: json["full_name"] as String?,
      plan: json["plan"] as String?,
      trialDaysLeft: json["trial_days_left"] as int?,
      streakCurrent: json["streak_current"] as int?,
      streakBest: json["streak_best"] as int?,
      streakMultiplier: (json["streak_multiplier"] as num?)?.toDouble(),
      lastActivityAt: _parseDate(json["last_activity_at"] as String?),
      age: json["age"] as int? ?? _coerceInt(json["age"]),
      gender: json["gender"] as String?,
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  static int? _coerceInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
