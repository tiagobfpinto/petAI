class UserSession {
  const UserSession({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.plan,
    
  });

  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String? plan;

  String get displayName {
    final candidate = (fullName ?? username).trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
    return email;
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json["id"] as int,
      username: json["username"] as String? ?? "",
      email: json["email"] as String? ?? "",
      fullName: json["full_name"] as String?,
      plan: json["plan"] as String?,
    );
  }
    
  factory UserSession.guest() {
    return const UserSession(
      id: -1,
      username: "Guest",
      email: "guest@local",
      fullName: "Guest User",
      plan: null,
    );
    
  }
    


}
