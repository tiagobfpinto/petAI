import 'dart:math';

import 'package:flutter/material.dart';

import '../models/pet_state.dart';
import '../models/progression_snapshot.dart';
import '../services/api_service.dart';
import '../utils/number_rounding.dart';

class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({
    super.key,
    required this.apiService,
    required this.onError,
    this.onPendingRewardsChanged,
    this.onPetChanged,
  });

  final ApiService apiService;
  final void Function(String message) onError;
  final ValueChanged<int>? onPendingRewardsChanged;
  final ValueChanged<PetState>? onPetChanged;

  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

enum _CompletedGoalsRange { week, month, year }

class _ProgressionScreenState extends State<ProgressionScreen> {
  ProgressionSnapshot? _snapshot;
  bool _loading = true;
  final Set<String> _redeeming = {};
  _CompletedGoalsRange _completedGoalsRange = _CompletedGoalsRange.week;
  TabController? _tabController;
  int? _lastTabIndex;

  @override
  void initState() {
    super.initState();
    _loadProgression();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller == _tabController) return;
    _tabController?.removeListener(_handleTabChange);
    _tabController = controller;
    _lastTabIndex = controller?.index;
    _tabController?.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    final controller = _tabController;
    if (controller == null || _loading) return;
    if (controller.index == _lastTabIndex) return;
    _lastTabIndex = controller.index;
    if (controller.index == controller.length - 1) {
      _loadProgression();
    }
  }

  Future<void> _loadProgression() async {
    setState(() => _loading = true);
    final response = await widget.apiService.fetchProgression();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      final snapshot = response.data!;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      widget.onPendingRewardsChanged?.call(snapshot.pendingRewards);
    } else {
      setState(() => _loading = false);
      widget.onError(response.error ?? "Failed to load progression");
    }
  }

  String _formatReward(int xp, int coins, {String fallback = ""}) {
    final parts = <String>[];
    if (xp > 0) parts.add("+$xp XP");
    if (coins > 0) parts.add("+$coins coins");
    if (parts.isEmpty) return fallback;
    return parts.join(" ");
  }

  Future<void> _showRewardCelebration({
    required int xp,
    required int coins,
  }) async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Rewards",
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _RewardCelebrationDialog(xp: xp, coins: coins);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _redeemWeeklyGoal(ProgressionWeeklyGoal goal) async {
    final goalId = goal.goalId;
    if (goalId == null) {
      widget.onError("Missing goal id");
      return;
    }
    final key = "goal-$goalId";
    if (_redeeming.contains(key)) return;
    setState(() => _redeeming.add(key));
    final response = await widget.apiService.redeemProgressionReward(
      type: "weekly_goal",
      goalId: goalId,
    );
    if (!mounted) return;
    setState(() => _redeeming.remove(key));
    if (response.isSuccess && response.data != null) {
      final result = response.data!;
      widget.onPetChanged?.call(result.pet);
      widget.onPendingRewardsChanged?.call(result.pendingRewards);
      await _showRewardCelebration(
        xp: result.rewardXp,
        coins: result.rewardCoins,
      );
      if (!mounted) return;
      await _loadProgression();
      return;
    }
    widget.onError(response.error ?? "Failed to redeem goal");
  }

  Future<void> _redeemMilestone(ProgressionMilestone milestone) async {
    if (milestone.id.isEmpty) {
      widget.onError("Missing milestone id");
      return;
    }
    final key = "milestone-${milestone.id}";
    if (_redeeming.contains(key)) return;
    setState(() => _redeeming.add(key));
    final response = await widget.apiService.redeemProgressionReward(
      type: "milestone",
      milestoneId: milestone.id,
    );
    if (!mounted) return;
    setState(() => _redeeming.remove(key));
    if (response.isSuccess && response.data != null) {
      final result = response.data!;
      widget.onPetChanged?.call(result.pet);
      widget.onPendingRewardsChanged?.call(result.pendingRewards);
      await _showRewardCelebration(
        xp: result.rewardXp,
        coins: result.rewardCoins,
      );
      if (!mounted) return;
      await _loadProgression();
      return;
    }
    widget.onError(response.error ?? "Failed to redeem milestone");
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
          _completedGoals(_snapshot!.completedGoals),
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

  Widget _completedGoals(ProgressionCompletedGoals completedGoals) {
    final theme = Theme.of(context);
    final selections = [
      _completedGoalsRange == _CompletedGoalsRange.week,
      _completedGoalsRange == _CompletedGoalsRange.month,
      _completedGoalsRange == _CompletedGoalsRange.year,
    ];
    final entries = switch (_completedGoalsRange) {
      _CompletedGoalsRange.week => completedGoals.week,
      _CompletedGoalsRange.month => completedGoals.month,
      _CompletedGoalsRange.year => completedGoals.year,
    };
    String rangeLabel = "this week";
    if (_completedGoalsRange == _CompletedGoalsRange.month) {
      rangeLabel = "this month";
    } else if (_completedGoalsRange == _CompletedGoalsRange.year) {
      rangeLabel = "this year";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Completed goals",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = (constraints.maxWidth / 3) - 4;
            return ToggleButtons(
              isSelected: selections,
              onPressed: (index) {
                setState(() {
                  _completedGoalsRange = _CompletedGoalsRange.values[index];
                });
              },
              borderRadius: BorderRadius.circular(12),
              selectedColor: Colors.white,
              fillColor: theme.colorScheme.primary,
              color: Colors.grey.shade700,
              constraints: BoxConstraints(minWidth: buttonWidth, minHeight: 36),
              children: const [
                Text("Week"),
                Text("Month"),
                Text("Year"),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Text(
              "No goals completed $rangeLabel yet.",
              style: TextStyle(color: Colors.grey.shade700),
            ),
          )
        else
          ...entries.map(_completedGoalCard),
      ],
    );
  }

  Widget _completedGoalCard(ProgressionCompletedGoal goal) {
    final theme = Theme.of(context);
    final title = (goal.title ?? "").trim();
    final activity = (goal.activity ?? "").trim();
    final interest = goal.interest.trim();
    final header = title.isNotEmpty ? title : (activity.isNotEmpty ? activity : interest);
    final subtitleParts = <String>[];
    if (interest.isNotEmpty && interest != header) subtitleParts.add(interest);
    if (activity.isNotEmpty && activity != header && activity != interest) {
      subtitleParts.add(activity);
    }
    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(" - ");
    final amountText = _formatCompletedAmount(goal.amount, goal.unit);
    final dateText = _formatCompletedDate(goal.displayDate);

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (amountText.isNotEmpty || dateText.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amountText.isNotEmpty)
                  Text(
                    amountText,
                    style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ) ??
                        TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                  ),
                if (dateText.isNotEmpty)
                  Text(
                    dateText,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatCompletedAmount(double? amount, String? unit) {
    if (amount == null) return "";
    final formatted = amount >= 10 || amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
    final trimmed = formatted.replaceFirst(RegExp(r'\.0$'), '');
    final unitText = (unit ?? "").trim();
    return unitText.isNotEmpty ? "$trimmed $unitText" : trimmed;
  }

  String _formatCompletedDate(DateTime? date) {
    if (date == null) return "";
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "${date.year}-$month-$day";
  }

  Widget _weeklyGoalCard(ProgressionWeeklyGoal goal) {
    final plan = goal.plan;
    final hasPlan = plan != null && plan.weeklyGoalValue > 0;
    final target = hasPlan
        ? "${plan!.weeklyGoalValue.toStringAsFixed(plan.weeklyGoalValue >= 10 ? 0 : 1)} ${plan.weeklyGoalUnit}"
        : "Not set";
    final days = hasPlan && plan!.days.isNotEmpty ? plan.days.join(", ").toUpperCase() : "Flexible";
    final perDay = hasPlan && plan!.perDayGoal() > 0
        ? roundToHalf(plan.perDayGoal()).toStringAsFixed(1)
        : null;
    final progressTarget = goal.progressTarget ?? plan?.weeklyGoalValue ?? 0;
    final progressValue = goal.progressValue ?? 0;
    final progress = (goal.progress ?? (progressTarget > 0 ? progressValue / progressTarget : 0))
        .clamp(0.0, 1.0)
        .toDouble();
    final isCompleted = goal.completed || progress >= 1.0;
    final showRedeem = isCompleted && !goal.redeemed;
    final rewardText = _formatReward(goal.rewardXp, goal.rewardCoins);
    final redeemKey = goal.goalId != null ? "goal-${goal.goalId}" : null;
    final isRedeeming = redeemKey != null && _redeeming.contains(redeemKey);
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
                      (goal.goal?.isNotEmpty ?? false) ? goal.goal! : goal.interest,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (goal.goal != null && goal.goal!.isNotEmpty)
                      Text(
                        goal.interest,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Container(
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
          if (showRedeem) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Completed",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rewardText.isNotEmpty ? rewardText : "Reward ready",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (isRedeeming || goal.goalId == null)
                      ? null
                      : () => _redeemWeeklyGoal(goal),
                  child: isRedeeming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Redeem"),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _weeklyXp(List<ProgressionDay> days) {
    if (days.isEmpty) {
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
            const SizedBox(height: 8),
            Text(
              "No XP logged yet. Log a win to start your weekly history.",
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      );
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
          final rewardText = _formatReward(
            milestone.rewardXp,
            milestone.rewardCoins,
            fallback: milestone.reward,
          );
          final redeemKey = "milestone-${milestone.id}";
          final isRedeeming = _redeeming.contains(redeemKey);
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
                            rewardText,
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
                if (milestone.achieved && !milestone.redeemed) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Reward ready",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            isRedeeming ? null : () => _redeemMilestone(milestone),
                        child: isRedeeming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Redeem"),
                      ),
                    ],
                  ),
                ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCelebrationDialog extends StatelessWidget {
  const _RewardCelebrationDialog({
    required this.xp,
    required this.coins,
  });

  final int xp;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Reward claimed!",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You earned",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _RewardAmountTile(
                          label: "XP",
                          amount: xp,
                          icon: Icons.bolt_rounded,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RewardAmountTile(
                          label: "Coins",
                          amount: coins,
                          icon: Icons.monetization_on_rounded,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Tap anywhere to continue",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
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

class _RewardAmountTile extends StatelessWidget {
  const _RewardAmountTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = amount <= 0;
    final accent = isEmpty ? Colors.grey.shade400 : color;
    final border = accent.withValues(alpha: 0.35);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final offset = 12 * (1 - value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(
              scale: 0.94 + (0.06 * value),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(height: 8),
            Text(
              "+$amount",
              style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ) ??
                  TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: accent,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
