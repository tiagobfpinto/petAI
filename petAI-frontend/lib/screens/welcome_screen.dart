import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/api_service.dart';

enum AuthMode { login, register }

extension AuthModeLabel on AuthMode {
  String get label => this == AuthMode.login ? "Log in" : "Create account";
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.apiService,
    required this.onAuthenticated,
  });

  final ApiService apiService;
  final void Function(UserSession session, bool isNewUser) onAuthenticated;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  AuthMode _mode = AuthMode.login;
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _mode == AuthMode.login ? "Welcome back" : "Create your account",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _mode == AuthMode.login
                  ? "Log in to jump straight into your suggested activities."
                  : "Sign up, pick interests, and we will help you set goals.",
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
                  value: AuthMode.register,
                  label: Text("Sign up"),
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
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_mode == AuthMode.register) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Name (optional)",
                        hintText: "How should PetAI call you?",
                      ),
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
                label: const Text("Forgot your goals? Recreate them"),
                onPressed: () {
                  setState(() {
                    _mode = AuthMode.register;
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
    final name = _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim();

    ApiResponse<UserSession> response;
    if (_mode == AuthMode.login) {
      response = await widget.apiService.login(
        email: email,
        password: password,
      );
    } else {
      final username = _deriveUsername(email, name);
      response = await widget.apiService.register(
        username: username,
        email: email,
        password: password,
        fullName: name,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess && response.data != null) {
      widget.onAuthenticated(response.data!, _mode == AuthMode.register);
    } else {
      _showSnack(response.error ?? "Something went wrong — try again.");
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deriveUsername(String email, String? fullName) {
    String sanitized = (fullName ?? email.split("@").first).toLowerCase();
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
