class FriendProfile {
  FriendProfile({
    required this.id,
    required this.username,
    required this.petStage,
    required this.petLevel,
    required this.petXp,
    required this.petNextEvolutionXp,
  });

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? 'Friend',
      petStage: json['pet_stage'] as String? ?? 'egg',
      petLevel: json['pet_level'] as int? ?? 1,
      petXp: json['pet_xp'] as int? ?? 0,
      petNextEvolutionXp: json['pet_next_evolution_xp'] as int? ?? 0,
    );
  }

  final int id;
  final String username;
  final String petStage;
  final int petLevel;
  final int petXp;
  final int petNextEvolutionXp;
}

class FriendRequestEntry {
  FriendRequestEntry({
    required this.requestId,
    required this.username,
    required this.direction,
    required this.status,
  });

  factory FriendRequestEntry.fromJson(
    Map<String, dynamic> json, {
    required RequestDirection direction,
  }) {
    return FriendRequestEntry(
      requestId: json['request_id'] as int? ?? 0,
      username: (json['from_username'] ?? json['to_username'] ?? 'User') as String,
      direction: direction,
      status: json['status'] as String? ?? 'pending',
    );
  }

  final int requestId;
  final String username;
  final RequestDirection direction;
  final String status;
}

class FriendsOverview {
  FriendsOverview({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  factory FriendsOverview.fromJson(Map<String, dynamic> json) {
    final friends = (json['friends'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(FriendProfile.fromJson)
        .toList();
    final incoming = (json['incoming'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((entry) => FriendRequestEntry.fromJson(entry, direction: RequestDirection.incoming))
        .toList();
    final outgoing = (json['outgoing'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((entry) => FriendRequestEntry.fromJson(entry, direction: RequestDirection.outgoing))
        .toList();
    return FriendsOverview(friends: friends, incoming: incoming, outgoing: outgoing);
  }

  final List<FriendProfile> friends;
  final List<FriendRequestEntry> incoming;
  final List<FriendRequestEntry> outgoing;
}

enum RequestDirection { incoming, outgoing }
