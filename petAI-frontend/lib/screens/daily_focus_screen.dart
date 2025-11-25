import 'dart:async';

import 'package:flutter/material.dart';

import '../models/interest.dart';
import '../models/pet.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';
import '../services/guest_storage.dart';

class DailyFocusScreen extends StatefulWidget {
  const DailyFocusScreen({
    super.key,
    required this.session,
    required this.apiService,
    required this.configuredInterests,
    required this.onLogout,
    this.onRefineGoals,
    this.onRequireAccount,
    this.trialDaysLeft,
  });

  final UserSession session;
  final ApiService apiService;
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
  final Set<String> _removing = {};

  late List<_ActivityItem> _allActivities;
  late List<_ActivityItem> _visibleActivities;

  int _streak = 0;

  PetState _pet = const PetState(level: 1, xp: 0, nextLevelXp: 80);

  static const int _xpPerActivity = 25;

  String? _xpToast;
  Timer? _xpToastTimer;

  static const List<_PetLook> _petLooks = [
    _PetLook(
      name: "Sprout",
      gradient: [Color(0xFFfdf3ff), Color(0xFFd9e5ff)],
      accent: Color(0xFF8b5cf6),
      cheek: Color(0xFFf9a8d4),
      accessory: Icons.energy_savings_leaf_rounded,
    ),
    _PetLook(
      name: "Explorer",
      gradient: [Color(0xFFe8fff7), Color(0xFFc8e7ff)],
      accent: Color(0xFF10b981),
      cheek: Color(0xFFfcd34d),
      accessory: Icons.emoji_nature_rounded,
    ),
    _PetLook(
      name: "Champion",
      gradient: [Color(0xFFfff0f0), Color(0xFFffe7c2)],
      accent: Color(0xFFf97316),
      cheek: Color(0xFFfb7185),
      accessory: Icons.star_rate_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _resetActivities(widget.configuredInterests);
    _loadPet();
    _loadGuestDailyStateIfNeeded();
  }

  @override
  void dispose() {
    _xpToastTimer?.cancel();
    super.dispose();
  }

  void _resetActivities(List<SelectedInterest> interests) {
    _allActivities = _buildActivities(interests);
    _visibleActivities = List<_ActivityItem>.from(_allActivities);
    _completed.clear();
    _removing.clear();
  }

  Future<void> _loadPet() async {
    if (widget.session.id == -1) {
      final progress = await GuestStorage.loadPetProgress();
      if (!mounted) return;
      setState(() => _pet = progress);
      return;
    }

    final response = await widget.apiService.fetchPet();
    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      setState(() => _pet = response.data!);
    }
  }

  Future<void> _loadGuestDailyStateIfNeeded() async {
    if (widget.session.id != -1) return;

    final completed = await GuestStorage.loadGuestDailyCompletion();
    final streak = await GuestStorage.loadGuestStreak();
    final validCompleted = completed
        .where((id) => _visibleActivities.any((activity) => activity.id == id))
        .toSet();

    if (!mounted) return;
    setState(() {
      _completed
        ..clear()
        ..addAll(validCompleted);
      _streak = streak;
      _visibleActivities.removeWhere(
        (activity) => _completed.contains(activity.id),
      );
    });
  }

  @override
  void didUpdateWidget(covariant DailyFocusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      _pet = const PetState(level: 1, xp: 0, nextLevelXp: 80);
      _loadPet();
    }

