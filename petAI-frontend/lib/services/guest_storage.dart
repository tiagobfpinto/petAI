import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/interest_catalog.dart';
import '../models/interest.dart';

const _guestProfileKey = 'guest_profile_v1';
const int trialDays = 3; // MVP: 3 dias de trial

class GuestProfile {
  GuestProfile({
    required this.trialStart,
    required this.configuredInterests,
  });

  final DateTime trialStart;
  final List<SelectedInterest> configuredInterests;
}

class GuestStorage {
  /// Apaga tudo sobre o guest (interesses, trial, completions, etc.)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestProfileKey);
  }

  /// Guarda o perfil base do guest (interesses + trialStart).
  /// Usa-se no fim do onboarding, quando o guest escolhe interesses/goals.
  static Future<void> saveGuestProfile(
    List<SelectedInterest> configured, {
    DateTime? trialStartOverride,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Se já existir profile, manter a data de início do trial
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
    baseData['configuredInterests'] =
        configured.map((c) => c.toGuestJson()).toList();

    await prefs.setString(_guestProfileKey, jsonEncode(baseData));
  }

  /// Carrega o perfil base do guest (interesses + trialStart).
  /// Ignora campos extra como completions diários.
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

  /// Guarda as activities completadas HOJE para o guest.
  /// Não mexe em trialStart nem configuredInterests.
  static Future<void> saveGuestDailyCompletion(
    Set<String> completedIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestProfileKey);
    if (raw == null) {
      // ainda não há perfil guest, não vale a pena guardar só completions
      return;
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;

    // Guardamos só a data (yyyy-mm-dd) para saber se é outro dia
    final todayStr = DateTime.now().toIso8601String().split('T').first;

    data['lastActivityDate'] = todayStr;
    data['completedToday'] = completedIds.toList();

    await prefs.setString(_guestProfileKey, jsonEncode(data));
  }

  /// Carrega as completions de HOJE para o guest.
  /// Se for outro dia, devolve set vazio (reset diário natural).
  static Future<Set<String>> loadGuestDailyCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestProfileKey);
    if (raw == null) return {};

    final data = jsonDecode(raw) as Map<String, dynamic>;

    final dateStr = data['lastActivityDate'] as String?;
    if (dateStr == null) return {};

    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (dateStr != todayStr) {
      // É um novo dia → não carregamos completions antigas
      return {};
    }

    final listDynamic = data['completedToday'] as List<dynamic>? ?? [];
    final list = listDynamic.map((e) => e.toString()).toList();

    return Set<String>.from(list);
  }
}
