import 'package:flutter/material.dart';

import '../models/interest.dart';

final List<InterestBlueprint> interestCatalog = [
  InterestBlueprint(
    id: "running",
    name: "Running & Cardio",
    description:
        "Build stamina with approachable cardio sessions tailored to your pace.",
    accentColor: const Color(0xFFFF8A65),
    icon: Icons.directions_run_rounded,
    suggestedActivities: [
      "15 min guided jog",
      "Low impact HIIT set",
      "Long walk & podcast",
      "Stride drills with mobility",
    ],
    goalPresets: {
      MotivationLevel.never: const GoalPreset(
        title: "Ease into movement",
        description:
            "Start with gentle walks so your joints keep up with your motivation.",
        suggestion:
            "Plan two 15-minute brisk walks this week plus one stretch session.",
      ),
      MotivationLevel.sometimes: const GoalPreset(
        title: "Build rhythm",
        description: "Add a little structure so the habit sticks.",
        suggestion:
            "Lock three cardio days (Mon/Wed/Sat) with 20-minute runs or bike rides.",
      ),
      MotivationLevel.usually: const GoalPreset(
        title: "Level up pacing",
        description: "Blend endurance and speed to feel progress.",
        suggestion:
            "Do one interval workout, one tempo run, and a 30-minute recovery jog.",
      ),
      MotivationLevel.always: const GoalPreset(
        title: "Stay consistent",
        description: "Dial in performance without burning out.",
        suggestion:
            "Keep four sessions weekly with heart-rate tracking and mobility finishers.",
      ),
    },
  ),
  InterestBlueprint(
    id: "study",
    name: "Study & Deep Learning",
    description: "Protect focused time to learn faster and retain more.",
    accentColor: const Color(0xFF7E57C2),
    icon: Icons.menu_book_rounded,
    suggestedActivities: [
      "50 min focus block",
      "Active recall cards",
      "Review class notes",
      "Summarize a chapter",
    ],
    goalPresets: {
      MotivationLevel.never: const GoalPreset(
        title: "Start with sparks",
        description: "Keep sessions short and energizing.",
        suggestion:
            "Commit to two 25-minute study sprints with a single topic each.",
      ),
      MotivationLevel.sometimes: const GoalPreset(
        title: "Design a cadence",
        description: "Pomodoro blocks make consistency easier.",
        suggestion:
            "Schedule three 40-minute deep work blocks plus one review slot.",
      ),
      MotivationLevel.usually: const GoalPreset(
        title: "Sharpen mastery",
        description: "Layer practice and reflection.",
        suggestion:
            "Alternate four focus blocks with active recall and end-of-week summaries.",
      ),
      MotivationLevel.always: const GoalPreset(
        title: "Sustain excellence",
        description: "Keep challenging yourself with insights.",
        suggestion:
            "Maintain daily 45-minute sessions plus a weekly retrospective journal.",
      ),
    },
  ),
  InterestBlueprint(
    id: "project",
    name: "Work on a Project",
    description: "Ship meaningful progress on personal or side projects.",
    accentColor: const Color(0xFF26A69A),
    icon: Icons.auto_fix_high_rounded,
    suggestedActivities: [
      "Define sprint goals",
      "Design review",
      "Prototype feature",
      "Ship changelog",
    ],
    goalPresets: {
      MotivationLevel.never: const GoalPreset(
        title: "Find momentum",
        description: "Break the idea into the tiniest next steps.",
        suggestion:
            "Outline the outcome and block two 30-minute build sessions this week.",
      ),
      MotivationLevel.sometimes: const GoalPreset(
        title: "Protect build slots",
        description: "Rhythm beats intensity for creative work.",
        suggestion:
            "Book three evening sprints (45 min) and capture blockers in a log.",
      ),
      MotivationLevel.usually: const GoalPreset(
        title: "Ship confidently",
        description: "Add feedback loops to stay aligned.",
        suggestion:
            "Plan a mini sprint: backlog grooming Monday, two build days, Friday demo.",
      ),
      MotivationLevel.always: const GoalPreset(
        title: "Operate like a team",
        description: "Treat your project like a product.",
        suggestion:
            "Maintain weekly roadmap review plus daily 1-hour maker time.",
      ),
    },
  ),
  InterestBlueprint(
    id: "skincare",
    name: "Skincare Ritual",
    description: "Reward your skin (and brain) with calm, repeatable routines.",
    accentColor: const Color(0xFFEC407A),
    icon: Icons.face_retouching_natural_rounded,
    suggestedActivities: [
      "AM cleanse & SPF",
      "PM double cleanse",
      "Weekly mask reset",
      "Log product reactions",
    ],
    goalPresets: {
      MotivationLevel.never: const GoalPreset(
        title: "Just the essentials",
        description: "A lightweight routine reduces friction.",
        suggestion:
            "Do AM cleanse + SPF and nightly moisturizer at least four days.",
      ),
      MotivationLevel.sometimes: const GoalPreset(
        title: "Glow routine",
        description: "Stack habits you already enjoy.",
        suggestion:
            "Keep AM essentials daily and add two intentional PM rituals.",
      ),
      MotivationLevel.usually: const GoalPreset(
        title: "Targeted care",
        description: "Introduce treatments with purpose.",
        suggestion:
            "Maintain daily AM/PM plus two treatment nights (AHA or retinol).",
      ),
      MotivationLevel.always: const GoalPreset(
        title: "Skincare architect",
        description: "Keep logs so tweaks stay data-driven.",
        suggestion:
            "Review routine weekly, rotate actives, and log results with photos.",
      ),
    },
  ),
  InterestBlueprint(
    id: "eat-healthy",
    name: "Eat Healthy",
    description: "Plan meals that help you feel fueled, not restricted.",
    accentColor: const Color(0xFFFFC107),
    icon: Icons.local_dining_rounded,
    suggestedActivities: [
      "Plan groceries",
      "Batch prep bowls",
      "Hydration check-in",
      "Cook a new recipe",
    ],
    goalPresets: {
      MotivationLevel.never: const GoalPreset(
        title: "One gentle swap",
        description: "Small wins build trust.",
        suggestion:
            "Prep two balanced lunches ahead of time and track daily water.",
      ),
      MotivationLevel.sometimes: const GoalPreset(
        title: "Weekend prep flow",
        description: "Keep quick meals ready.",
        suggestion:
            "Plan three dinners, prep snacks Sunday, log how you feel afterwards.",
      ),
      MotivationLevel.usually: const GoalPreset(
        title: "Fuel with intention",
        description: "Dial macros to energy needs.",
        suggestion:
            "Maintain 80/20 balance with four home-cooked meals + veggie snacks.",
      ),
      MotivationLevel.always: const GoalPreset(
        title: "Chef of habits",
        description: "Variety keeps motivation high.",
        suggestion:
            "Rotate weekly menu themes and host one experimental cook night.",
      ),
    },
  ),
  InterestBlueprint(
    id: "wake-early",
    name: "Wake Up Early",
    description: "Design a wind-down ritual that makes mornings effortless.",
    accentColor: const Color(0xFF42A5F5),
    icon: Icons.wb_twilight_rounded,
    suggestedActivities: [
      "Prep tomorrow list",
      "Digital sunset alarm",
      "Morning light walk",
      "Track sleep quality",
    ],
    goalPresets: {
      MotivationLevel.never: const GoalPreset(
        title: "Shift gently",
        description: "Adjust bedtime in 15-minute increments.",
        suggestion:
            "Target lights out by 11:30 PM and 7:30 AM wake on four days.",
      ),
      MotivationLevel.sometimes: const GoalPreset(
        title: "Lock routine",
        description: "Anchor both ends of the day.",
        suggestion:
            "Create a 3-step wind-down and wake at the same time five days.",
      ),
      MotivationLevel.usually: const GoalPreset(
        title: "Own your mornings",
        description: "Layer in activation habits.",
        suggestion:
            "Wake by 6:30 AM with sunlight, hydration, and a 10-minute walk.",
      ),
      MotivationLevel.always: const GoalPreset(
        title: "Refine recovery",
        description: "Optimize sleep hygiene.",
        suggestion:
            "Keep six consistent wake-ups and track readiness in a journal.",
      ),
    },
  ),
  InterestBlueprint(
    id: "tidy-bed",
    name: "Do Your Bed",
    description: "Quick resets build identity-based habits.",
    accentColor: const Color(0xFF8D6E63),
    icon: Icons.king_bed_rounded,
    suggestedActivities: [
      "2-min tidy timer",
      "Swap linens weekly",
      "Lay out outfit",
      "Diffuser on / off",
    ],
    goalPresets: {
      MotivationLevel.never: const GoalPreset(
        title: "Quick reset",
        description: "Tie it to brushing your teeth.",
        suggestion:
            "Make the bed immediately after waking at least four mornings.",
      ),
      MotivationLevel.sometimes: const GoalPreset(
        title: "Stack the habit",
        description: "Attach it to morning coffee.",
        suggestion: "Keep bed making + 2 minute tidy on five mornings.",
      ),
      MotivationLevel.usually: const GoalPreset(
        title: "Tidy mindset",
        description: "Add micro upgrades.",
        suggestion: "Make bed daily and reset nightstands twice a week.",
      ),
      MotivationLevel.always: const GoalPreset(
        title: "Zen suite",
        description: "Turn it into a ritual.",
        suggestion:
            "Maintain daily reset plus Sunday deep tidy with oils or playlists.",
      ),
    },
  ),
];

