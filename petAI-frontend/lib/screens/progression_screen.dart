import 'dart:math';

import 'package:flutter/material.dart';

import '../models/progression_snapshot.dart';
import '../services/api_service.dart';

class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({
    super.key,
    required this.apiService,
    required this.onError,
  });

  final ApiService apiService;
  final void Function(String message) onError;

  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen> {
  ProgressionSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgression();
  }

  Future<void> _loadProgression() async {
    setState(() => _loading = true);
    final response = await widget.apiService.fetchProgression();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _snapshot = response.data;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      widget.onError(response.error ?? "Failed to load progression");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_snapshot == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _loadProgression,
          child: const Text("Reload progression"),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProgression,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _summaryCard(context, _snapshot!.summary),
          const SizedBox(height: 14),
          _todayRow(_snapshot!.today),
          const SizedBox(height: 14),
          _weeklyGoals(_snapshot!.weeklyGoals),
          const SizedBox(height: 14),
          _weeklyXp(_snapshot!.weeklyXp),
          const SizedBox(height: 14),
          _milestones(_snapshot!.milestones),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, ProgressionSummary summary) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_nature_rounded, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Stage: ${summary.stage}",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    "Level ${summary.level} • ${summary.interests} interests",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text("Streak", style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      "${summary.streakCurrent}d",
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      "Best ${summary.streakBest}",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: summary.xpProgress,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${summary.xp} / ${summary.nextEvolutionXp} XP to next evolution",
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _todayRow(ProgressionToday today) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.bolt_rounded,
            label: "Today's XP",
            value: "${today.xp}",
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_rounded,
            label: "Wins logged",
            value: "${today.completed}",
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _weeklyGoals(List<ProgressionWeeklyGoal> goals) {
    if (goals.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Weekly goals",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...goals.map(_weeklyGoalCard),
      ],
    );
  }

  Widget _weeklyGoalCard(ProgressionWeeklyGoal goal) {
    final plan = goal.plan;
    final hasPlan = plan != null && plan.weeklyGoalValue > 0;
    final target = hasPlan
        ? "${plan!.weeklyGoalValue.toStringAsFixed(plan.weeklyGoalValue >= 10 ? 0 : 1)} ${plan.weeklyGoalUnit}"
        : "Not set";
    final days = hasPlan && plan!.days.isNotEmpty ? plan.days.join(", ").toUpperCase() : "Flexible";
    final perDay = hasPlan && plan!.perDayGoal() > 0 ? plan.perDayGoal().toStringAsFixed(1) : null;
    final progressTarget = goal.progressTarget ?? plan?.weeklyGoalValue ?? 0;
    final progressValue = goal.progressValue ?? 0;
    final progress = (goal.progress ?? (progressTarget > 0 ? progressValue / progressTarget : 0))
        .clamp(0.0, 1.0)
        .toDouble();
    String _formatDouble(double value) {
      return value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.track_changes_rounded, color: Colors.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.interest,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      target,
                      style: TextStyle(
                        color: hasPlan ? Colors.black87 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (perDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$perDay ${plan!.weeklyGoalUnit}/day",
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo),
                  ),
                ),
            ],
          ),
          if (goal.goal != null && goal.goal!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              goal.goal!,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            "Days: $days",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          if (progressTarget > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Progress",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF5667FF)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${_formatDouble(progressValue)} / ${_formatDouble(progressTarget)} ${plan?.weeklyGoalUnit ?? ''}".trim(),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weeklyXp(List<ProgressionDay> days) {
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxXp = days.map((d) => d.xp).fold<int>(0, max);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Last 7 days",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...days.map((day) {
            final label = labels[(day.day.weekday - 1) % labels.length];
            final progress = maxXp == 0 ? 0.0 : day.xp / maxXp;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF5667FF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "+${day.xp} XP",
                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _milestones(List<ProgressionMilestone> milestones) {
    if (milestones.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Milestones",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...milestones.map((milestone) {
          final color = milestone.achieved ? Colors.green : Colors.deepPurple;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        milestone.achieved ? Icons.celebration_rounded : Icons.flag_rounded,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            milestone.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            milestone.reward,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "${(milestone.progress * 100).clamp(0, 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: milestone.progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade700)),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
