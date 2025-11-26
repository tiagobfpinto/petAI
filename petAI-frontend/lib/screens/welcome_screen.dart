import 'package:flutter/material.dart';

import '../models/session_bootstrap.dart';
import '../services/api_service.dart';

enum AuthMode { login, convert }

extension AuthModeLabel on AuthMode {
  String get label => this == AuthMode.login ? "Log in" : "Create account";

  String get subtitle => this == AuthMode.login
      ? "Access an existing account"
      : "Upgrade this guest to keep progress";
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.apiService,
    required this.onAuthenticated,
    this.isGuestSession = true,
    this.initialMode = AuthMode.login,
  });

  final ApiService apiService;
  final void Function(SessionBootstrap bootstrap) onAuthenticated;
  final bool isGuestSession;
  final AuthMode initialMode;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  late AuthMode _mode;
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 880;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildStoryPanel(context)),
                              const SizedBox(width: 32),
                              Expanded(child: _buildFormCard(context)),
                            ],
                          )
                        : Column(
                            children: [
                              _buildStoryPanel(context),
                              const SizedBox(height: 24),
                              _buildFormCard(context),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoryPanel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    const featurePoints = [
      (
        "Curated onboarding",
        "Tell PetAI what you want to improve and we build the playbook.",
      ),
      (
        "Adaptive goals",
        "Every interest comes with a level-based starter goal you can tweak.",
      ),
      (
        "Tap to complete",
        "Daily suggestions stay in sync with what you select.",
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.95),
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "petAI beta",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Coach yourself with\nAI-crafted routines.",
            style: textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Log habits, pick interests, and let PetAI surface the next micro-action.",
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 32),
          Column(
            children: featurePoints
                .map(
                  (tuple) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tuple.$1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tuple.$2,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Pick interests first, goals next. PetAI then suggests daily actions you can check off.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLogin = _mode == AuthMode.login;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLogin ? "Welcome back" : "Create your account",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isLogin
                  ? "Log in to sync your pet, goals, and streaks."
                  : "Convert this guest profile to keep progress on reinstall.",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SegmentedButton<AuthMode>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                selectedBackgroundColor: colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                selectedForegroundColor: colorScheme.primary,
                foregroundColor: Colors.grey.shade800,
              ),
              segments: const [
                ButtonSegment(
                  value: AuthMode.login,
                  label: Text("Log in"),
                  icon: Icon(Icons.login_rounded),
                ),
                ButtonSegment(
                  value: AuthMode.convert,
                  label: Text("Create account"),
                  icon: Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() {
                  _mode = value.first;
                });
              },
            ),
            const SizedBox(height: 12),
            if (widget.isGuestSession)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.key_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Guest session detected. Create an account to keep this pet on all devices.",
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_mode == AuthMode.convert) ...[
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Username",
                        hintText: "Choose your public handle",
                      ),
                      validator: (value) {
                        if (_mode != AuthMode.convert) return null;
                        if (value == null || value.trim().isEmpty) {
                          return "Username is required";
                        }
                        if (value.trim().length < 3) {
                          return "Use at least 3 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      hintText: "you@email.com",
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Email is required";
                      }
                      if (!value.contains("@")) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return "Minimum 6 characters";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(
                        _mode == AuthMode.login
                            ? Icons.login_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(_mode.label),
                onPressed: _isLoading ? null : _handleSubmit,
              ),
            ),
            if (_mode == AuthMode.login) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.explore_rounded),
                label: const Text("Stay as guest for now"),
                onPressed: () {
                  setState(() {
                    _mode = AuthMode.convert;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final username = _usernameCtrl.text.trim();

    ApiResponse<SessionBootstrap> response;
    if (_mode == AuthMode.login) {
      response = await widget.apiService.login(
        email: email,
        password: password,
      );
    } else {
      if (!widget.isGuestSession) {
        setState(() => _isLoading = false);
        _showSnack("You already have an account. Log out to convert a guest.");
        return;
      }
      final resolvedUsername =
          username.isEmpty ? _deriveUsername(email) : username;
      response = await widget.apiService.convertGuest(
        username: resolvedUsername,
        email: email,
        password: password,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess && response.data != null) {
      widget.onAuthenticated(response.data!);
    } else {
      _showSnack(response.error ?? "Something went wrong, try again.");
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deriveUsername(String email) {
    String sanitized = email.split("@").first.toLowerCase();
    sanitized = sanitized
        .replaceAll(RegExp(r"[^a-z0-9]+"), "_")
        .replaceAll(RegExp(r"_+"), "_");
    sanitized = sanitized.replaceAll(RegExp(r"^_+|_+\$"), "");
    if (sanitized.isEmpty) {
      sanitized = "petai_user";
    }
    return sanitized;
  }
}
