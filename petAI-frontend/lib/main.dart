import 'package:flutter/material.dart';

import 'data/interest_catalog.dart';
import 'models/interest.dart';
import 'models/user_session.dart';
import 'screens/daily_focus_screen.dart';
import 'screens/goal_setup_screen.dart';
import 'screens/interest_selection_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/api_service.dart';
import 'services/guest_storage.dart'; // 👈 trial + guest storage
import 'theme/app_theme.dart';

void main() {
  runApp(const PetAiApp());
}

class PetAiApp extends StatefulWidget {
  const PetAiApp({super.key});

  @override
  State<PetAiApp> createState() => _PetAiAppState();
}

class _PetAiAppState extends State<PetAiApp> {
  final ApiService _apiService = ApiService();

  UserSession? _session;
  bool _isFresh = false;
  bool _isUpgradingFromGuest = false;

  DateTime? _guestTrialStart;

  List<InterestBlueprint> _pendingSelection = [];
  List<SelectedInterest> _configured = [];

  @override
  void initState() {
    super.initState();
    _restoreGuestIfAny();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "petAI",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: _buildFlow(),
    );
  }

  Widget _buildFlow() {
    if (_session == null) {
  return WelcomeScreen(
    apiService: _apiService,
    onAuthenticated: (session, isNewUser) {
      // se for conta real (não guest) → limpar perfil guest local
      if (session.id != -1) {
        GuestStorage.clear();
        _guestTrialStart = null;
      }

      setState(() {
        _session = session;

        if (_isUpgradingFromGuest) {
          _isFresh = false;
        } else {
          _isFresh = isNewUser;
          _pendingSelection = [];
          _configured = [];
        }

        _isUpgradingFromGuest = false;
      });
    },
    hideGuestOption: _isUpgradingFromGuest, // 👈 AQUI
  );
}


    if (_isFresh) {
      if (_pendingSelection.isEmpty) {
        return InterestSelectionScreen(
          catalog: interestCatalog,
          onContinue: (selection) {
            if (selection.isEmpty) return;
            setState(() => _pendingSelection = selection);
          },
          onLogout: _resetAll,
        );
      }
      return GoalSetupScreen(
        interests: _pendingSelection,
        onBack: () => setState(() => _pendingSelection = []),
        onComplete: (configured) async {
          setState(() {
            _configured = configured;
            _isFresh = false;
            _pendingSelection = [];
            _guestTrialStart ??= DateTime.now();
          });

          // se estivermos em guest, guardar o perfil localmente
          if (_session != null && _session!.id == -1) {
            await GuestStorage.saveGuestProfile(
              configured,
              trialStartOverride: _guestTrialStart,
            );
          }
        },
      );
    }

    final interests =
        _configured.isNotEmpty ? _configured : _fallbackSelections();

    return DailyFocusScreen(
      session: _session!,
      apiService: _apiService,
      configuredInterests: interests,
      onLogout: _resetAll,
      onRefineGoals: () {
        setState(() {
          _isFresh = true;
          _pendingSelection =
              interests.map((item) => item.blueprint).toList();
          _configured = [];
        });
      },
      onRequireAccount: () {
        setState(() {
          _session = null;
          _isFresh = false;
          _pendingSelection = [];
          _isUpgradingFromGuest = true;
        });
      },
      trialDaysLeft: _trialDaysLeftForCurrentGuest(),
    );
  }

  List<SelectedInterest> _fallbackSelections() {
    return interestCatalog.take(3).map((blueprint) {
      final preset = blueprint.presetFor(MotivationLevel.usually);
      return SelectedInterest(
        blueprint: blueprint,
        level: MotivationLevel.usually,
        goal: preset.suggestion,
      );
    }).toList();
  }

  int? _trialDaysLeftForCurrentGuest() {
    if (_session == null || _session!.id != -1) return null;
    if (_guestTrialStart == null) return null;

    final now = DateTime.now();
    final used = now.difference(_guestTrialStart!).inDays;

    // 'trialDays' vem do guest_storage.dart
    final left = trialDays - used;

    if (left < 0) return 0;
    return left;
  }

  Future<void> _restoreGuestIfAny() async {
    final profile = await GuestStorage.loadGuestProfile();
    if (profile == null) return;

    setState(() {
      _session = UserSession(
        id: -1,
        username: 'guest',
        email: '',
        fullName: null,
        plan: null,
      );
      _configured = profile.configuredInterests;
      _pendingSelection = [];
      _isFresh = false;
      _guestTrialStart = profile.trialStart;
      _isUpgradingFromGuest = false;
    });
  }

  void _resetAll() {
    setState(() {
      _session = null;
      _isFresh = false;
      _pendingSelection = [];
      _configured = [];
      _guestTrialStart = null;
      _isUpgradingFromGuest = false;
    });
    GuestStorage.clear();
  }
}
