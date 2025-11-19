import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/interest_catalog.dart';
import '../models/interest.dart';

const _guestProfileKey = 'guest_profile_v1';
const int trialDays = 5; // 👈 muda aqui se quiseres 3 dias, 7, etc.

class GuestProfile {
  GuestProfile({
    required this.trialStart,
    required this.configuredInterests,
  });

  final DateTime trialStart;
  final List<SelectedInterest> configuredInterests;
}

class GuestStorage {
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestProfileKey);
  }

  static Future<void> saveGuestProfile(
    List<SelectedInterest> configured, {
    DateTime? trialStartOverride,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Se já existir profile, manter a data de início do trial
    final existingRaw = prefs.getString(_guestProfileKey);
    DateTime trialStart;
    if (existingRaw != null) {
      final data = jsonDecode(existingRaw) as Map<String, dynamic>;
      trialStart = DateTime.parse(data['trialStart'] as String);
    } else {
      trialStart = trialStartOverride ?? DateTime.now();
    }

    final data = {
      "trialStart": trialStart.toIso8601String(),
      "configuredInterests":
          configured.map((c) => c.toGuestJson()).toList(),
    };

    await prefs.setString(_guestProfileKey, jsonEncode(data));
  }

  static Future<GuestProfile?> loadGuestProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestProfileKey);
    if (raw == null) return null;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final trialStart = DateTime.parse(data['trialStart'] as String);
    final now = DateTime.now();

    // trial expirou?
    if (now.difference(trialStart).inDays >= trialDays) {
      await prefs.remove(_guestProfileKey);
      return null;
    }

    final configuredJson =
        data['configuredInterests'] as List<dynamic>? ?? [];

    final configured = configuredJson
        .map((j) => selectedInterestFromGuestJson(
              j as Map<String, dynamic>,
              interestCatalog,
            ))
        .toList();

    return GuestProfile(
      trialStart: trialStart,
      configuredInterests: configured,
    );
  }
}
