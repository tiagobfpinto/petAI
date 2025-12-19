class FriendSearchResult {
  FriendSearchResult({required this.id, required this.username});

  final int id;
  final String username;

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    return FriendSearchResult(
      id: json["id"] as int? ?? 0,
      username: json["username"] as String? ?? "",
    );
  }
}
