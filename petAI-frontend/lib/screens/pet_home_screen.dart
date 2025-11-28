import 'package:flutter/material.dart';

import '../models/activity_log.dart';
import '../models/interest.dart';
import '../models/pet_state.dart';
import '../models/user_interest.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';
import '../widgets/pet_sprite.dart';
import '../widgets/xp_progress_bar.dart';
import 'friends_screen.dart';
import 'progression_screen.dart';
import 'shop_screen.dart';

class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({
    super.key,
    required this.apiService,
    required this.session,
    required this.pet,
    required this.interests,
    required this.onLogout,
    required this.onManageAccount,
    required this.onPetChanged,
    required this.onRefreshInterests,
    required this.onEditInterests,
    required this.onError,
    this.isSyncing = false,
  });

  final ApiService apiService;
  final UserSession session;
  final PetState pet;
  final List<UserInterest> interests;
  final bool isSyncing;

  final VoidCallback onLogout;
  final VoidCallback onManageAccount;
  final ValueChanged<PetState> onPetChanged;
  final Future<void> Function() onRefreshInterests;
  final VoidCallback onEditInterests;
  final void Function(String message) onError;

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  late PetState _pet;
  late List<UserInterest> _interests;
  final Map<String, bool> _logging = {};
  List<ActivityLogEntry> _activities = [];
  bool _loadingActivities = true;
  Set<int> _completedToday = {};
  final Map<int, int> _celebrations = {};
  int? _streakCurrent;
  int? _streakBest;
  double? _xpMultiplier;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _interests = widget.interests;
    _streakCurrent = widget.session.streakCurrent;
    _streakBest = widget.session.streakBest;
    _xpMultiplier = widget.session.streakMultiplier;
    _loadActivities();
  }

  @override
  void didUpdateWidget(covariant PetHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet != widget.pet) {
      _pet = widget.pet;
    }
    if (oldWidget.interests != widget.interests) {
      _interests = widget.interests;
    }
    if (oldWidget.session != widget.session) {
      _streakCurrent = widget.session.streakCurrent;
      _streakBest = widget.session.streakBest;
      _xpMultiplier = widget.session.streakMultiplier;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Hi, ${widget.session.displayName}"),
          actions: [
            IconButton(
              tooltip: "Adjust interests",
              onPressed: widget.onEditInterests,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: "Account",
              onPressed: widget.onManageAccount,
              icon: const Icon(Icons.person_rounded),
            ),
            IconButton(
              tooltip: "Log out",
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: widget.isSyncing
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: SafeArea(
          child: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildHomeTab(context),
              ShopScreen(
                apiService: widget.apiService,
                onError: widget.onError,
              ),
              FriendsScreen(
                apiService: widget.apiService,
                onError: widget.onError,
              ),
              ProgressionScreen(
                apiService: widget.apiService,
                onError: widget.onError,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildNavBar(context),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TabBar(
        isScrollable: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        tabs: const [
          Tab(icon: Icon(Icons.pets_rounded), text: "Home"),
          Tab(icon: Icon(Icons.store_mall_directory_rounded), text: "Shop"),
          Tab(icon: Icon(Icons.people_alt_rounded), text: "Friends"),
          Tab(icon: Icon(Icons.auto_graph_rounded), text: "Progression"),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          if (widget.session.isGuest) ...[
            _buildGuestBanner(context),
            const SizedBox(height: 16),
          ],
          _buildStreakCard(context),
          const SizedBox(height: 16),
          _buildPetHeader(context),
          const SizedBox(height: 24),
          _buildInterestsSection(),
          const SizedBox(height: 24),
          _buildActivityLog(),
        ],
      ),
    );
  }

  Widget _buildPetHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.9),
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: PetSprite(stage: _pet.stage, mood: _pet.level),
          ),
          const SizedBox(height: 12),
          Text(
            _pet.stage.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            "Level ${_pet.level}",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          XpProgressBar(
            progress: _pet.progressToNext,
            xp: _pet.xp,
            nextXp: _pet.nextEvolutionXp,
          ),
          const SizedBox(height: 12),
          Text(
            "Log quick wins to help your buddy evolve.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection() {
    if (_interests.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("No interests yet"),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text("Add at least one interest to begin."),
              trailing: ElevatedButton(
                onPressed: widget.onEditInterests,
                child: const Text("Add now"),
              ),
            ),
          ),
        ],
      );
    }

    final visibleInterests = _interests.where((interest) {
      final id = interest.id;
      if (id == null) {
        return true;
      }
      final celebrating = _celebrations.containsKey(id);
      final completed = _completedToday.contains(id);
      return !completed || celebrating;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Today's focus"),
        const SizedBox(height: 12),
        if (visibleInterests.isEmpty)
          _allCaughtUpCard()
        else
          ...visibleInterests.map(_buildInterestCard),
      ],
    );
  }

  Widget _buildInterestCard(UserInterest interest) {
    final blueprint = interest.blueprint;
    final isLoading = _logging[interest.name] ?? false;
    final quickIdeas = blueprint.suggestedActivities.take(2).toList();
    final goalText = (interest.goal ?? "").trim();
    final interestId = interest.id;
    final celebrationXp =
        interestId != null ? _celebrations[interestId] : null;
    final isCompleted = interestId != null && _completedToday.contains(interestId);

    if (isCompleted && celebrationXp == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: blueprint.accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    blueprint.icon,
                    color: blueprint.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blueprint.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${interest.level.label} • ${goalText.isEmpty ? "No goal yet" : goalText}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onEditInterests,
                  child: const Text("Edit"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: quickIdeas
                  .map(
                    (idea) => Chip(
                      label: Text(idea),
                      backgroundColor:
                          blueprint.accentColor.withValues(alpha: 0.12),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: celebrationXp != null
                  ? _XpCelebration(
                      key: ValueKey("celebrating-${interestId ?? interest.name}"),
                      xp: celebrationXp,
                    )
                  : SizedBox(
                      key: ValueKey("cta-${interestId ?? interest.name}"),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.bolt_rounded),
                        label: Text(isLoading ? "Logging..." : "Log a win"),
                        onPressed: (isLoading || isCompleted)
                            ? null
                            : () => _completeActivity(interest),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Set<int> _extractCompletedInterestIds(List<ActivityLogEntry> logs) {
    final ids = <int>{};
    for (final log in logs) {
      if (log.interestId > 0) {
        ids.add(log.interestId);
      }
    }
    ids.addAll(_celebrations.keys);
    return ids;
  }

  void _startCelebration(int? interestId, int xpAwarded) {
    if (interestId == null) return;
    setState(() {
      _celebrations[interestId] = xpAwarded;
      _completedToday.add(interestId);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _celebrations.remove(interestId);
      });
    });
  }

  Widget _buildActivityLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Today's activity"),
        const SizedBox(height: 12),
        if (_loadingActivities)
          const Center(child: CircularProgressIndicator())
        else if (_activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.shade100,
            ),
            child: const Text("No activity yet today."),
          )
        else
          ..._activities.map((log) {
            final interestName =
                _interests.firstWhere(
                  (interest) => interest.id == log.interestId,
                  orElse: () => _fallbackInterest(log.interestId),
                ).blueprint.name;
            final time = log.timestamp != null
                ? TimeOfDay.fromDateTime(log.timestamp!)
                : null;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text("$interestName • +${log.xpEarned} XP"),
              subtitle: time == null ? null : Text(time.format(context)),
            );
          }),
      ],
    );
  }

  Widget _allCaughtUpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.green.shade50,
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_rounded, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "All tasks completed for today! Come back tomorrow for more XP.",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadActivities(),
      widget.onRefreshInterests(),
      _refreshPetState(),
    ]);
  }

  Future<void> _loadActivities() async {
    setState(() => _loadingActivities = true);
    final response = await widget.apiService.fetchTodayActivities();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _activities = response.data!;
        _completedToday = _extractCompletedInterestIds(response.data!);
        _loadingActivities = false;
      });
    } else {
      setState(() => _loadingActivities = false);
      widget.onError(response.error ?? "Failed to load activity log");
    }
  }

  Future<void> _refreshPetState() async {
    final response = await widget.apiService.fetchPet();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      widget.onPetChanged(response.data!);
    } else {
      widget.onError(response.error ?? "Failed to refresh pet");
    }
  }

  Future<void> _completeActivity(UserInterest interest) async {
    setState(() => _logging[interest.name] = true);
    final response =
        await widget.apiService.completeActivity(interest.name);
    if (!mounted) return;
    setState(() => _logging[interest.name] = false);
    if (response.isSuccess && response.data != null) {
      final completion = response.data!;
      widget.onPetChanged(completion.pet);
      setState(() {
        _streakCurrent = completion.streakCurrent ?? _streakCurrent;
        _streakBest = completion.streakBest ?? _streakBest;
        _xpMultiplier = completion.xpMultiplier ?? _xpMultiplier;
      });
      _startCelebration(completion.interestId, completion.xpAwarded);
      _loadActivities();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Great job! ${interest.name} earned +${completion.xpAwarded} XP.",
          ),
        ),
      );
    } else {
      if (response.statusCode == 403) {
        _showUpgradeDialog();
      } else {
        widget.onError(response.error ?? "Failed to log activity");
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Trial ended"),
        content: const Text(
          "Your free trial streak has ended. Create an account to keep earning XP and evolve your pet.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Later"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onManageAccount();
            },
            child: const Text("Upgrade"),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildGuestBanner(BuildContext context) {
    final daysLeft = _trialDaysLeft(widget.session);
    final bannerText =
        daysLeft != null ? "$daysLeft day${daysLeft == 1 ? "" : "s"} left" : "Free trial active";
    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_open_rounded, color: Colors.amber.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Guest mode",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bannerText,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: widget.onManageAccount,
              child: const Text("Create account"),
            ),
          ],
        ),
      ),
    );
  }

  int? _trialDaysLeft(UserSession session) {
    final fromBackend = session.trialDaysLeft;
    if (fromBackend != null) {
      return fromBackend;
    }
    const trialLengthDays = 3;
    final createdAt = session.createdAt;
    if (createdAt == null) return null;
    final elapsed = DateTime.now().difference(createdAt).inDays;
    final remaining = trialLengthDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  Widget _buildStreakCard(BuildContext context) {
    final theme = Theme.of(context);
    final streak = _streakCurrent ?? widget.session.streakCurrent ?? 0;
    final best = _streakBest ?? widget.session.streakBest ?? streak;
    final multiplier = _xpMultiplier ?? widget.session.streakMultiplier ?? 1.0;
    final capped = streak.clamp(0, 10);
    final progress = (capped / 10).clamp(0.0, 1.0);
    final daysLabel = "$streak day${streak == 1 ? "" : "s"} streak";
    final bestLabel = "Best: $best";

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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department_rounded, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    daysLabel,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    "XP multiplier ${multiplier.toStringAsFixed(2)}x",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bestLabel,
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Reach 10 days for a 2x XP boost. Don't break the chain!",
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  UserInterest _fallbackInterest(int id) {
    return UserInterest(
      id: id,
      name: "Interest",
      level: MotivationLevel.sometimes,
      goal: "",
    );
  }
}

class _XpCelebration extends StatelessWidget {
  const _XpCelebration({super.key, required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final opacity = (value - 0.7).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              "+$xp XP",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Great job!",
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
