import "package:flutter/material.dart";

import "screens/login_screen.dart";
import "screens/users_screen.dart";
import "services/admin_api_service.dart";

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final AdminApiService _api = AdminApiService();
  bool _ready = false;
  bool _authenticated = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _probeSession();
  }

  Future<void> _probeSession() async {
    final result = await _api.fetchUsers(limit: 1);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _authenticated = true;
        _ready = true;
      });
      return;
    }
    setState(() {
      _authenticated = false;
      _ready = true;
      if (result.statusCode != null && result.statusCode! >= 500) {
        _startupError = result.error ?? "Backend unavailable.";
      }
    });
  }

  void _handleLoggedIn() {
    setState(() {
      _authenticated = true;
    });
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _authenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "petAI Admin",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_authenticated) {
      return UsersScreen(api: _api, onLogout: _handleLogout);
    }
    return Stack(
      children: [
        LoginScreen(api: _api, onLoggedIn: _handleLoggedIn),
        if (_startupError != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _startupError!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
