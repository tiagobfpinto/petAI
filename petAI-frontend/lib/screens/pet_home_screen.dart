import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/activity_log.dart';
import '../models/daily_activity.dart';
import '../models/interest.dart';
import '../models/activity_type.dart';
import '../models/pet_state.dart';
import '../models/user_interest.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';
import '../widgets/xp_progress_bar.dart';
import 'coin_store_screen.dart';
import 'friends_screen.dart';
import 'progression_screen.dart';
import 'shop_screen.dart';
import 'styles_sheet.dart';
import 'package:rive/rive.dart' as rive;

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
  static const String _petRiveAssetPath = "assets/rive/pet_home.riv";
  late PetState _pet;
  late List<UserInterest> _interests;
  rive.RiveWidgetController? _petRiveController;
  rive.ViewModelInstance? _petRiveViewModel;
  rive.RiveWidgetController? _petRiveViewModelController;
  final Map<String, bool> _logging = {};
  List<DailyActivity> _dailyActivities = [];
  bool _loadingDaily = true;
  bool _hadDailyToday = false;
  List<ActivityType> _activityTypes = [];
  bool _loadingActivityTypes = false;
  List<ActivityLogEntry> _activities = [];
  bool _loadingActivities = true;
  Set<int> _completedToday = {};
  final Map<int, int> _celebrations = {};
  int? _streakCurrent;
  int? _streakBest;
  double? _xpMultiplier;
  List<String> _equippedStyleTriggers = const [];
  bool _loadingEquippedStyleTriggers = false;
  rive.RiveWidgetController? _equippedStyleControllerAppliedTo;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _interests = widget.interests;
    _streakCurrent = widget.session.streakCurrent;
    _streakBest = widget.session.streakBest;
    _xpMultiplier = widget.session.streakMultiplier;
    _loadDailyActivities();
    _loadActivities();
    _loadActivityTypes();
    _loadEquippedStyleTriggers();
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
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Hi, ${widget.session.displayName}"),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _openCoinStore,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.monetization_on_outlined,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_pet.coins}",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                pet: _pet,
                onBalanceChanged: (balance) {
                  setState(() {
                    _pet = _pet.copyWith(coins: balance);
                  });
                  widget.onPetChanged(_pet);
                },
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
          const SizedBox(height: 16),
          _buildCreateActivityButton(context),
          const SizedBox(height: 8),
          _buildLogoutButton(context),
          const SizedBox(height: 16),
          _buildDailyActivitiesSection(),
          const SizedBox(height: 24),
          _buildActivityLog(),
        ],
      ),
    );
  }

  Widget _buildCreateActivityButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add new activity"),
        onPressed: _openAddActivityOverlay,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        icon: const Icon(Icons.logout_rounded),
        label: const Text("Log out"),
        onPressed: widget.onLogout,
      ),
    );
  }

  Widget _buildDailyActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Today's focus"),
        _buildDailyCelebration(),
        if (_celebrations.isNotEmpty) const SizedBox(height: 8),
        const SizedBox(height: 12),
        if (_loadingDaily)
          const Center(child: CircularProgressIndicator())
        else if (_dailyActivities.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.shade100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hadDailyToday ? "All daily tasks done." : "No tasks scheduled today.",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _hadDailyToday
                      ? "Your pet is celebrating. Queue a quick win while the streak is hot."
                      : "Add a new activity to focus on today.",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _openAddActivityOverlay,
                  child: const Text("Add activity"),
                ),
              ],
            ),
          )
        else
          ..._dailyActivities.map(_buildDailyActivityCard),
      ],
    );
  }

  Future<void> _loadDailyActivities() async {
    setState(() => _loadingDaily = true);
    final response = await widget.apiService.fetchDailyActivities();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      final daily = response.data!;
      final pending = daily.where((a) => !a.isCompleted).toList();
      setState(() {
        _dailyActivities = pending;
        _hadDailyToday = _hadDailyToday || daily.isNotEmpty;
        _loadingDaily = false;
      });
    } else {
      setState(() => _loadingDaily = false);
      widget.onError(response.error ?? "Failed to load daily activities");
    }
  }

  Future<void> _loadActivityTypes() async {
    setState(() => _loadingActivityTypes = true);
    final response = await widget.apiService.fetchActivityTypes();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _activityTypes = response.data!;
        _loadingActivityTypes = false;
      });
    } else {
      setState(() => _loadingActivityTypes = false);
      widget.onError(response.error ?? "Failed to load activity types");
    }
  }

  Future<void> _openAddActivityOverlay() async {
    if (_activityTypes.isEmpty && !_loadingActivityTypes) {
      await _loadActivityTypes();
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<_ActivityPickerResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ActivityTypePickerSheet(
        activityTypes: _activityTypes,
        isLoading: _loadingActivityTypes,
      ),
    );
    if (result == null) return;
    if (result.createNew) {
      await _openNewActivityForm();
    } else if (result.type != null) {
      await _startActivityFromType(result.type!);
    }
  }

  Future<void> _openNewActivityForm() async {
    final result = await Navigator.of(context).push<_ActivityFormResult>(
      MaterialPageRoute(
        builder: (_) => _NewActivityScreen(
          interests: _interests,
        ),
      ),
    );
    if (result == null || result.deleted) return;
    final data = result.data;
    if (data == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saving activity...")),
    );
    final response = await widget.apiService.createActivity(
      name: data.name,
      area: data.areaName,
      weeklyGoalValue: data.weeklyGoalValue,
      weeklyGoalUnit: data.weeklyGoalUnit,
      days: data.days,
      rrule: data.rrule,
    );
    if (!mounted) return;
    if (response.isSuccess) {
      final weeklyText = data.weeklyGoalValue != null
          ? "Weekly goal: ${data.weeklyGoalValue} ${data.weeklyGoalUnit} on ${data.days.isEmpty ? "flex days" : data.days.join(", ").toUpperCase()}"
          : "No weekly goal set";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Created \"${data.name}\" for ${data.areaName}. $weeklyText",
          ),
        ),
      );
      await _loadDailyActivities();
      await _loadActivities();
      await _loadActivityTypes();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? "Failed to create activity"),
        ),
      );
    }
  }

  Future<void> _openEditDailyActivity(DailyActivity activity) async {
    ActivityType? type;
    try {
      type = _activityTypes.firstWhere((t) => t.id == activity.activityTypeId);
    } catch (_) {
      type = null;
    }
    if (type == null) {
      await _loadActivityTypes();
      try {
        type = _activityTypes.firstWhere((t) => t.id == activity.activityTypeId);
      } catch (_) {
        type = null;
      }
    }
    if (type == null) {
      widget.onError("Could not load activity details to edit");
      return;
    }

    final result = await Navigator.of(context).push<_ActivityFormResult>(
      MaterialPageRoute(
        builder: (_) => _NewActivityScreen(
          interests: _interests,
          initialType: type,
          allowDelete: true,
        ),
      ),
    );
    if (result == null) return;
    if (result.deleted) {
      await _deleteActivityType(type.id);
      return;
    }
    final data = result.data;
    if (data == null) return;
    await _updateActivityType(type.id, data);
  }

  Future<void> _startActivityFromType(ActivityType type) async {
    final plan = type.plan;
    final planDays = plan?.days ?? [];
    final weeklyGoalValue =
        plan != null && plan.weeklyGoalValue > 0 ? plan.weeklyGoalValue : null;
    final weeklyGoalUnit =
        plan != null && plan.weeklyGoalUnit.isNotEmpty ? plan.weeklyGoalUnit : null;
    final areaName = type.areaName.isNotEmpty ? type.areaName : type.name;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Adding ${type.name}...")),
    );

    final response = await widget.apiService.createActivity(
      name: type.name,
      area: areaName,
      weeklyGoalValue: weeklyGoalValue,
      weeklyGoalUnit: weeklyGoalUnit,
      days: planDays.isEmpty ? null : planDays,
      rrule: type.rrule,
    );
    if (!mounted) return;
    if (response.isSuccess) {
      final goalText = weeklyGoalValue != null
          ? " • weekly ${weeklyGoalValue.toString()} ${weeklyGoalUnit ?? ""}".trim()
          : "";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Added \"${type.name}\"${areaName != type.name ? " in $areaName" : ""}$goalText",
          ),
        ),
      );
      await _loadDailyActivities();
      await _loadActivities();
    } else {
      widget.onError(response.error ?? "Failed to add activity");
    }
  }

  Future<void> _updateActivityType(int activityTypeId, _NewActivityData data) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Updating activity...")),
    );
    final response = await widget.apiService.updateActivityType(
      activityTypeId: activityTypeId,
      name: data.name,
      area: data.areaName,
      weeklyGoalValue: data.weeklyGoalValue,
      weeklyGoalUnit: data.weeklyGoalUnit,
      days: data.days,
      rrule: data.rrule,
    );
    if (!mounted) return;
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Updated \"${data.name}\"")),
      );
      await _loadDailyActivities();
      await _loadActivities();
      await _loadActivityTypes();
    } else {
      widget.onError(response.error ?? "Failed to update activity");
    }
  }

  Future<void> _deleteActivityType(int activityTypeId) async {
    final response = await widget.apiService.deleteActivityType(activityTypeId);
    if (!mounted) return;
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Activity deleted")),
      );
      await _loadDailyActivities();
      await _loadActivities();
      await _loadActivityTypes();
    } else {
      widget.onError(response.error ?? "Failed to delete activity");
    }
  }

  Widget _buildPetHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
            final size = min(maxWidth, 260.0);
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _PetRiveAnimation(
                        assetPath: _petRiveAssetPath,
                        fallback: ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        ),
                        onControllerReady: (controller) {
                          _petRiveController = controller;
                          _maybeBindPetViewModel(controller);
                          _applyEquippedStyleTriggersIfReady();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          _pet.stage.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 1.2,
          ),
        ),
        Text(
          "Level ${_pet.level}",
          style: theme.textTheme.headlineSmall?.copyWith(
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
        OutlinedButton.icon(
          onPressed: _openStylesMenu,
          icon: const Icon(Icons.checkroom_rounded),
          label: const Text("Styles"),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Log quick wins to help your buddy evolve.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Future<void> _openStylesMenu() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StylesSheet(
        apiService: widget.apiService,
        onError: widget.onError,
        onTrigger: (trigger) {
          _firePetTrigger(trigger);
        },
      ),
    );
  }

  Future<void> _loadEquippedStyleTriggers() async {
    if (_loadingEquippedStyleTriggers) return;
    _loadingEquippedStyleTriggers = true;
    final response = await widget.apiService.fetchEquippedStyleTriggers();
    _loadingEquippedStyleTriggers = false;
    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      _equippedStyleTriggers = response.data!;
      _applyEquippedStyleTriggersIfReady();
      return;
    }

    if (kDebugMode) {
      debugPrint(
        "[style] Failed to load equipped style triggers: ${response.error ?? 'unknown error'}",
      );
    }
  }

  void _applyEquippedStyleTriggersIfReady() {
    final controller = _petRiveController;
    if (controller == null) return;
    if (_equippedStyleTriggers.isEmpty) return;
    if (_equippedStyleControllerAppliedTo == controller) return;

    for (final trigger in _equippedStyleTriggers) {
      _firePetTrigger(trigger, showErrors: false);
    }
    _equippedStyleControllerAppliedTo = controller;
  }

  void _maybeBindPetViewModel(rive.RiveWidgetController controller) {
    if (_petRiveViewModelController == controller) return;
    _petRiveViewModelController = controller;
    _petRiveViewModel = null;

    try {
      _petRiveViewModel = controller.dataBind(const rive.AutoBind());
      if (kDebugMode) {
        debugPrint(
          "[pet_rive] bound view model: ${_petRiveViewModel?.name} (sm=${controller.stateMachine.name})",
        );
      }
    } catch (err) {
      if (kDebugMode) {
        debugPrint("[pet_rive] no view model binding (sm=${controller.stateMachine.name}): $err");
      }
    }
  }

  static String _normalizeRiveName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]"), "");
  }

  static List<String> _triggerNameCandidates(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>[trimmed];

    final hatAbbrev = RegExp(r"^h[_-]?(\d+)$", caseSensitive: false).firstMatch(trimmed);
    if (hatAbbrev != null) {
      candidates.add("hat_${hatAbbrev.group(1)}");
    }

    final hatFull = RegExp(r"^hat[_-]?(\d+)$", caseSensitive: false).firstMatch(trimmed);
    if (hatFull != null) {
      final id = hatFull.group(1);
      if (id != null) {
        candidates.add("hat_$id");
        candidates.add("h_$id");
      }
    }

    final unique = <String>[];
    for (final candidate in candidates) {
      if (unique.contains(candidate)) continue;
      unique.add(candidate);
    }
    return unique;
  }

  static String _describeRiveInputs(rive.StateMachine stateMachine) {
    final triggers = <String>[];
    final booleans = <String>[];
    final numbers = <String>[];

    // ignore: deprecated_member_use
    for (final input in stateMachine.inputs) {
      if (input is rive.TriggerInput) {
        triggers.add(input.name);
      } else if (input is rive.BooleanInput) {
        booleans.add(input.name);
      } else if (input is rive.NumberInput) {
        numbers.add(input.name);
      }
    }

    final parts = <String>[];
    if (triggers.isNotEmpty) parts.add("triggers=[${triggers.join(", ")}]");
    if (booleans.isNotEmpty) parts.add("booleans=[${booleans.join(", ")}]");
    if (numbers.isNotEmpty) parts.add("numbers=[${numbers.join(", ")}]");
    return parts.isEmpty ? "inputs=[]" : parts.join(" ");
  }

  void _firePetTrigger(String triggerName, {bool showErrors = true}) {
    final controller = _petRiveController;
    final originalName = triggerName.trim();
    if (originalName.isEmpty) return;
    if (controller == null) {
      if (showErrors) {
        widget.onError("Pet animation not ready yet");
      } else if (kDebugMode) {
        debugPrint("[pet_rive] trigger ignored (animation not ready): $originalName");
      }
      return;
    }

    final stateMachine = controller.stateMachine;

    bool tryFire(String name) {
      // 1) Try state machine trigger input (legacy inputs).
      // ignore: deprecated_member_use
      final direct = stateMachine.trigger(name);
      if (direct != null) {
        direct.fire();
        return true;
      }

      // 2) Try normalized match across inputs (handles case/underscore differences).
      final normalized = _normalizeRiveName(name);
      rive.Input? matched;
      // ignore: deprecated_member_use
      for (final input in stateMachine.inputs) {
        if (_normalizeRiveName(input.name) == normalized) {
          matched = input;
          break;
        }
      }

      if (matched is rive.TriggerInput) {
        matched.fire();
        return true;
      }

      // Some files use booleans/numbers as pseudo-triggers. Pulse them.
      if (matched is rive.BooleanInput) {
        final input = matched;
        input.value = true;
        Future.delayed(const Duration(milliseconds: 60), () {
          if (_petRiveController == controller) {
            input.value = false;
          }
        });
        return true;
      }

      if (matched is rive.NumberInput) {
        final input = matched;
        input.value = 1;
        Future.delayed(const Duration(milliseconds: 60), () {
          if (_petRiveController == controller) {
            input.value = 0;
          }
        });
        return true;
      }

      // 3) Try data-binding triggers (new Rive workflow).
      _maybeBindPetViewModel(controller);
      final viewModel = stateMachine.boundRuntimeViewModelInstance ?? _petRiveViewModel;
      if (viewModel != null) {
        final vmTrigger = viewModel.trigger(name);
        if (vmTrigger != null) {
          vmTrigger.trigger();
          return true;
        }

        final normalizedVm = _normalizeRiveName(name);
        for (final property in viewModel.properties) {
          if (property.type != rive.DataType.trigger) continue;
          if (_normalizeRiveName(property.name) == normalizedVm) {
            viewModel.trigger(property.name)?.trigger();
            return true;
          }
        }
      }

      return false;
    }

    for (final candidate in _triggerNameCandidates(originalName)) {
      if (!tryFire(candidate)) continue;
      if (kDebugMode && candidate != originalName) {
        debugPrint(
          "[pet_rive] Aliased trigger \"$originalName\" -> \"$candidate\" (sm=${stateMachine.name})",
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        "[pet_rive] Unknown input \"$originalName\" on state machine \"${stateMachine.name}\" (${_describeRiveInputs(stateMachine)})",
      );
    }

    if (showErrors) {
      widget.onError('Unknown pet trigger: $originalName (sm="${stateMachine.name}")');
    }
  }

  int _baseXpForLevel(MotivationLevel level) {
    switch (level) {
      case MotivationLevel.never:
        return 20;
      case MotivationLevel.sometimes:
        return 15;
      case MotivationLevel.usually:
        return 10;
      case MotivationLevel.always:
        return 5;
    }
  }

  double _currentXpMultiplier() {
    final multiplier = _xpMultiplier ?? widget.session.streakMultiplier ?? 1.0;
    if (multiplier <= 0) return 1.0;
    return multiplier;
  }

  double? _suggestedAmount(UserInterest interest) {
    final plan = interest.plan;
    if (plan == null) return null;
    final perDay = plan.perDayGoalValue ?? plan.perDayGoal();
    if (perDay > 0) return perDay;
    return null;
  }

  String _goalUnit(UserInterest interest, {DailyActivity? activity}) {
    final fromActivity = (activity?.goalUnit ?? "").trim();
    if (fromActivity.isNotEmpty) return fromActivity;
    final unit = (interest.plan?.weeklyGoalUnit ?? "").trim();
    return unit.isNotEmpty ? unit : "units";
  }

  String _formatAmount(double value) {
    if (value >= 10) return value.toStringAsFixed(0);
    if ((value * 10).roundToDouble() == value * 10) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  int? _expectedDailyXp(DailyActivity activity, UserInterest interest) {
    final stored = activity.xpAwarded;
    if (stored != null && stored > 0) return stored;
    final base = _baseXpForLevel(interest.level);
    if (base <= 0) return null;
    final scaled = (base * _currentXpMultiplier()).round();
    return max(1, scaled);
  }

  Future<_LoggedAmount?> _promptForGoalAmount({
    required String title,
    required String unit,
    double? suggested,
  }) async {
    final controller = TextEditingController(
      text: suggested != null ? _formatAmount(suggested) : "",
    );
    final focusNode = FocusNode();
    String? errorText;
    final result = await showDialog<_LoggedAmount>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Log your effort"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "How much did you complete for \"$title\"?",
                  ),
                  if (suggested != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Suggested ${_formatAmount(suggested)} $unit. Go above to earn extra XP.",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Amount ($unit)",
                      hintText: suggested != null ? _formatAmount(suggested) : "Enter amount",
                      errorText: errorText,
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed =
                        double.tryParse(controller.text.trim().replaceAll(",", "."));
                    if (parsed == null || parsed <= 0) {
                      setState(() => errorText = "Enter a positive number");
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _LoggedAmount(value: parsed, unit: unit),
                    );
                  },
                  child: const Text("Log amount"),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    focusNode.dispose();
    return result;
  }

  Widget _buildDailyCelebration() {
    final entry = _celebrations.entries.isNotEmpty ? _celebrations.entries.first : null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        final slideAnimation = animation.drive(
          Tween<Offset>(
            begin: const Offset(0, -0.12),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: entry == null
          ? const SizedBox.shrink()
          : _XpCelebration(
              key: ValueKey("${entry.key}-${entry.value}"),
              xp: entry.value,
            ),
    );
  }

  Widget _buildDailyActivityCard(DailyActivity activity) {
    final interest = _interests.firstWhere(
      (i) => i.id == activity.interestId,
      orElse: () => _fallbackInterest(activity.interestId),
    );
    final blueprint = interest.blueprint;
    final isLoading = _logging["daily-${activity.id}"] ?? false;
    final isCompleted = activity.isCompleted;
    final expectedXp = _expectedDailyXp(activity, interest);
    final suggestedAmount = _suggestedAmount(interest);
    final goalUnit = _goalUnit(interest, activity: activity);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: blueprint.accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(blueprint.icon, color: blueprint.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        blueprint.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Chip(
                            label: Text(
                              expectedXp != null ? "+$expectedXp XP" : "XP reward",
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            backgroundColor: blueprint.accentColor.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ],
                      ),
                      if (suggestedAmount != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          "Suggested ${_formatAmount(suggestedAmount)} $goalUnit",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openEditDailyActivity(activity),
                  child: const Text("Edit"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
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
                label: Text(
                  isCompleted
                      ? "Completed"
                      : isLoading
                      ? "Logging..."
                      : "Log a win",
                ),
                onPressed: (isLoading || isCompleted)
                    ? null
                    : () => _completeDailyActivity(activity),
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
          Builder(builder: (context) {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey.shade100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "No activity yet today.",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add a new activity to start your streak.",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            );
          })
        else
          ..._activities.map((log) {
            final interestName =
                _interests.firstWhere(
                  (interest) => interest.id == log.interestId,
                  orElse: () => _fallbackInterest(log.interestId),
                ).blueprint.name;
            final activityName = log.activity.isNotEmpty
                ? log.activity
                : (log.interest.isNotEmpty ? log.interest : interestName);
            final time = log.timestamp != null
                ? TimeOfDay.fromDateTime(log.timestamp!)
                : null;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text("$activityName • +${log.xpEarned} XP"),
              subtitle: time == null ? null : Text(time.format(context)),
            );
          }),
      ],
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadDailyActivities(),
      _loadActivities(),
      _loadActivityTypes(),
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

  Future<void> _completeDailyActivity(DailyActivity activity) async {
    final interest = _interests.firstWhere(
      (i) => i.id == activity.interestId,
      orElse: () => _fallbackInterest(activity.interestId),
    );
    final hasGoal = activity.goalId != null || (interest.plan?.weeklyGoalValue ?? 0) > 0;
    final suggested = _suggestedAmount(interest);
    _LoggedAmount? loggedAmount;
    if (hasGoal) {
      loggedAmount = await _promptForGoalAmount(
        title: activity.title,
        unit: _goalUnit(interest, activity: activity),
        suggested: suggested,
      );
      if (!mounted || loggedAmount == null) {
        return;
      }
    }

    setState(() => _logging["daily-${activity.id}"] = true);
    try {
      final response = await widget.apiService.completeDailyActivity(
        activity.id,
        value: loggedAmount?.value,
        unit: loggedAmount?.unit,
      );
      if (!mounted) return;
        if (response.isSuccess && response.data != null) {
          final completion = response.data!;
          final xpEarned = completion.xpAwarded ?? _expectedDailyXp(activity, interest);
          widget.onPetChanged(completion.pet);
          setState(() {
            _pet = completion.pet;
            _streakCurrent = completion.streakCurrent ?? _streakCurrent;
            _streakBest = completion.streakBest ?? _streakBest;
            _xpMultiplier = completion.xpMultiplier ?? _xpMultiplier;
            _dailyActivities =
                _dailyActivities.where((a) => a.id != activity.id).toList();
            _hadDailyToday = true;
            _completedToday.add(activity.interestId);
          });
        if (xpEarned != null) {
          _startCelebration(activity.interestId, xpEarned);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Great job! ${activity.title} logged +${xpEarned ?? 0} XP.",
            ),
          ),
        );
        _loadActivities();
      } else {
        widget.onError(response.error ?? "Failed to complete activity");
      }
    } finally {
      if (mounted) {
        setState(() => _logging["daily-${activity.id}"] = false);
      }
    }
  }

  Future<void> _refreshPetState() async {
    final response = await widget.apiService.fetchPet();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() => _pet = response.data!);
      widget.onPetChanged(response.data!);
    } else {
      widget.onError(response.error ?? "Failed to refresh pet");
    }
  }

  Future<void> _completeActivity(UserInterest interest) async {
    final hasPlan = (interest.plan?.weeklyGoalValue ?? 0) > 0;
    final suggested = _suggestedAmount(interest);
    _LoggedAmount? loggedAmount;
    if (hasPlan) {
      loggedAmount = await _promptForGoalAmount(
        title: interest.name,
        unit: _goalUnit(interest),
        suggested: suggested,
      );
      if (!mounted || loggedAmount == null) {
        return;
      }
    }

    setState(() => _logging[interest.name] = true);
    try {
      final response = await widget.apiService.completeActivity(
        interest.name,
        value: loggedAmount?.value,
        unit: loggedAmount?.unit,
      );
      if (!mounted) return;
      if (response.isSuccess && response.data != null) {
        final completion = response.data!;
        widget.onPetChanged(completion.pet);
        setState(() {
          _pet = completion.pet;
          _streakCurrent = completion.streakCurrent ?? _streakCurrent;
          _streakBest = completion.streakBest ?? _streakBest;
          _xpMultiplier = completion.xpMultiplier ?? _xpMultiplier;
        });
        _startCelebration(completion.interestId, completion.xpAwarded);
        _loadActivities();
        final coins = completion.coinsAwarded ?? 0;
        final coinsText = coins > 0 ? " and +$coins coins" : "";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Great job! ${interest.name} earned +${completion.xpAwarded} XP$coinsText.",
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
    } finally {
      if (mounted) {
        setState(() => _logging[interest.name] = false);
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "XP multiplier ${multiplier.toStringAsFixed(2)}x",
                    style: TextStyle(color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bestLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w700,
                    ),
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

  UserInterest? _nextLoggableInterest() {
    for (final interest in _interests) {
      final id = interest.id;
      final completed = id != null && _completedToday.contains(id);
      if (!completed) {
        return interest;
      }
    }
    return null;
  }

  Future<void> _openCoinStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoinStoreScreen(
          apiService: widget.apiService,
          currentBalance: _pet.coins,
          onBalanceUpdated: (newBalance) {
            final updated = _pet.copyWith(coins: newBalance);
            setState(() => _pet = updated);
            widget.onPetChanged(updated);
          },
        ),
      ),
    );
  }
}

