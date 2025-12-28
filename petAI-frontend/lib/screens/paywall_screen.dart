import 'package:flutter/material.dart';

import '../models/subscription_status.dart';
import '../models/user_session.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({
    super.key,
    required this.session,
    required this.subscription,
    required this.onManageAccount,
    required this.onRetry,
  });

  final UserSession session;
  final SubscriptionStatus? subscription;
  final VoidCallback onManageAccount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysLeft = session.trialDaysLeft ?? 0;
    final isGuest = session.isGuest;
    final status = subscription?.status ?? "none";
    final active = subscription?.active ?? false;

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
                      onPressed: onManageAccount,
                      child: Text(isGuest ? "Create account" : "Manage account"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text("Retry"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