    if (oldWidget.configuredInterests != widget.configuredInterests) {
      _resetActivities(widget.configuredInterests);
      _loadGuestDailyStateIfNeeded();
    }
  }

  int _xpNeededForLevel(int level) {
    return 80 + (level - 1) * 40;
  }

  Future<void> _completeActivity(_ActivityItem activity) async {
    if (_completed.contains(activity.id) || _removing.contains(activity.id)) {
      return;
    }

    setState(() {
      _completed.add(activity.id);
      _removing.add(activity.id);
    });

    _showXpToast("+$_xpPerActivity XP");

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    setState(() {
      _visibleActivities.removeWhere((item) => item.id == activity.id);
      _removing.remove(activity.id);
    });

    await _addXp(_xpPerActivity);

    if (widget.session.id == -1) {
      await GuestStorage.saveGuestDailyCompletion(_completed);
      final streak = await GuestStorage.loadGuestStreak();

      if (mounted) {
        setState(() {
          _streak = streak;
        });
      }
    }
  }

  Future<void> _addXp(int amount) async {
    final isGuest = widget.session.id == -1;

    if (!isGuest) {
      final response = await widget.apiService.addPetXp(amount);
      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        setState(() => _pet = response.data!);
        return;
      }
      // fall through to optimistic local update if API fails
    }

    int level = _pet.level;
    int xp = _pet.xp + amount;
    int nextXp = _pet.nextLevelXp;

    while (xp >= nextXp) {
      xp -= nextXp;
      level += 1;
      nextXp = _xpNeededForLevel(level);
    }

    final pet = PetState(level: level, xp: xp, nextLevelXp: nextXp);

    if (!mounted) return;
    setState(() => _pet = pet);

    if (isGuest) {
      await GuestStorage.savePetProgress(pet: pet);
    }
  }

  void _showXpToast(String text) {
    _xpToastTimer?.cancel();
    setState(() {
      _xpToast = text;
    });
    _xpToastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _xpToast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
        child: Stack(
          children: [
            Column(
              children: [
                if (isGuest && widget.onRequireAccount != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: _buildGuestBanner(context),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: _buildHeroCard(context),
                ),
                Expanded(
                  child: _visibleActivities.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemBuilder: (context, index) {
                            final activity = _visibleActivities[index];
                            final isRemoving = _removing.contains(activity.id);
                            return _ActivityTile(
                              activity: activity,
                              isRemoving: isRemoving,
                              onComplete: () => _completeActivity(activity),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemCount: _visibleActivities.length,
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
            _XpToastBanner(message: _xpToast),
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
          "You're in guest mode. Create an account and continue for 4.99/month before your trial ends.";
    } else if (daysLeft == 1) {
      title = "Trial: 1 day left";
      subtitle =
          "Your trial ends tomorrow. Create an account and continue for 4.99/month.";
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
          const Icon(Icons.info_outline_rounded, size: 20),
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
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.onRequireAccount,
            child: const Text("Continue", style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final petLook = _petLooks[(_pet.level - 1) % _petLooks.length];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.95),
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PetAvatar(
              look: petLook,
              switchKey: "pet-${_pet.level}-${petLook.name}",
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: Text(
                "Level ${_pet.level}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            if (widget.session.id == -1 && _streak > 0) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Streak: $_streak",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Tudo pronto por hoje!",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            "O seu pet ja ganhou o XP de todas as tasks.",
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  List<_ActivityItem> _buildActivities(List<SelectedInterest> interests) {
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
    required this.onComplete,
    required this.isRemoving,
  });

  final _ActivityItem activity;
  final VoidCallback onComplete;
  final bool isRemoving;

  @override
  Widget build(BuildContext context) {
    final slideOffset = isRemoving ? const Offset(0.05, -0.05) : Offset.zero;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isRemoving ? 0 : 1,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: slideOffset,
          child: InkWell(
            onTap: isRemoving ? null : onComplete,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: activity.color, width: 1.4),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: activity.color.withOpacity(0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: activity.color.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      activity.isGoal ? Icons.flag_rounded : Icons.bolt_rounded,
                      color: activity.color,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.check_circle_outline_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.look, required this.switchKey});

  final _PetLook look;
  final String switchKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        );
      },
      child: _buildPetFace(look, key: ValueKey(switchKey)),
    );
  }

  Widget _buildPetFace(_PetLook look, {required Key key}) {
    return Container(
      key: key,
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: look.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: look.accent.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -10, left: 22, child: _ear(look.accent, flip: false)),
          Positioned(top: -10, right: 22, child: _ear(look.accent, flip: true)),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.86),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Positioned(left: 28, top: 38, child: _eye()),
                  Positioned(right: 28, top: 38, child: _eye()),
                  Align(
                    alignment: const Alignment(0, 0.1),
                    child: Container(
                      width: 30,
                      height: 22,
                      decoration: BoxDecoration(
                        color: look.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(left: 22, bottom: 18, child: _cheek(look.cheek)),
                  Positioned(right: 22, bottom: 18, child: _cheek(look.cheek)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Icon(look.accessory, size: 26, color: look.accent),
          ),
        ],
      ),
    );
  }

  Widget _ear(Color color, {required bool flip}) {
    return Transform.rotate(
      angle: flip ? -0.35 : 0.35,
      child: Container(
        width: 42,
        height: 54,
        decoration: BoxDecoration(
          color: color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _eye() {
    return Container(
      width: 12,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _cheek(Color color) {
    return Container(
      width: 18,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _PetLook {
  const _PetLook({
    required this.name,
    required this.gradient,
    required this.accent,
    required this.cheek,
    required this.accessory,
  });

  final String name;
  final List<Color> gradient;
  final Color accent;
  final Color cheek;
  final IconData accessory;
}

class _XpToastBanner extends StatelessWidget {
  const _XpToastBanner({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.15),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: message == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(message),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}
