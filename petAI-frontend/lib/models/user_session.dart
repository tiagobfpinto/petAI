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
  });

  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String? plan;
  final bool isGuest;
  final DateTime? createdAt;
  final int? trialDaysLeft;

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
}
