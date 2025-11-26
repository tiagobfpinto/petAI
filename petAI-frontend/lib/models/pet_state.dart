import '../data/pet_evolution_data.dart';

class PetState {
  const PetState({
    required this.id,
    required this.userId,
    required this.xp,
    required this.level,
    required this.stage,
    required this.nextEvolutionXp,
    required this.petType,
    this.currentSprite,
  });

  final int id;
  final int userId;
  final int xp;
  final int level;
  final String stage;
  final int nextEvolutionXp;
  final String petType;
  final String? currentSprite;

  factory PetState.fromJson(Map<String, dynamic> json) {
    return PetState(
      id: json["id"] as int? ?? 0,
      userId: json["user_id"] as int? ?? 0,
      xp: json["xp"] as int? ?? 0,
      level: json["level"] as int? ?? 1,
      stage: json["stage"] as String? ?? "egg",
      nextEvolutionXp: json["next_evolution_xp"] as int? ?? 100,
      petType: json["pet_type"] as String? ?? "sprout",
      currentSprite: json["current_sprite"] as String?,
    );
  }

  PetState copyWith({
    int? id,
    int? userId,
    int? xp,
    int? level,
    String? stage,
    int? nextEvolutionXp,
    String? petType,
    String? currentSprite,
  }) {
    return PetState(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      stage: stage ?? this.stage,
      nextEvolutionXp: nextEvolutionXp ?? this.nextEvolutionXp,
      petType: petType ?? this.petType,
      currentSprite: currentSprite ?? this.currentSprite,
    );
  }

  int get currentLevelFloor => xpFloorForLevel(level);

  double get progressToNext {
    final floor = currentLevelFloor;
    final ceil = nextEvolutionXp <= floor ? floor + 1 : nextEvolutionXp;
    if (ceil == floor) return 1.0;
    final progress = (xp - floor) / (ceil - floor);
    if (progress.isNaN) return 0.0;
    return progress.clamp(0.0, 1.0);
  }
}
