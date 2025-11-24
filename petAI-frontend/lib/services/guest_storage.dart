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
      /// Atualiza também o streak de dias seguidos em que o guest completou algo.
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

        final now = DateTime.now();
        final todayStr = now.toIso8601String().split('T').first;

        final previousDateStr = data['lastActivityDate'] as String?;
        int streak = (data['streak'] as int?) ?? 0;

        if (completedIds.isNotEmpty) {
          if (previousDateStr == null) {
            // primeira vez que completa algo
            streak = 1;
          } else {
            final prevDate = DateTime.parse(previousDateStr);
            final prev = DateTime(prevDate.year, prevDate.month, prevDate.day);
            final today = DateTime(now.year, now.month, now.day);
            final diffDays = today.difference(prev).inDays;

            if (diffDays == 0) {
              // já contou streak hoje → mantém
            } else if (diffDays == 1) {
              // dia seguinte → streak++
              streak += 1;
            } else {
              // quebrou streak → volta a 1
              streak = 1;
            }
          }

          // só atualizamos lastActivityDate quando há pelo menos uma completion hoje
          data['lastActivityDate'] = todayStr;
        }

        data['streak'] = streak;
        data['completedToday'] = completedIds.toList();

        await prefs.setString(_guestProfileKey, jsonEncode(data));
      }

            /// Lê o streak atual do guest (dias seguidos com pelo menos uma activity completada).
      static Future<int> loadGuestStreak() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_guestProfileKey);
      if (raw == null) return 0;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      return (data['streak'] as int?) ?? 0;
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