const List<Color> customInterestPalette = [
  Color(0xFFAB47BC),
  Color(0xFF00ACC1),
  Color(0xFF66BB6A),
  Color(0xFFFF7043),
  Color(0xFF5C6BC0),
];

final Map<String, InterestBlueprint> _catalogById = {
  for (final blueprint in interestCatalog) blueprint.id.toLowerCase(): blueprint,
};

final Map<String, String> _aliasIndex = _buildAliasIndex();
final Map<String, InterestBlueprint> _customBlueprintCache = {};

Map<String, String> _buildAliasIndex() {
  final aliases = <String, String>{};
  for (final blueprint in interestCatalog) {
    aliases[blueprint.name.toLowerCase()] = blueprint.id.toLowerCase();
  }
  const manual = <String, String>{
    "running": "running",
    "cardio": "running",
    "study": "study",
    "learn": "study",
    "work on a project": "project",
    "project": "project",
    "skincare": "skincare",
    "skin care": "skincare",
    "eat healthy": "eat-healthy",
    "nutrition": "eat-healthy",
    "wake up early": "wake-early",
    "morning routine": "wake-early",
    "make my bed": "tidy-bed",
    "do your bed": "tidy-bed",
    "tidy": "tidy-bed",
  };
  aliases.addAll(manual);
  return aliases.map((key, value) => MapEntry(key.toLowerCase(), value));
}