class _LoggedAmount {
  const _LoggedAmount({required this.value, required this.unit});

  final double value;
  final String unit;
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

class _ActivityTypePickerSheet extends StatelessWidget {
  const _ActivityTypePickerSheet({
    required this.activityTypes,
    required this.isLoading,
  });

  final List<ActivityType> activityTypes;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.65;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 12,
        ),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Add new activity",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Pick an existing type to schedule it again or create a new one.",
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : activityTypes.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.history_rounded, size: 40, color: Colors.grey),
                                    const SizedBox(height: 12),
                                    const Text("No activity types yet"),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Create one with the + button.",
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: activityTypes.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final type = activityTypes[index];
                                  final subtitleParts = <String>[];
                                  if (type.areaName.isNotEmpty) {
                                    subtitleParts.add(type.areaName);
                                  }
                                  final plan = type.plan;
                                  if (plan != null && plan.weeklyGoalValue > 0) {
                                    final daysLabel =
                                        plan.days.isNotEmpty ? " • ${plan.days.join(", ").toUpperCase()}" : "";
                                    subtitleParts.add(
                                        "Goal: ${plan.weeklyGoalValue} ${plan.weeklyGoalUnit}$daysLabel");
                                  }
                                  final subtitle =
                                      subtitleParts.isEmpty ? null : subtitleParts.join(" • ");
                                  return ListTile(
                                    leading: const Icon(Icons.history_rounded),
                                    title: Text(type.name),
                                    subtitle: subtitle != null ? Text(subtitle) : null,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () =>
                                        Navigator.of(context).pop(_ActivityPickerResult(type: type)),
                                  );
                                },
                              ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: FloatingActionButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const _ActivityPickerResult(createNew: true)),
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetRiveAnimation extends StatefulWidget {
  const _PetRiveAnimation({
    required this.assetPath,
    required this.fallback,
    this.onControllerReady,
    this.fit = rive.Fit.cover,
  });

  final String assetPath;
  final Widget fallback;
  final rive.Fit fit;
  final ValueChanged<rive.RiveWidgetController>? onControllerReady;

  @override
  State<_PetRiveAnimation> createState() => _PetRiveAnimationState();
}

