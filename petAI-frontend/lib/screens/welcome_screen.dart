import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../models/session_bootstrap.dart';
import '../services/api_service.dart';

enum AuthMode { login, convert }

extension AuthModeLabel on AuthMode {
  String get title => this == AuthMode.login ? "SIGN IN" : "SIGN UP";
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.apiService,
    required this.onAuthenticated,
    this.isGuestSession = true,
    this.initialMode = AuthMode.login,
    this.enableAuthAnimation = true,
  });

  final ApiService apiService;
  final void Function(SessionBootstrap bootstrap) onAuthenticated;
  final bool isGuestSession;
  final AuthMode initialMode;
  final bool enableAuthAnimation;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  rive.FileLoader? _authRiveLoader;
  rive.RiveWidgetController? _authRiveController;
  AuthMode _riveMode = AuthMode.login;

  late AuthMode _mode;
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    if (_shouldLoadAuthAnimation()) {
      _authRiveLoader = rive.FileLoader.fromAsset(
        "assets/rive/login_anim.riv",
        riveFactory: rive.Factory.rive,
      );
    }
  }

  @override
  void dispose() {
    _authRiveLoader?.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildAuthBackground(context),
          _buildAuthBackgroundScrim(),
          SafeArea(child: _buildAuthForeground(context)),
        ],
      ),
    );
  }

  Widget _buildAuthForeground(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final topPadding = constraints.maxHeight < 720 ? 24.0 : 56.0;
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildAuthCard(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    final theme = Theme.of(context);
    final isLogin = _mode == AuthMode.login;
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(28);

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
              borderRadius: borderRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "Nuru beta",
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _mode.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLogin
                        ? "Sign in to sync your pet, goals, and streaks."
                        : "Create an account to keep Nuru on all devices.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_mode == AuthMode.convert) ...[
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              hintText: "Username",
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
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
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: isLogin ? "Email or username" : "Email",
                            prefixIcon: Icon(
                              isLogin
                                  ? Icons.person_outline_rounded
                                  : Icons.email_outlined,
                            ),
                            floatingLabelBehavior:
                                FloatingLabelBehavior.never,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return isLogin
                                  ? "Email or username is required"
                                  : "Email is required";
                            }
                            if (!isLogin && !value.contains("@")) {
                              return "Enter a valid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                              onPressed:
                                  () => setState(() => _obscure = !_obscure),
                            ),
                            floatingLabelBehavior:
                                FloatingLabelBehavior.never,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Password is required";
                            }
                            if (isLogin) {
                              return null;
                            }
                            if (value.length < 8) {
                              return "Minimum 8 characters";
                            }
                            if (!RegExp(r"\d").hasMatch(value)) {
                              return "Include at least 1 number";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(_mode.title),
                    ),
                  ),
                  if (isLogin) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        child: const Text("Forgot password?"),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildModeSwitchRow(context),
                  if (isLogin && widget.isGuestSession) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : _continueAsGuest,
                        icon: const Icon(Icons.explore_rounded, size: 18),
                        label: const Text("Continue as guest"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitchRow(BuildContext context) {
    final theme = Theme.of(context);
    final isLogin = _mode == AuthMode.login;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          isLogin ? "Don't have an account?" : "Already have an account?",
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => _setMode(isLogin ? AuthMode.convert : AuthMode.login),
          child: Text(isLogin ? "SIGN UP" : "SIGN IN"),
        ),
      ],
    );
  }

  bool _shouldLoadAuthAnimation() {
    if (!widget.enableAuthAnimation) return false;
    return !_isTestBinding;
  }

  bool get _isTestBinding {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains("TestWidgetsFlutterBinding");
  }

  Widget _buildAuthBackground(BuildContext context) {
    final authRiveLoader = _authRiveLoader;
    if (authRiveLoader == null) {
      return _buildAuthBackgroundPlaceholder(context);
    }

    return rive.RiveWidgetBuilder(
      fileLoader: authRiveLoader,
      stateMachineSelector: const rive.StateMachineDefault(),
      builder: (context, state) => switch (state) {
        rive.RiveLoading() => _buildAuthBackgroundPlaceholder(context),
        rive.RiveFailed() => _buildAuthBackgroundPlaceholder(context),
        rive.RiveLoaded() => Builder(
            builder: (context) {
              final controller = state.controller;
              if (_authRiveController != controller) {
                _authRiveController = controller;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _syncAuthAnimation();
                  }
                });
              }
              return rive.RiveWidget(
                controller: controller,
                fit: rive.Fit.cover,
              );
            },
          ),
      },
    );
  }

  Widget _buildAuthBackgroundScrim() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xB3FFFFFF),
            Color(0xCCFFFFFF),
            Color(0xE6FFFFFF),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthBackgroundPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topColor = colorScheme.primary.withValues(alpha: 0.14);
    final bottomColor = colorScheme.secondary.withValues(alpha: 0.10);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                topColor,
                const Color(0xFFFFFFFF),
                bottomColor,
              ],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _buildBackgroundBlob(
            colorScheme.primary.withValues(alpha: 0.18),
            260,
          ),
        ),
        Positioned(
          bottom: -120,
          left: -90,
          child: _buildBackgroundBlob(
            colorScheme.primary.withValues(alpha: 0.12),
            320,
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  void _setMode(AuthMode nextMode) {
    if (_mode == nextMode) return;
    setState(() => _mode = nextMode);
    _syncAuthAnimation();
  }

  void _continueAsGuest() {
    Navigator.of(context).maybePop();
  }

  void _handleForgotPassword() {
    _showSnack("Password reset isn't available yet.");
  }

  void _syncAuthAnimation() {
    if (_authRiveController == null) return;
    if (_riveMode == _mode) return;

    if (_mode == AuthMode.convert) {
      if (_fireAuthTrigger("left")) {
        _riveMode = AuthMode.convert;
      }
    } else {
      if (_fireAuthTrigger("right")) {
        _riveMode = AuthMode.login;
      }
    }
  }

  bool _fireAuthTrigger(String triggerName) {
    final controller = _authRiveController;
    if (controller == null) return false;
    final stateMachine = controller.stateMachine;

    // ignore: deprecated_member_use
    final direct = stateMachine.trigger(triggerName);
    if (direct != null) {
      direct.fire();
      return true;
    }

    final normalized = _normalizeRiveName(triggerName);
    // ignore: deprecated_member_use
    for (final input in stateMachine.inputs) {
      if (input is! rive.TriggerInput) continue;
      if (_normalizeRiveName(input.name) == normalized) {
        input.fire();
        return true;
      }
    }

    return false;
  }

  static String _normalizeRiveName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "");
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deriveUsername(String email) {
    String sanitized = email.split("@").first.toLowerCase();
    sanitized = sanitized
        .replaceAll(RegExp(r"[^a-z0-9]+"), "_")
        .replaceAll(RegExp(r"_+"), "_");
    sanitized = sanitized.replaceAll(RegExp(r"^_+|_+\$"), "");
    if (sanitized.isEmpty) {
      sanitized = "nuru_user";
    }
    return sanitized;
  }
}