InterestBlueprint resolveInterestBlueprint(String rawName) {
  final normalized = rawName.trim().toLowerCase();
  final blueprintId = _aliasIndex[normalized];
  if (blueprintId != null) {
    final blueprint = _catalogById[blueprintId];
    if (blueprint != null) {
      return blueprint;
    }
  }
  return _buildCustomBlueprint(rawName);
}

InterestBlueprint _buildCustomBlueprint(String rawName) {
  final normalized = rawName.trim().isEmpty ? "Custom interest" : rawName.trim();
  final cacheKey = normalized.toLowerCase();
  return _customBlueprintCache.putIfAbsent(cacheKey, () {
    final color = _colorForName(cacheKey);
    return InterestBlueprint(
      id: "custom-${_slugify(cacheKey)}",
      name: normalized,
      description: "Your personalized track in PetAI.",
      accentColor: color,
      icon: Icons.auto_awesome_rounded,
      suggestedActivities: [
        "Brainstorm a tiny win",
        "Ask PetAI for inspiration",
        "Reflect for 2 minutes",
      ],
      goalPresets: _genericPresets(normalized),
    );
  });
}

Map<MotivationLevel, GoalPreset> _genericPresets(String name) {
  return {
    MotivationLevel.never: GoalPreset(
      title: "Ease into $name",
      description: "Start tiny so you can celebrate day one.",
      suggestion: "Spend 10 minutes exploring $name twice this week.",
    ),
    MotivationLevel.sometimes: GoalPreset(
      title: "Design a cadence",
      description: "Schedule it so momentum compounds.",
      suggestion: "Block three 20-minute sessions for $name and track one insight.",
    ),
    MotivationLevel.usually: GoalPreset(
      title: "Sharpen execution",
      description: "Add feedback loops to stay focused.",
      suggestion: "Ship two tangible outcomes for $name and journal learnings.",
    ),
    MotivationLevel.always: GoalPreset(
      title: "Optimize flow",
      description: "Refine the routine that already works.",
      suggestion: "Maintain four sessions for $name and review metrics weekly.",
    ),
  };
}

String _slugify(String input) {
  final sanitized = input.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "-");
  return sanitized.replaceAll(RegExp(r"^-+|-+\$"), "");
}

Color _colorForName(String name) {
  final hash = name.codeUnits.fold<int>(0, (sum, code) => sum + code);
  final index = hash.abs() % customInterestPalette.length;
  return customInterestPalette[index];
}

bool isKnownInterestName(String rawName) {
  return _aliasIndex.containsKey(rawName.trim().toLowerCase());
}
