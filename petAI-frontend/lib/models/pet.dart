class PetState {
  const PetState({
    required this.level,
    required this.xp,
    required this.nextLevelXp,
  });

  final int level;
  final int xp;
  final int nextLevelXp;

  factory PetState.fromJson(Map<String, dynamic> json) {
    final level = (json['level'] as int?) ?? 1;
    final xp = (json['xp'] as int?) ?? 0;
    final nextXp =
        (json['next_level_xp'] as int?) ?? (json['nextLevelXp'] as int?) ?? 80;

    return PetState(
      level: level < 1 ? 1 : level,
      xp: xp < 0 ? 0 : xp,
      nextLevelXp: nextXp < 1 ? 80 : nextXp,
    );
  }

  PetState copyWith({int? level, int? xp, int? nextLevelXp}) {
    return PetState(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      nextLevelXp: nextLevelXp ?? this.nextLevelXp,
    );
  }
}
