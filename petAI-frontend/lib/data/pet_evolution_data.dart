class PetEvolutionBreakpoint {
  const PetEvolutionBreakpoint({
    required this.level,
    required this.stage,
    required this.xpRequired,
  });

  final int level;
  final String stage;
  final int xpRequired;
}

const List<PetEvolutionBreakpoint> petEvolutionBreakpoints = [
  PetEvolutionBreakpoint(level: 1, stage: "egg", xpRequired: 0),
  PetEvolutionBreakpoint(level: 2, stage: "sprout", xpRequired: 100),
  PetEvolutionBreakpoint(level: 3, stage: "bud", xpRequired: 250),
  PetEvolutionBreakpoint(level: 4, stage: "plant", xpRequired: 500),
  PetEvolutionBreakpoint(level: 5, stage: "tree", xpRequired: 1000),
];

PetEvolutionBreakpoint breakpointForLevel(int level) {
  return petEvolutionBreakpoints.firstWhere(
    (breakpoint) => breakpoint.level == level,
    orElse: () => petEvolutionBreakpoints.first,
  );
}

int xpFloorForLevel(int level) {
  if (level <= 1) return 0;
  final breakpoint = petEvolutionBreakpoints
      .where((entry) => entry.level <= level)
      .fold<PetEvolutionBreakpoint>(
        petEvolutionBreakpoints.first,
        (previous, element) => element.level > previous.level ? element : previous,
      );
  return breakpoint.xpRequired;
}

PetEvolutionBreakpoint? nextBreakpointAfter(int level) {
  final sorted = List<PetEvolutionBreakpoint>.from(petEvolutionBreakpoints)
    ..sort((a, b) => a.level.compareTo(b.level));
  for (final breakpoint in sorted) {
    if (breakpoint.level > level) {
      return breakpoint;
    }
  }
  return null;
}
