import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/interest_catalog.dart';
import '../models/interest.dart';
import '../models/pet.dart';

const _guestProfileKey = 'guest_profile_v1';
const _petProgressKey = 'pet_progress_v1';
const int trialDays = 3; // MVP: 3-day trial

class GuestProfile {
  GuestProfile({required this.trialStart, required this.configuredInterests});

  final DateTime trialStart;
  final List<SelectedInterest> configuredInterests;
}

class GuestStorage {
  /// Clears everything about the guest (interests, trial, completions, pet XP).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestProfileKey);
    await prefs.remove(_petProgressKey);
  }

  /// Saves the guest base profile (interests + trialStart).
  /// Called at the end of onboarding, when the guest chooses interests/goals.
  static Future<void> saveGuestProfile(
    List<SelectedInterest> configured, {
    DateTime? trialStartOverride,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final existingRaw = prefs.getString(_guestProfileKey);
    DateTime trialStart;
    Map<String, dynamic> baseData = {};

    if (existingRaw != null) {
      final data = jsonDecode(existingRaw) as Map<String, dynamic>;
      trialStart = DateTime.parse(data['trialStart'] as String);
      baseData = data;
    } else {
      trialStart = trialStartOverride ?? DateTime.now();
    }

    baseData['trialStart'] = trialStart.toIso8601String();
    baseData['configuredInterests'] = configured
        .map((c) => c.toGuestJson())
        .toList();

    await prefs.setString(_guestProfileKey, jsonEncode(baseData));
  }

  /// Loads the guest base profile (interests + trialStart).
  /// Ignores extra fields such as daily completions.
  static Future<GuestProfile?> loadGuestProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestProfileKey);
    if (raw == null) return null;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final trialStart = DateTime.parse(data['trialStart'] as String);
    final now = DateTime.now();

    // Trial expired?
    if (now.difference(trialStart).inDays >= trialDays) {
      await prefs.remove(_guestProfileKey);
      return null;
    }

    final configuredJson = data['configuredInterests'] as List<dynamic>? ?? [];

    final configured = configuredJson
        .map(
          (j) => selectedInterestFromGuestJson(
            j as Map<String, dynamic>,
            interestCatalog,
          ),
        )
        .toList();

    return GuestProfile(
      trialStart: trialStart,
      configuredInterests: configured,
    );
  }

  /// Saves today's completed activities for the guest and updates streak.
  static Future<void> saveGuestDailyCompletion(Set<String> completedIds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestProfileKey);
    if (raw == null) {
      // No guest profile yet; skip storing completions.
      return;
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;

    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T').first;

    final previousDateStr = data['lastActivityDate'] as String?;
    int streak = (data['streak'] as int?) ?? 0;

    if (completedIds.isNotEmpty) {
      if (previousDateStr == null) {
        streak = 1;
      } else {
        final prevDate = DateTime.parse(previousDateStr);
        final prev = DateTime(prevDate.year, prevDate.month, prevDate.day);
        final today = DateTime(now.year, now.month, now.day);
        final diffDays = today.difference(prev).inDays;

        if (diffDays == 0) {
          // Already counted streak today.
        } else if (diffDays == 1) {
          streak += 1;
        } else {
          streak = 1;
        }
      }

      // Only update lastActivityDate when there is at least one completion today.
      data['lastActivityDate'] = todayStr;
    }

    data['streak'] = streak;
    data['completedToday'] = completedIds.toList();

    await prefs.setString(_guestProfileKey, jsonEncode(data));
  }

  /// Reads the current streak (consecutive days with at least one completion).
  static Future<int> loadGuestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestProfileKey);
    if (raw == null) return 0;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    return (data['streak'] as int?) ?? 0;
  }

  /// Loads today's completions for the guest.
  /// If it's a different day, returns an empty set.
  static Future<Set<String>> loadGuestDailyCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestProfileKey);
    if (raw == null) return {};

    final data = jsonDecode(raw) as Map<String, dynamic>;

    final dateStr = data['lastActivityDate'] as String?;
    if (dateStr == null) return {};

    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (dateStr != todayStr) {
      return {};
    }

    final listDynamic = data['completedToday'] as List<dynamic>? ?? [];
    final list = listDynamic.map((e) => e.toString()).toList();

    return Set<String>.from(list);
  }

  static Future<PetState> loadPetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_petProgressKey);
    if (raw == null) {
      return const PetState(level: 1, xp: 0, nextLevelXp: 80);
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final level = (data['level'] as int?) ?? 1;
    final xp = (data['xp'] as int?) ?? 0;
    final nextXp = (data['nextLevelXp'] as int?) ?? 80;
    return PetState(
      level: level < 1 ? 1 : level,
      xp: xp < 0 ? 0 : xp,
      nextLevelXp: nextXp < 1 ? 80 : nextXp,
    );
  }

  static Future<void> savePetProgress({required PetState pet}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _petProgressKey,
      jsonEncode({
        'level': pet.level,
        'xp': pet.xp,
        'nextLevelXp': pet.nextLevelXp,
      }),
    );
  }
}
