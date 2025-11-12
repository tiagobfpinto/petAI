import 'package:flutter/material.dart';

import 'data/interest_catalog.dart';
import 'models/interest.dart';
import 'models/user_session.dart';
import 'screens/daily_focus_screen.dart';
import 'screens/goal_setup_screen.dart';
import 'screens/interest_selection_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/api_service.dart';
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
  List<InterestBlueprint> _pendingSelection = [];
  List<SelectedInterest> _configured = [];

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
          setState(() {
            _session = session;
            _isFresh = isNewUser;
            _pendingSelection = [];
            _configured = [];
          });
        },
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
        onComplete: (configured) {
          setState(() {
            _configured = configured;
            _isFresh = false;
            _pendingSelection = [];
          });
        },
      );
    }

    final interests = _configured.isNotEmpty
        ? _configured
        : _fallbackSelections();

    return DailyFocusScreen(
      session: _session!,
      configuredInterests: interests,
      onLogout: _resetAll,
      onRefineGoals: () {
        setState(() {
          _isFresh = true;
          _pendingSelection = interests.map((item) => item.blueprint).toList();
          _configured = [];
        });
      },
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

  void _resetAll() {
    setState(() {
      _session = null;
      _isFresh = false;
      _pendingSelection = [];
      _configured = [];
    });
  }
}