class _PetRiveAnimationState extends State<_PetRiveAnimation> {
  late final rive.FileLoader _fileLoader;
  rive.RiveWidgetController? _notifiedController;

  @override
  void initState() {
    super.initState();
    _fileLoader = rive.FileLoader.fromAsset(
      widget.assetPath,
      riveFactory: rive.Factory.rive,
    );
  }

  @override
  void dispose() {
    _fileLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return rive.RiveWidgetBuilder(
      fileLoader: _fileLoader,
      stateMachineSelector: const rive.StateMachineDefault(),
      builder: (context, state) => switch (state) {
        rive.RiveLoading() => Stack(
            fit: StackFit.expand,
            children: [
              widget.fallback,
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        rive.RiveFailed() => widget.fallback,
        rive.RiveLoaded() => Builder(
            builder: (context) {
              final controller = state.controller;
              if (widget.onControllerReady != null && _notifiedController != controller) {
                _notifiedController = controller;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onControllerReady?.call(controller);
                });
              }
              return rive.RiveWidget(
                controller: controller,
                fit: widget.fit,
              );
            },
          ),
      },
    );
  }
}

class _ActivityPickerResult {
  const _ActivityPickerResult({this.type, this.createNew = false});

  final ActivityType? type;
  final bool createNew;
}

