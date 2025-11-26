import 'package:flutter/material.dart';

import 'models/pet_state.dart';
import 'models/session_bootstrap.dart';
import 'models/user_interest.dart';
import 'models/user_session.dart';
import 'screens/interest_selection_screen.dart';
import 'screens/pet_home_screen.dart';
import 'screens/splash_screen.dart';
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
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  UserSession? _session;
  PetState? _pet;
  List<UserInterest> _interests = [];
  bool _needsInterestSetup = false;
  bool _isSyncing = false;
  bool _isBooting = true;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    _startBootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "petAI",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      home: _buildFlow(),
    );
  }

  Widget _buildFlow() {
    if (_isBooting) {
      return SplashScreen(
        message: "Syncing your pet...",
        error: _bootError,
        onRetry: _startBootstrap,
      );
    }

    if (_session == null) {
      return SplashScreen(
        message: "Reconnecting...",
        error: _bootError ?? "No active session found",
        onRetry: _startBootstrap,
      );
    }

    if (_needsInterestSetup || _interests.isEmpty) {
      return InterestSelectionScreen(
        apiService: _apiService,
        existingInterests: _interests,
        onSaved: (interests) {
          setState(() {
            _interests = interests;
            _needsInterestSetup = interests.isEmpty;
          });
        },
        onLogout: _handleLogout,
        onManageAccount: () =>
            _openAccountManager(initialMode: AuthMode.convert),
      );
    }

    if (_pet == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PetHomeScreen(
      apiService: _apiService,
      session: _session!,
      pet: _pet!,
      interests: _interests,
      isSyncing: _isSyncing,
      onLogout: _handleLogout,
      onManageAccount: _openAccountManager,
      onPetChanged: (pet) => setState(() => _pet = pet),
      onRefreshInterests: _loadInterests,
      onEditInterests: () => setState(() => _needsInterestSetup = true),
      onError: _showError,
    );
  }

  Future<void> _startBootstrap() async {
    setState(() {
      _isBooting = true;
      _bootError = null;
      _session = null;
      _pet = null;
      _interests = [];
      _needsInterestSetup = false;
    });

    await _apiService.hydrateToken();

    ApiResponse<SessionBootstrap> response = await _apiService.currentUser();
    if (!response.isSuccess && response.statusCode == 401) {
      await _apiService.clearToken();
    }
    if (!response.isSuccess) {
      response = await _apiService.createGuest();
    }

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      _applyBootstrap(response.data!);
      setState(() => _isBooting = false);
      _bootstrapSync();
    } else {
      setState(() {
        _bootError = response.error ?? "Failed to start session";
        _isBooting = false;
      });
    }
  }

  void _applyBootstrap(SessionBootstrap bootstrap) {
    _apiService.syncToken(bootstrap.token);
    setState(() {
      _session = bootstrap.user;
      _pet = bootstrap.pet;
      _needsInterestSetup = bootstrap.needInterestsSetup;
      _interests = [];
      _bootError = null;
    });
  }

  Future<void> _bootstrapSync() async {
    setState(() => _isSyncing = true);
    await Future.wait([_loadInterests(showErrors: false), _refreshPet()]);
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _openAccountManager({AuthMode initialMode = AuthMode.login}) async {
    if (!mounted) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          apiService: _apiService,
          onAuthenticated: (bootstrap) {
            navigator.pop();
            _applyBootstrap(bootstrap);
            _bootstrapSync();
          },
          isGuestSession: _session?.isGuest ?? true,
          initialMode: initialMode,
        ),
      ),
    );
  }

  Future<void> _loadInterests({bool showErrors = true}) async {
    final response = await _apiService.fetchUserInterests();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _interests = response.data!;
        _needsInterestSetup = _interests.isEmpty;
      });
    } else if (showErrors) {
      _showError(response.error ?? "Failed to load interests");
    }
  }

  Future<void> _refreshPet({bool showErrors = false}) async {
    final response = await _apiService.fetchPet();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() => _pet = response.data);
    } else if (showErrors) {
      _showError(response.error ?? "Failed to load pet");
    }
  }

  Future<void> _handleLogout() async {
    await _apiService.logout();
    if (!mounted) return;
    await _startBootstrap();
  }

  void _showError(String message) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
