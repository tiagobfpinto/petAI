class UserSummary {
  UserSummary({
    required this.id,
    required this.coins,
    required this.activityCount,
    this.username,
    this.email,
    this.fullName,
    this.plan,
    this.isGuest = false,
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final String? username;
  final String? email;
  final String? fullName;
  final String? plan;
  final bool isGuest;
  final bool isActive;
  final int coins;
  final int activityCount;
  final DateTime? createdAt;

  UserSummary copyWith({
    String? username,
    String? email,
    String? fullName,
    String? plan,
    bool? isGuest,
    bool? isActive,
    int? coins,
    int? activityCount,
    DateTime? createdAt,
  }) {
    return UserSummary(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      plan: plan ?? this.plan,
      isGuest: isGuest ?? this.isGuest,
      isActive: isActive ?? this.isActive,
      coins: coins ?? this.coins,
      activityCount: activityCount ?? this.activityCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: _asInt(json["id"]),
      username: _asString(json["username"]),
      email: _asString(json["email"]),
      fullName: _asString(json["full_name"]),
      plan: _asString(json["plan"]),
      isGuest: json["is_guest"] == true,
      isActive: json["is_active"] != false,
      coins: _asInt(json["coins"]),
      activityCount: _asInt(json["activity_count"]),
      createdAt: _parseDate(json["created_at"]),
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }
}