class _NewActivityData {
  _NewActivityData({
    required this.name,
    required this.areaName,
    this.isNewArea = false,
    this.weeklyGoalValue,
    this.weeklyGoalUnit,
    this.days = const [],
    this.rrule,
    this.activityTypeId,
  });

  final String name;
  final String areaName;
  final bool isNewArea;
  final double? weeklyGoalValue;
  final String? weeklyGoalUnit;
  final List<String> days;
  final String? rrule;
  final int? activityTypeId;
}

class _ActivityFormResult {
  const _ActivityFormResult({this.data, this.deleted = false});

  final _NewActivityData? data;
  final bool deleted;
}

enum _RecurrenceOption { none, daily, weekly, monthly }

class _NewActivityScreen extends StatefulWidget {
  const _NewActivityScreen({
    required this.interests,
    this.initialType,
    this.allowDelete = false,
  });

  final List<UserInterest> interests;
  final ActivityType? initialType;
  final bool allowDelete;

  @override
  State<_NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends State<_NewActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _enableWeeklyGoal = false;
  final _weeklyGoalCtrl = TextEditingController();
  final _weeklyUnitCtrl = TextEditingController(text: "minutes");
  String? _selectedInterest;
  bool _useCustomArea = false;
  final _customAreaCtrl = TextEditingController();
  final Set<String> _selectedDays = {};
  _RecurrenceOption _recurrence = _RecurrenceOption.none;
  int _monthlyDay = 1;
  ActivityType? get _initialType => widget.initialType;
  bool get _isEditing => _initialType != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _prefillFromActivityType();
    }
  }

  void _prefillFromActivityType() {
    final type = _initialType;
    if (type == null) return;
    _nameCtrl.text = type.name;

    final areaName = type.areaName.isNotEmpty ? type.areaName : type.name;
    UserInterest? match;
    try {
      match = widget.interests
          .firstWhere((interest) => interest.name.toLowerCase() == areaName.toLowerCase());
    } catch (_) {
      match = null;
    }
    if (match != null) {
      _selectedInterest = match.name;
      _useCustomArea = false;
    } else {
      _useCustomArea = true;
      _customAreaCtrl.text = areaName;
    }

    final plan = type.plan;
    if (plan != null && plan.weeklyGoalValue > 0) {
      _enableWeeklyGoal = true;
      _weeklyGoalCtrl.text = plan.weeklyGoalValue.toString();
      _weeklyUnitCtrl.text = plan.weeklyGoalUnit;
      _selectedDays.addAll(plan.days.map((d) => d.toLowerCase()));
      _recurrence = _RecurrenceOption.weekly;
    }

    _applyRrule(type.rrule ?? "");
    if (_recurrence == _RecurrenceOption.none && _selectedDays.isNotEmpty) {
      _recurrence = _RecurrenceOption.weekly;
    }
  }

  void _applyRrule(String rrule) {
    if (rrule.isEmpty) return;
    final upper = rrule.toUpperCase();
    if (upper.contains("FREQ=DAILY")) {
      _recurrence = _RecurrenceOption.daily;
      return;
    }
    if (upper.contains("FREQ=WEEKLY")) {
      _recurrence = _RecurrenceOption.weekly;
      final match = RegExp(r"BYDAY=([^;]+)").firstMatch(upper);
      if (match != null) {
        final tokens = match.group(1)!.split(",");
        const map = {
          "MO": "mon",
          "TU": "tue",
          "WE": "wed",
          "TH": "thu",
          "FR": "fri",
          "SA": "sat",
          "SU": "sun",
        };
        for (final token in tokens) {
          final normalized = map[token.trim()] ?? "";
          if (normalized.isNotEmpty) _selectedDays.add(normalized);
        }
      }
      return;
    }
    if (upper.contains("FREQ=MONTHLY")) {
      _recurrence = _RecurrenceOption.monthly;
      final match = RegExp(r"BYMONTHDAY=([0-9]{1,2})").firstMatch(upper);
      if (match != null) {
        final value = int.tryParse(match.group(1) ?? "");
        if (value != null && value >= 1 && value <= 28) {
          _monthlyDay = value;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weeklyGoalCtrl.dispose();
    _weeklyUnitCtrl.dispose();
    _customAreaCtrl.dispose();
    super.dispose();
  }

  Widget _buildRecurrenceSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Repetition",
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _recurrenceOptionChip(_RecurrenceOption.none, "Never"),
            _recurrenceOptionChip(_RecurrenceOption.daily, "Daily"),
            _recurrenceOptionChip(_RecurrenceOption.weekly, "Weekly"),
            _recurrenceOptionChip(_RecurrenceOption.monthly, "Monthly"),
          ],
        ),
      ],
    );
  }

  Widget _recurrenceOptionChip(_RecurrenceOption option, String label) {
    final selected = _recurrence == option;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _recurrence = option),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit activity" : "New activity"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Activity name",
                    hintText: "e.g. Jump rope",
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? "Name required" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _useCustomArea ? "custom" : _selectedInterest,
                  decoration: const InputDecoration(labelText: "Area"),
                  items: [
                    ...widget.interests.map(
                      (interest) => DropdownMenuItem<String>(
                        value: interest.name,
                        child: Text(interest.name),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: "custom",
                      child: Text("Create new area..."),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      if (value == "custom") {
                        _useCustomArea = true;
                        _selectedInterest = null;
                      } else {
                        _useCustomArea = false;
                        _selectedInterest = value;
                      }
                    });
                  },
                  validator: (_) {
                    if (_useCustomArea) {
                      if (_customAreaCtrl.text.trim().isEmpty) {
                        return "Enter a new area name";
                      }
                      return null;
                    }
                    return (_selectedInterest == null || _selectedInterest!.isEmpty)
                        ? "Select an area"
                        : null;
                  },
                ),
                if (_useCustomArea) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customAreaCtrl,
                    decoration: const InputDecoration(
                      labelText: "New area name",
                      hintText: "e.g. Reading",
                    ),
                    validator: (value) {
                      if (!_useCustomArea) return null;
                      if (value == null || value.trim().isEmpty) {
                        return "Enter a new area name";
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                _buildRecurrenceSelector(),
                SwitchListTile(
                  title: const Text("Add weekly goal"),
                  value: _enableWeeklyGoal,
                  onChanged: (value) => setState(() => _enableWeeklyGoal = value),
                ),
                if (_enableWeeklyGoal) ...[
                  TextFormField(
                    controller: _weeklyGoalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Weekly goal amount",
                      hintText: "e.g. 90",
                    ),
                    validator: (value) {
                      if (!_enableWeeklyGoal) return null;
                      final parsed = double.tryParse(value ?? "");
                      if (parsed == null || parsed <= 0) {
                        return "Enter a positive number";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weeklyUnitCtrl,
                    decoration: const InputDecoration(
                      labelText: "Unit",
                      hintText: "minutes, km, etc.",
                    ),
                  ),
                ],
                if (_recurrence == _RecurrenceOption.weekly) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Days",
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {"key": "mon", "label": "Mon"},
                      {"key": "tue", "label": "Tue"},
                      {"key": "wed", "label": "Wed"},
                      {"key": "thu", "label": "Thu"},
                      {"key": "fri", "label": "Fri"},
                      {"key": "sat", "label": "Sat"},
                      {"key": "sun", "label": "Sun"},
                    ].map((entry) {
                      final key = entry["key"]!;
                      final label = entry["label"]!;
                      final selected = _selectedDays.contains(key);
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedDays.add(key);
                            } else {
                              _selectedDays.remove(key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (_recurrence == _RecurrenceOption.monthly) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Day of month",
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: _monthlyDay.toDouble(),
                    min: 1,
                    max: 28,
                    divisions: 27,
                    label: _monthlyDay.toString(),
                    onChanged: (value) => setState(() => _monthlyDay = value.round()),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text("Save activity"),
                    onPressed: _submit,
                  ),
                ),
                if (_isEditing && widget.allowDelete) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    label: const Text(
                      "Delete activity",
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: _confirmDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_recurrence == _RecurrenceOption.weekly && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pick at least one day for weekly repeat")),
      );
      return;
    }
    final weeklyValue =
        !_enableWeeklyGoal ? null : double.tryParse(_weeklyGoalCtrl.text.trim());
    String? rrule;
    if (_recurrence == _RecurrenceOption.daily) {
      rrule = "FREQ=DAILY";
    } else if (_recurrence == _RecurrenceOption.weekly && _selectedDays.isNotEmpty) {
        final map = {
          "mon": "MO",
          "tue": "TU",
          "wed": "WE",
          "thu": "TH",
          "fri": "FR",
          "sat": "SA",
          "sun": "SU",
        };
        final bydays = _selectedDays.map((d) => map[d] ?? "").where((d) => d.isNotEmpty).join(",");
        if (bydays.isNotEmpty) {
          rrule = "FREQ=WEEKLY;BYDAY=$bydays";
        }
    } else if (_recurrence == _RecurrenceOption.monthly) {
      rrule = "FREQ=MONTHLY;BYMONTHDAY=$_monthlyDay";
    }
    final areaName = _useCustomArea ? _customAreaCtrl.text.trim() : (_selectedInterest ?? "");
    Navigator.of(context).pop(
      _ActivityFormResult(
        data: _NewActivityData(
          name: _nameCtrl.text.trim(),
          areaName: areaName,
          isNewArea: _useCustomArea,
          weeklyGoalValue: weeklyValue,
          weeklyGoalUnit: _enableWeeklyGoal ? _weeklyUnitCtrl.text.trim() : null,
          days:
              _recurrence == _RecurrenceOption.weekly ? _selectedDays.toList() : const [],
          rrule: rrule,
          activityTypeId: _initialType?.id,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete activity"),
        content: const Text(
          "This will remove the activity and its upcoming daily tasks. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    Navigator.of(context).pop(const _ActivityFormResult(deleted: true));
  }
}
