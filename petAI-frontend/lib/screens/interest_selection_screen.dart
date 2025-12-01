import 'dart:async';

import 'package:flutter/material.dart';

import '../data/interest_catalog.dart';
import '../models/activity_plan.dart';
import '../models/goal_suggestion.dart';
import '../models/interest.dart';
import '../models/user_interest.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({
    super.key,
    required this.apiService,
    required this.existingInterests,
    required this.user,
    required this.onSaved,
    required this.onLogout,
    required this.onManageAccount,
  });

  final ApiService apiService;
  final List<UserInterest> existingInterests;
  final UserSession user;
  final ValueChanged<List<UserInterest>> onSaved;
  final VoidCallback onLogout;
  final VoidCallback onManageAccount;

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final List<_InterestDraft> _drafts = [];
  List<String> _defaultLibrary = [];
  bool _loadingDefaults = true;
  bool _saving = false;
  bool _savingProfile = false;
  bool _profileDirty = false;
  int? _profileAge;
  String? _profileGender;
  late TextEditingController _ageCtrl;
  String? _loadError;
  final List<String> _genderOptions = const [
    "Female",
    "Male",
    "Non-binary",
    "Prefer not to say",
  ];

  @override
  void initState() {
    super.initState();
    _profileAge = widget.user.age;
    _profileGender = widget.user.gender;
    _ageCtrl = TextEditingController(
      text: _profileAge != null && _profileAge! > 0
          ? _profileAge.toString()
          : "",
    );
    _drafts.addAll(
      widget.existingInterests
          .map(
            (interest) => _InterestDraft(
              name: interest.name,
              level: interest.level,
              goal: interest.goal ?? "",
              plan:
                  interest.plan != null &&
                      interest.name.toLowerCase() == "running"
                  ? RunningPlanDraft.fromPlan(interest.plan!)
                  : null,
              isCustom: !isKnownInterestName(interest.name),
            ),
          )
          .toList(),
    );
    _loadDefaults();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    super.dispose();
  }

  bool get _profileComplete =>
      (_profileAge ?? 0) > 0 && (_profileGender ?? "").isNotEmpty;

  RunningPlanDraft _suggestRunningPlanDraft(MotivationLevel level) {
    double baseKm;
    switch (level) {
      case MotivationLevel.never:
        baseKm = 2;
        break;
      case MotivationLevel.sometimes:
        baseKm = 3.5;
        break;
      case MotivationLevel.usually:
        baseKm = 5;
        break;
      case MotivationLevel.always:
        baseKm = 7;
        break;
    }
    if (_profileAge != null) {
      if (_profileAge! < 25) {
        baseKm *= 1.1;
      } else if (_profileAge! > 50) {
        baseKm *= 0.7;
      }
    }
    final gender = (_profileGender ?? "").toLowerCase();
    if (gender.startsWith("female")) {
      baseKm *= 0.9;
    } else if (gender.contains("non")) {
      baseKm *= 0.95;
    }
    baseKm = double.parse(baseKm.toStringAsFixed(1));
    if (baseKm < 1) baseKm = 1;
    return RunningPlanDraft(
      weeklyGoalValue: baseKm,
      days: const ["mon", "wed"],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose your interests"),
        actions: [
          IconButton(
            tooltip: "Refresh library",
            onPressed: _loadingDefaults ? null : _loadDefaults,
            icon: const Icon(Icons.refresh_rounded),
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
      ),
      body: SafeArea(
        child: _loadingDefaults
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDefaults,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Text(
                      "Pick at least one interest to unlock your pet's activity feed. "
                      "You can always edit this later.",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildProfileCard(),
                    const SizedBox(height: 12),
                    if (_loadError != null)
                      _ErrorBanner(
                        message: _loadError!,
                        onRetry: _loadDefaults,
                      ),
                    const SizedBox(height: 8),
                    _buildLibrarySection(),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Add a custom interest"),
                      onPressed: () =>
                          _openEditor(draft: _InterestDraft.custom()),
                    ),
                    const SizedBox(height: 24),
                    _buildSelectionList(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _drafts.isEmpty ||
                                _saving ||
                                _savingProfile ||
                                !_profileComplete
                            ? null
                            : _handleSave,
                        child: (_saving || _savingProfile)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                "Save ${_drafts.length} interest${_drafts.length == 1 ? "" : "s"}",
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final subtitle = _profileComplete
        ? "Thanks! We'll tailor running goals based on your details."
        : "Age and gender help us suggest safe starting goals for running.";
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Tell us about you",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Age",
                      hintText: "e.g. 28",
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      setState(() {
                        _profileAge = parsed;
                        _profileDirty = true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _genderOptions.contains(_profileGender)
                        ? _profileGender
                        : null,
                    decoration: const InputDecoration(labelText: "Gender"),
                    isExpanded: true,
                    items: _genderOptions
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _profileGender = value;
                        _profileDirty = true;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (!_profileComplete)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Complete these to continue.",
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrarySection() {
    if (_defaultLibrary.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Popular picks", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _defaultLibrary.map((name) {
            final selected = _draftForName(name) != null;
            final blueprint = resolveInterestBlueprint(name);
            return GestureDetector(
              onTap: () => _openEditor(
                draft:
                    _draftForName(name) ??
                    _InterestDraft.suggested(
                      blueprint.name,
                      plan: blueprint.id.toLowerCase() == "running"
                          ? _suggestRunningPlanDraft(MotivationLevel.sometimes)
                          : null,
                    ),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? blueprint.accentColor.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? blueprint.accentColor
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(blueprint.icon, color: blueprint.accentColor),
                    const SizedBox(width: 10),
                    Text(
                      blueprint.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? blueprint.accentColor.darken()
                            : Colors.black87,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle_rounded,
                        color: blueprint.accentColor,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectionList() {
    if (_drafts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          "No interests selected yet. Tap one of the suggestions or add your own.",
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Your plan", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ..._drafts.map((draft) {
          final blueprint = resolveInterestBlueprint(draft.name);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: blueprint.accentColor.withValues(alpha: 0.18),
                child: Icon(blueprint.icon, color: blueprint.accentColor),
              ),
              title: Text(blueprint.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.level.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (draft.plan != null &&
                      resolveInterestBlueprint(draft.name).id.toLowerCase() ==
                          "running")
                    Text(
                      "Weekly: ${draft.plan!.weeklyGoalValue.toStringAsFixed(1)} ${draft.plan!.unit} • ${draft.plan!.formattedDays()} (${draft.plan!.perDayGoal().toStringAsFixed(1)} ${draft.plan!.unit}/day)",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if (draft.goal.isNotEmpty)
                    Text(
                      draft.goal,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "Edit",
                    onPressed: () => _openEditor(draft: draft),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: "Remove",
                    onPressed: () => setState(() => _drafts.remove(draft)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _loadDefaults() async {
    setState(() {
      _loadingDefaults = true;
      _loadError = null;
    });
    final response = await widget.apiService.fetchDefaultInterests();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _defaultLibrary = response.data!;
        _loadingDefaults = false;
      });
    } else {
      setState(() {
        _loadError = response.error ?? "Failed to load interests";
        _loadingDefaults = false;
      });
    }
  }

  Future<void> _openEditor({_InterestDraft? draft}) async {
    var initial =
        draft ??
        (_defaultLibrary.isNotEmpty
            ? _InterestDraft.suggested(_defaultLibrary.first)
            : _InterestDraft.custom());
    if (resolveInterestBlueprint(initial.name).id.toLowerCase() == "running" &&
        initial.plan == null) {
      initial = initial.copyWith(plan: _suggestRunningPlanDraft(initial.level));
    }
    final result = await showModalBottomSheet<_InterestDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InterestDraftSheet(
        initial: initial,
        apiService: widget.apiService,
        profileAge: _profileAge,
        profileGender: _profileGender,
      ),
    );
    if (result == null) return;
    setState(() {
      final index = _drafts.indexWhere(
        (entry) => entry.name.toLowerCase() == result.name.toLowerCase(),
      );
      if (index >= 0) {
        _drafts[index] = result;
      } else {
        _drafts.add(result);
      }
    });
  }

  _InterestDraft? _draftForName(String name) {
    for (final draft in _drafts) {
      if (draft.name.toLowerCase() == name.toLowerCase()) {
        return draft;
      }
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_profileComplete) {
      _showSnack("Add your age and gender to tailor your plan.");
      return;
    }
    setState(() => _savingProfile = true);
    final profileOk = await _saveProfileIfNeeded();
    if (!mounted) return;
    setState(() => _savingProfile = false);
    if (!profileOk) return;

    setState(() => _saving = true);
    final payload = _drafts.map((draft) => draft.toPayload()).toList();
    final response = await widget.apiService.saveUserInterests(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (response.isSuccess && response.data != null) {
      widget.onSaved(response.data!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Interests saved")));
    } else {
      _showSnack(response.error ?? "Failed to save interests");
    }
  }

  Future<bool> _saveProfileIfNeeded() async {
    if (!_profileDirty) return true;
    if (_profileAge == null ||
        _profileGender == null ||
        _profileGender!.isEmpty) {
      return false;
    }
    final response = await widget.apiService.updateProfile(
      age: _profileAge,
      gender: _profileGender,
    );
    if (response.isSuccess) {
      setState(() {
        _profileDirty = false;
      });
      return true;
    }
    _showSnack(response.error ?? "Failed to save profile");
    return false;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InterestDraftSheet extends StatefulWidget {
  const _InterestDraftSheet({
    required this.initial,
    required this.apiService,
    this.profileAge,
    this.profileGender,
  });

  final _InterestDraft initial;
  final ApiService apiService;
  final int? profileAge;
  final String? profileGender;

  @override
  State<_InterestDraftSheet> createState() => _InterestDraftSheetState();
}

class _InterestDraftSheetState extends State<_InterestDraftSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _goalCtrl;
  late MotivationLevel _level;
  late double _weeklyGoalValue;
  late String _weeklyGoalUnit;
  Set<String> _selectedDays = {};
  bool _planTouched = false;
  String? _planError;
  GoalSuggestion? _activitySuggestion;
  bool _activitySuggestionLoading = false;
  String? _activitySuggestionError;
  GoalSuggestion? _weeklyGoalSuggestion;
  bool _weeklyGoalLoading = false;
  String? _weeklyGoalError;
  Timer? _weeklyGoalDebounce;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _goalCtrl = TextEditingController(text: "");
    _goalCtrl.addListener(_handleActivityChanged);
    _level = widget.initial.level;
    _weeklyGoalValue =
        widget.initial.plan?.weeklyGoalValue ?? _suggestWeeklyGoal();
    _weeklyGoalUnit = widget.initial.plan?.unit ?? "km";
    _selectedDays = widget.initial.plan?.days.toSet() ?? {"mon", "wed"};

    // Auto-fetch a suggestion when we already have profile info for running.
    if (_isRunning &&
        widget.profileAge != null &&
        (widget.profileGender ?? "").isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSuggestedActivity();
        _loadWeeklyGoalSuggestion();
      });
    }
  }

  @override
  void dispose() {
    _weeklyGoalDebounce?.cancel();
    _goalCtrl.removeListener(_handleActivityChanged);
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.trim().isEmpty
        ? widget.initial.name
        : _nameCtrl.text.trim();
    final blueprint = resolveInterestBlueprint(name);
    final preset = blueprint.presetFor(_level);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
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
                        child: Text(
                          "Configure ${blueprint.name}",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    enabled: widget.initial.isCustom,
                    decoration: const InputDecoration(labelText: "Name"),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? "Name is required"
                        : null,
                    onChanged: (_) => setState(() {
                      if (!_isRunning) {
                        _activitySuggestion = null;
                        _activitySuggestionError = null;
                        _weeklyGoalSuggestion = null;
                        _weeklyGoalError = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "How often do you already do this?",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: MotivationLevel.values.map((level) {
                      final selected = level == _level;
                      return ChoiceChip(
                        label: Text(level.label),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _activitySuggestion = null;
                            _activitySuggestionError = null;
                            _weeklyGoalSuggestion = null;
                            _weeklyGoalError = null;
                            _level = level;
                            if (_isRunning && !_planTouched) {
                              _weeklyGoalValue = _suggestWeeklyGoal();
                            }
                            if (_goalCtrl.text.trim().isEmpty) {
                              _goalCtrl.text = blueprint
                                  .presetFor(level)
                                  .suggestion;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (_isRunning) ...[
                    const SizedBox(height: 12),
                    _buildSuggestionSection(),
                  ] else ...[
                    _buildActivityField(),
                  ],
                  if (_isRunning) ...[
                    const SizedBox(height: 12),
                    _buildWeeklyGoalSection(context),
                    const SizedBox(height: 16),
                    Text(
                      "Weekly goal",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _weeklyGoalValue.clamp(
                              _weeklySliderMin,
                              _weeklySliderMax,
                            ),
                            min: _weeklySliderMin,
                            max: _weeklySliderMax,
                            divisions: _weeklySliderDivisions,
                            label: _formatWeeklyLabel(_weeklyGoalValue),
                            onChanged: (value) {
                              setState(() {
                                _weeklyGoalValue = double.parse(
                                  value.toStringAsFixed(1),
                                );
                                _planTouched = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatWeeklyLabel(_weeklyGoalValue)),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _weeklyGoalLoading
                            ? null
                            : _loadWeeklyGoalSuggestion,
                        icon: _weeklyGoalLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          _weeklyGoalLoading
                              ? "Fetching..."
                              : "Refresh weekly goal",
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Which days will you run?",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _weekDays
                          .map(
                            (entry) => FilterChip(
                              label: Text(entry.label),
                              selected: _selectedDays.contains(entry.key),
                              onSelected: (_) {
                                setState(() {
                                  _planTouched = true;
                                  if (_selectedDays.contains(entry.key)) {
                                    _selectedDays.remove(entry.key);
                                  } else {
                                    _selectedDays.add(entry.key);
                                  }
                                  _planError = null;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (_planError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          _planError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedDays.isEmpty
                          ? "Pick at least one day to create a daily running activity."
                          : "Daily split: ${_perDayGoal().toStringAsFixed(1)} ${_weeklyGoalUnit} on ${_formattedDays()}",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text("Save interest"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityField() {
    return TextFormField(
      controller: _goalCtrl,
      minLines: 2,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: "Activity",
        hintText: "Your activity here",
      ),
    );
  }

  Widget _buildSuggestionSection() {
    final theme = Theme.of(context);

    Widget suggestionContent;
    if (_activitySuggestionLoading && _activitySuggestion == null) {
      suggestionContent = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              "Personalizing your cardio activity...",
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    } else if (_activitySuggestion != null) {
      suggestionContent = _SuggestedGoalCard(
        suggestion: _activitySuggestion!,
        onUse: () {
          final text = _activitySuggestion!.suggestedActivity.trim();
          if (text.isNotEmpty) {
            setState(() {
              _goalCtrl.text = text;
            });
          }
        },
      );
    } else {
      suggestionContent = Text(
        "Fetch a suggested cardio activity based on your profile.",
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.grey.shade700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "AI suggested activity",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              tooltip: "Refresh activity",
              onPressed:
                  _activitySuggestionLoading ? null : _loadSuggestedActivity,
              icon: _activitySuggestionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (_activitySuggestionError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _activitySuggestionError!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 620;
            final activityField = _buildActivityField();
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: suggestionContent),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: activityField),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                suggestionContent,
                const SizedBox(height: 12),
                activityField,
              ],
            );
          },
        ),
      ],
    );
  }

  void _handleActivityChanged() {
    if (!_isRunning) {
      _weeklyGoalDebounce?.cancel();
      return;
    }
    final text = _goalCtrl.text.trim();
    if (text.isEmpty) {
      _weeklyGoalDebounce?.cancel();
      return;
    }
    _weeklyGoalDebounce?.cancel();
    _weeklyGoalDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_weeklyGoalLoading) return;
      if (text != _goalCtrl.text.trim()) return;
      _loadWeeklyGoalSuggestion();
    });
  }

  Widget _buildWeeklyGoalSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "AI weekly goal",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              tooltip: "Refresh weekly goal",
              onPressed: _weeklyGoalLoading ? null : _loadWeeklyGoalSuggestion,
              icon: _weeklyGoalLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (_weeklyGoalError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _weeklyGoalError!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_weeklyGoalLoading && _weeklyGoalSuggestion == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  "Calculating a weekly target...",
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        if (_weeklyGoalSuggestion != null)
          _WeeklyGoalSuggestionCard(
            suggestion: _weeklyGoalSuggestion!,
            onApply: _applyWeeklyGoalSuggestion,
          )
        else if (!_weeklyGoalLoading)
          Text(
            "Pull a safe weekly target that gently builds on your last goal.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
      ],
    );
  }

  Future<void> _loadSuggestedActivity() async {
    if (!_isRunning) return;
    if (widget.profileAge == null || (widget.profileGender ?? "").isEmpty) {
      setState(() {
        _activitySuggestion = null;
        _activitySuggestionError =
            "Add age and gender in the profile card first.";
      });
      return;
    }
    setState(() {
      _activitySuggestionLoading = true;
      _activitySuggestionError = null;
    });
    final response = await widget.apiService.fetchGoalSuggestion(
      age: widget.profileAge,
      gender: widget.profileGender,
      activityLevel: _level.key,
    );
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      final suggestion = response.data!;
      setState(() {
        _activitySuggestionLoading = false;
        _activitySuggestionError = null;
        _activitySuggestion = suggestion;
        final text = suggestion.suggestedActivity.trim();
        if (text.isNotEmpty && _goalCtrl.text.trim().isEmpty) {
          _goalCtrl.text = text;
        }
      });
    } else {
      setState(() {
        _activitySuggestionLoading = false;
        _activitySuggestionError =
            response.error ?? "Failed to fetch suggestion";
      });
    }
  }

  Future<void> _loadWeeklyGoalSuggestion() async {
    if (!_isRunning) return;
    if (_goalCtrl.text.trim().isEmpty) {
      setState(() {
        _weeklyGoalSuggestion = null;
        _weeklyGoalError = "Add an activity first.";
      });
      return;
    }
    if (widget.profileAge == null || (widget.profileGender ?? "").isEmpty) {
      setState(() {
        _weeklyGoalSuggestion = null;
        _weeklyGoalError = "Add age and gender in the profile card first.";
      });
      return;
    }
    setState(() {
      _weeklyGoalLoading = true;
      _weeklyGoalError = null;
      _weeklyGoalSuggestion = null;
    });
    final response = await widget.apiService.fetchWeeklyGoalSuggestion(
      age: widget.profileAge,
      gender: widget.profileGender,
      activity: _goalCtrl.text.trim(),
      lastGoalValue: _weeklyGoalValue,
      lastGoalUnit: _weeklyGoalUnit,
      interestName: "running",
    );
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      final suggestion = response.data!;
      setState(() {
        _weeklyGoalLoading = false;
        _weeklyGoalError = null;
        _weeklyGoalSuggestion = suggestion;
      });
      _applyWeeklyGoalSuggestion(suggestion);
    } else {
      setState(() {
        _weeklyGoalLoading = false;
        _weeklyGoalError = response.error ?? "Failed to fetch weekly goal";
      });
    }
  }

  void _applyWeeklyGoalSuggestion(GoalSuggestion suggestion) {
    final amount = suggestion.amount;
    if (amount == null || amount <= 0) return;
    final nextUnit = (suggestion.unit ?? _weeklyGoalUnit).trim();
    setState(() {
      if (nextUnit.isNotEmpty) {
        _weeklyGoalUnit = nextUnit;
      }
      final min = _weeklySliderMin;
      final max = _weeklySliderMax;
      final clamped = amount.clamp(min, max);
      _weeklyGoalValue = double.parse(clamped.toStringAsFixed(1));
      _planTouched = true;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_isRunning && _selectedDays.isEmpty) {
      setState(() {
        _planError = "Pick at least one training day";
      });
      return;
    }
    final plan = _isRunning
        ? RunningPlanDraft(
            weeklyGoalValue: _weeklyGoalValue,
            unit: _weeklyGoalUnit,
            days: _orderedSelectedDays(),
          )
        : null;
    Navigator.of(context).pop(
      widget.initial.copyWith(
        name: _nameCtrl.text.trim(),
        goal: _goalCtrl.text.trim(),
        level: _level,
        plan: plan,
      ),
    );
  }

  bool get _isRunning {
    final current =
        (_nameCtrl.text.isNotEmpty ? _nameCtrl.text : widget.initial.name)
            .trim()
            .toLowerCase();
    return current == "running" ||
        current.contains("running") ||
        current.contains("cardio");
  }

  double get _weeklySliderMin {
    final unit = _weeklyGoalUnit.toLowerCase();
    if (unit.startsWith("min")) {
      return 10;
    }
    return 1;
  }

  double get _weeklySliderMax {
    final unit = _weeklyGoalUnit.toLowerCase();
    if (unit.startsWith("min")) {
      return 300;
    }
    return 30;
  }

  int? get _weeklySliderDivisions {
    final unit = _weeklyGoalUnit.toLowerCase();
    if (unit.startsWith("min")) {
      return ((_weeklySliderMax - _weeklySliderMin) / 10).round();
    }
    return 29;
  }

  String _formatWeeklyLabel(double value) {
    final formatted = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return "$formatted ${_weeklyGoalUnit}";
  }

  List<_WeekDay> get _weekDays => const [
    _WeekDay(key: "mon", label: "Mon"),
    _WeekDay(key: "tue", label: "Tue"),
    _WeekDay(key: "wed", label: "Wed"),
    _WeekDay(key: "thu", label: "Thu"),
    _WeekDay(key: "fri", label: "Fri"),
    _WeekDay(key: "sat", label: "Sat"),
    _WeekDay(key: "sun", label: "Sun"),
  ];

  double _suggestWeeklyGoal() {
    double base;
    switch (_level) {
      case MotivationLevel.never:
        base = 2;
        break;
      case MotivationLevel.sometimes:
        base = 3.5;
        break;
      case MotivationLevel.usually:
        base = 5;
        break;
      case MotivationLevel.always:
        base = 7;
        break;
    }
    final age = widget.profileAge;
    if (age != null) {
      if (age < 25) {
        base *= 1.1;
      } else if (age > 50) {
        base *= 0.7;
      }
    }
    final gender = (widget.profileGender ?? "").toLowerCase();
    if (gender.startsWith("female")) {
      base *= 0.9;
    } else if (gender.contains("non")) {
      base *= 0.95;
    }
    return double.parse(base.clamp(1, 30).toStringAsFixed(1));
  }

  List<String> _orderedSelectedDays() {
    final order = {
      for (var i = 0; i < _weekDays.length; i++) _weekDays[i].key: i,
    };
    final list = _selectedDays.toList();
    list.sort((a, b) => (order[a] ?? 0).compareTo(order[b] ?? 0));
    return list;
  }

  double _perDayGoal() {
    if (_selectedDays.isEmpty) return 0;
    return double.parse(
      (_weeklyGoalValue / _selectedDays.length).toStringAsFixed(2),
    );
  }

  String _formattedDays() {
    final labels = {for (final d in _weekDays) d.key: d.label};
    final days = _orderedSelectedDays();
    return days.map((d) => labels[d] ?? d).join(", ");
  }
}

class _WeekDay {
  const _WeekDay({required this.key, required this.label});
  final String key;
  final String label;
}

class _SuggestedGoalCard extends StatelessWidget {
  const _SuggestedGoalCard({required this.suggestion, this.onUse});

  final GoalSuggestion suggestion;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaParts = <String>[];
    if (suggestion.model != null) {
      metaParts.add(suggestion.model!);
    }
    if (suggestion.source != null) {
      metaParts.add(suggestion.source!);
    }
    final meta = metaParts.isEmpty ? null : metaParts.join(" • ");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.suggestedActivity.isNotEmpty
                      ? suggestion.suggestedActivity
                      : "Suggested cardio activity",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onUse != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4),
              child: OutlinedButton(onPressed: onUse, child: const Text("Use")),
            ),
        ],
      ),
    );
  }
}

class _WeeklyGoalSuggestionCard extends StatelessWidget {
  const _WeeklyGoalSuggestionCard({
    required this.suggestion,
    required this.onApply,
  });

  final GoalSuggestion suggestion;
  final void Function(GoalSuggestion suggestion) onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = suggestion.amount;
    final unit = (suggestion.unit ?? "km").toLowerCase();
    final activity = suggestion.activity ?? suggestion.suggestedActivity;
    final metaParts = <String>[];
    if (suggestion.model != null) {
      metaParts.add(suggestion.model!);
    }
    if (suggestion.source != null) {
      metaParts.add(suggestion.source!);
    }
    final meta = metaParts.isEmpty ? null : metaParts.join(" • ");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.flag_rounded, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount != null
                      ? "Weekly target: ${amount.toStringAsFixed(amount >= 10 ? 0 : 1)} $unit"
                      : "Suggested weekly goal",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.isNotEmpty
                      ? "For: $activity"
                      : "LLM-picked for your profile",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade900,
                  ),
                ),
                if (meta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => onApply(suggestion),
            child: const Text("Use"),
          ),
        ],
      ),
    );
  }
}

class _InterestDraft {
  _InterestDraft({
    required this.name,
    required this.level,
    required this.goal,
    required this.isCustom,
    this.plan,
  });

  final String name;
  final MotivationLevel level;
  final String goal;
  final bool isCustom;
  final RunningPlanDraft? plan;

  factory _InterestDraft.suggested(
    String backendName, {
    RunningPlanDraft? plan,
  }) {
    final blueprint = resolveInterestBlueprint(backendName);
    final preset = blueprint.presetFor(MotivationLevel.sometimes);
    return _InterestDraft(
      name: backendName,
      level: MotivationLevel.sometimes,
      goal: preset.suggestion,
      plan: plan,
      isCustom: !isKnownInterestName(backendName),
    );
  }

  factory _InterestDraft.custom() {
    return _InterestDraft(
      name: "",
      level: MotivationLevel.sometimes,
      goal: "",
      isCustom: true,
      plan: null,
    );
  }

  Map<String, dynamic> toPayload() {
    final Map<String, dynamic> payload = {
      "name": name.trim(),
      "level": level.key,
    };
    final trimmedGoal = goal.trim();
    if (trimmedGoal.isNotEmpty) {
      payload["goal"] = trimmedGoal;
    }
    if (plan != null) {
      payload["plan"] = plan!.toPayload();
    }
    return payload;
  }

  _InterestDraft copyWith({
    String? name,
    MotivationLevel? level,
    String? goal,
    bool? isCustom,
    RunningPlanDraft? plan,
  }) {
    return _InterestDraft(
      name: name ?? this.name,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      isCustom: isCustom ?? this.isCustom,
      plan: plan ?? this.plan,
    );
  }
}

class RunningPlanDraft {
  const RunningPlanDraft({
    required this.weeklyGoalValue,
    required this.days,
    this.unit = "km",
  });

  final double weeklyGoalValue;
  final List<String> days;
  final String unit;

  factory RunningPlanDraft.fromPlan(ActivityPlan plan) {
    return RunningPlanDraft(
      weeklyGoalValue: plan.weeklyGoalValue,
      days: List<String>.from(plan.days),
      unit: plan.weeklyGoalUnit,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      "weekly_goal_value": weeklyGoalValue,
      "weekly_goal_unit": unit,
      "days": days,
    };
  }

  double perDayGoal() {
    if (days.isEmpty) return 0;
    return weeklyGoalValue / days.length;
  }

  String formattedDays() {
    const labels = {
      "mon": "Mon",
      "tue": "Tue",
      "wed": "Wed",
      "thu": "Thu",
      "fri": "Fri",
      "sat": "Sat",
      "sun": "Sun",
    };
    return days.map((d) => labels[d] ?? d).join(", ");
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = 0.2]) {
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
