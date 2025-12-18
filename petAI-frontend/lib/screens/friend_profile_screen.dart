import 'dart:math';

import 'package:flutter/material.dart';

import '../models/friend_profile.dart';
import '../widgets/pet_sprite.dart';
import '../widgets/xp_progress_bar.dart';

class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({
    super.key,
    required this.friend,
  });

  final FriendProfile friend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = friend.petStage.trim().isEmpty ? "egg" : friend.petStage.trim();
    final progressBase = friend.petNextEvolutionXp <= 0
        ? 0.0
        : friend.petXp / max(1, friend.petNextEvolutionXp);
    final progress = progressBase.clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(friend.username),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
              final size = min(maxWidth, 280.0);
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.16),
                            theme.colorScheme.secondary.withValues(alpha: 0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: PetSprite(
                          stage: stage,
                          mood: max(1, friend.petLevel),
                          cosmetics: friend.petCosmetics,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            stage.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            "Level ${friend.petLevel}",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          XpProgressBar(
            progress: progress,
            xp: friend.petXp,
            nextXp: friend.petNextEvolutionXp,
          ),
        ],
      ),
    );
  }
}

