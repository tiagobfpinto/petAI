import 'package:flutter/material.dart';

class XpProgressBar extends StatelessWidget {
  const XpProgressBar({
    super.key,
    required this.progress,
    required this.xp,
    required this.nextXp,
  });

  final double progress;
  final int xp;
  final int nextXp;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final remaining = nextXp - xp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 12,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          remaining > 0
              ? "$xp / $nextXp XP • $remaining XP to evolve"
              : "$xp XP • maxed out!",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
        ),
      ],
    );
  }
}
