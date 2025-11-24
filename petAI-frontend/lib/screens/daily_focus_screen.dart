import 'package:flutter/material.dart';

import '../models/interest.dart';
import '../models/user_session.dart';
import '../services/guest_storage.dart';

class DailyFocusScreen extends StatefulWidget {
  const DailyFocusScreen({
    super.key,
    required this.session,
    required this.configuredInterests,
    required this.onLogout,
    this.onRefineGoals,
    this.onRequireAccount,
    this.trialDaysLeft,
  });

  final UserSession session;
  final List<SelectedInterest> configuredInterests;
  final VoidCallback onLogout;
  final VoidCallback? onRefineGoals;

  final VoidCallback? onRequireAccount;
  final int? trialDaysLeft;

  @override
  State<DailyFocusScreen> createState() => _DailyFocusScreenState();
}

class _DailyFocusScreenState extends State<DailyFocusScreen> {
  final Set<String> _completed = {};
  late List<_ActivityItem> _activities;

  @override
void initState() {
  super.initState();
  _activities = _buildActivities(widget.configuredInterests);

  // Se for guest, tentamos restaurar as completions de hoje
  if (widget.session.id == -1) {
    _restoreGuestDailyCompletion();
  }
}

    Future<void> _handleToggle(_ActivityItem activity, bool isDone) async {
      setState(() {
        if (isDone) {
          _completed.remove(activity.id);
        } else {
          _completed.add(activity.id);
        }
      });

      // Se for guest, guardar completions no storage
      if (widget.session.id == -1) {
        await GuestStorage.saveGuestDailyCompletion(_completed);
      }
    }

  @override
  void didUpdateWidget(covariant DailyFocusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuredInterests != widget.configuredInterests) {
      _activities = _buildActivities(widget.configuredInterests);
      _completed.clear();
    }
  }

      @override
    Widget build(BuildContext context) {
      final completion =
          _activities.isEmpty ? 0.0 : _completed.length / _activities.length;

      final isGuest = widget.session.id == -1;
      final daysLeft = widget.trialDaysLeft;

      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text("petAI"),
              if (isGuest && daysLeft != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    "Trial: $daysLeft day${daysLeft == 1 ? "" : "s"} left",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: "Log out",
              onPressed: widget.onLogout,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.session.id == -1 && widget.onRequireAccount != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _buildGuestBanner(context),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: _buildHeroCard(context, completion),
              ),
              Expanded(
                child: _activities.isEmpty
                    ? const Center(
                        child: Text(
                          "No activities yet. Add an interest to begin.",
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          final isDone = _completed.contains(activity.id);
                          return _ActivityTile(
                            activity: activity,
                            isDone: isDone,
                            onToggle: () {
                              _handleToggle(activity, isDone);
                            },
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemCount: _activities.length,
                      ),
              ),
              if (widget.onRefineGoals != null)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text("Adjust interests & goals"),
                      onPressed: widget.onRefineGoals,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }


      Widget _buildGuestBanner(BuildContext context) {
      final daysLeft = widget.trialDaysLeft;

      String title;
      String subtitle;

      if (daysLeft == null) {
        title = "You're in guest mode";
        subtitle =
            "Your progress is stored on this device. Create an account later to keep your pet and habits backed up.";
      } else if (daysLeft > 1) {
        title = "Trial: $daysLeft days left";
        subtitle =
            "You're in guest mode. Create an account and continue for €4.99/month before your trial ends.";
      } else if (daysLeft == 1) {
        title = "Trial: 1 day left";
        subtitle =
            "Your trial ends tomorrow. Create an account and continue for €4.99/month.";
      } else {
        title = "Trial ended";
        subtitle =
            "Your free trial has ended. Create an account and subscribe to keep using the app.";
      }

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.onRequireAccount,
              child: const Text(
                "Continue for €4.99",
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }


  Widget _buildHeroCard(BuildContext context, double completion) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.9),
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            "Hi, ${widget.session.displayName}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Here are your suggested micro-actions for today.",
            style: TextStyle(
              color:
                  Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: completion,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${(_completed.length).toString().padLeft(1)} of ${_activities.length} done",
            style: TextStyle(
              color:
                  Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  List<_ActivityItem> _buildActivities(
    List<SelectedInterest> interests,
  ) {
    final activities = <_ActivityItem>[];
    for (final interest in interests) {
      final blueprint = interest.blueprint;
      final picks = blueprint.suggestedActivities.take(3);
      for (final activity in picks) {
        activities.add(
          _ActivityItem(
            id: "${blueprint.id}-${activity.hashCode}",
            label: activity,
            interestName: blueprint.name,
            color: blueprint.accentColor,
            isGoal: false,
          ),
        );
      }
      activities.add(
        _ActivityItem(
          id: "${blueprint.id}-goal",
          label: interest.goal,
          interestName: blueprint.name,
          color: blueprint.accentColor,
          isGoal: true,
        ),
      );
    }
    return activities;
  }
      Future<void> _restoreGuestDailyCompletion() async {
      final completedIds = await GuestStorage.loadGuestDailyCompletion();
      if (!mounted) return;

      // Garantir que só marcamos IDs que ainda existem na lista de activities
      final valid = completedIds
          .where((id) => _activities.any((a) => a.id == id))
          .toSet();

      setState(() {
        _completed
          ..clear()
          ..addAll(valid);
      });
    }
}

class _ActivityItem {
  const _ActivityItem({
    required this.id,
    required this.label,
    required this.interestName,
    required this.color,
    required this.isGoal,
  });

  final String id;
  final String label;
  final String interestName;
  final Color color;
  final bool isGoal;
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.isDone,
    required this.onToggle,
  });

  final _ActivityItem activity;
  final bool isDone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isDone ? activity.color : Colors.grey.shade200,
            width: isDone ? 1.8 : 1,
          ),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: activity.color
                    .withValues(alpha: 0.16),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Icon(
                activity.isGoal
                    ? Icons.flag_rounded
                    : Icons.bolt_rounded,
                color: activity.color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.interestName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isDone,
              onChanged: (_) => onToggle(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
