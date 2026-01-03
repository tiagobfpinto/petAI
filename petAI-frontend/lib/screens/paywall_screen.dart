import 'package:flutter/material.dart';

import '../models/subscription_status.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.session,
    required this.subscription,
    required this.apiService,
    required this.onManageAccount,
    required this.onRetry,
  });

  final UserSession session;
  final SubscriptionStatus? subscription;
  final ApiService apiService;
  final VoidCallback onManageAccount;
  final VoidCallback onRetry;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isRedeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysLeft = widget.session.trialDaysLeft ?? 0;
    final isGuest = widget.session.isGuest;
    final status = widget.subscription?.status ?? "none";
    final active = widget.subscription?.active ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: theme.colorScheme.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Subscription required",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    daysLeft > 0
                        ? "$daysLeft day${daysLeft == 1 ? "" : "s"} left in free trial."
                        : "Your free trial has ended.",
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    active
                        ? "We detected an active subscription ($status). Tap retry to refresh."
                        : "Subscribe for €4.99 to keep using PetAI.",
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onManageAccount,
                      child: Text(isGuest ? "Create account" : "Manage account"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onRetry,
                      child: const Text("Retry"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAccessCodeCard(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessCodeCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Have an access code?",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: "Enter code",
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isRedeeming ? null : _redeemCode,
              child: _isRedeeming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Unlock with code"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemCode() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showSnack("Code not working");
      return;
    }

    setState(() => _isRedeeming = true);
    final response = await widget.apiService.redeemAccessCode(code);
    if (!mounted) return;
    setState(() => _isRedeeming = false);

    if (response.isSuccess) {
      _codeController.clear();
      widget.onRetry();
      _showSnack("Access unlocked");
    } else {
      _showSnack(response.error ?? "Code not working");
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
