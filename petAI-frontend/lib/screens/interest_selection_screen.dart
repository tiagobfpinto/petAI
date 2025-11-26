import 'package:flutter/material.dart';

import '../data/interest_catalog.dart';
import '../models/interest.dart';
import '../models/user_interest.dart';
import '../services/api_service.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({
    super.key,
    required this.apiService,
    required this.existingInterests,
    required this.onSaved,
    required this.onLogout,
    required this.onManageAccount,
  });

  final ApiService apiService;
  final List<UserInterest> existingInterests;
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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _drafts.addAll(
      widget.existingInterests
          .map(
            (interest) => _InterestDraft(
              name: interest.name,
              level: interest.level,
              goal: interest.goal ?? "",
              isCustom: !isKnownInterestName(interest.name),
            ),
          )
          .toList(),
    );
    _loadDefaults();
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
                      onPressed: () => _openEditor(
                        draft: _InterestDraft.custom(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSelectionList(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _drafts.isEmpty || _saving ? null : _handleSave,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
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

  Widget _buildLibrarySection() {
    if (_defaultLibrary.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Popular picks",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _defaultLibrary.map((name) {
            final selected = _draftForName(name) != null;
            final blueprint = resolveInterestBlueprint(name);
            return GestureDetector(
              onTap: () => _openEditor(
                draft: _draftForName(name) ??
                    _InterestDraft.suggested(blueprint.name),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    Icon(
                      blueprint.icon,
                      color: blueprint.accentColor,
                    ),
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
        Text(
          "Your plan",
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
                child: Icon(
                  blueprint.icon,
                  color: blueprint.accentColor,
                ),
              ),
              title: Text(blueprint.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.level.label,
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
    final initial = draft ??
        (_defaultLibrary.isNotEmpty
            ? _InterestDraft.suggested(_defaultLibrary.first)
            : _InterestDraft.custom());
    final result = await showModalBottomSheet<_InterestDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InterestDraftSheet(initial: initial),
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
    setState(() => _saving = true);
    final payload = _drafts.map((draft) => draft.toPayload()).toList();
    final response = await widget.apiService.saveUserInterests(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (response.isSuccess && response.data != null) {
      widget.onSaved(response.data!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Interests saved")),
      );
    } else {
      _showSnack(response.error ?? "Failed to save interests");
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

}

class _InterestDraftSheet extends StatefulWidget {
  const _InterestDraftSheet({required this.initial});

  final _InterestDraft initial;

  @override
  State<_InterestDraftSheet> createState() => _InterestDraftSheetState();
}

class _InterestDraftSheetState extends State<_InterestDraftSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _goalCtrl;
  late MotivationLevel _level;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _goalCtrl = TextEditingController(text: widget.initial.goal);
    _level = widget.initial.level;
  }

  @override
  void dispose() {
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

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
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
              validator: (value) =>
                  value == null || value.trim().isEmpty ? "Name is required" : null,
              onChanged: (_) => setState(() {}),
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
                      _level = level;
                      if (_goalCtrl.text.trim().isEmpty) {
                        _goalCtrl.text = blueprint.presetFor(level).suggestion;
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _goalCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Goal or reminder",
                hintText: preset.suggestion,
                helperText: "What outcome should PetAI cheer for?",
              ),
            ),
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
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      widget.initial.copyWith(
        name: _nameCtrl.text.trim(),
        goal: _goalCtrl.text.trim(),
        level: _level,
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
  });

  final String name;
  final MotivationLevel level;
  final String goal;
  final bool isCustom;

  factory _InterestDraft.suggested(String backendName) {
    final blueprint = resolveInterestBlueprint(backendName);
    final preset = blueprint.presetFor(MotivationLevel.sometimes);
    return _InterestDraft(
      name: backendName,
      level: MotivationLevel.sometimes,
      goal: preset.suggestion,
      isCustom: !isKnownInterestName(backendName),
    );
  }

  factory _InterestDraft.custom() {
    return _InterestDraft(
      name: "",
      level: MotivationLevel.sometimes,
      goal: "",
      isCustom: true,
    );
  }

  Map<String, dynamic> toPayload() {
    final payload = {
      "name": name.trim(),
      "level": level.key,
    };
    final trimmedGoal = goal.trim();
    if (trimmedGoal.isNotEmpty) {
      payload["goal"] = trimmedGoal;
    }
    return payload;
  }

  _InterestDraft copyWith({
    String? name,
    MotivationLevel? level,
    String? goal,
    bool? isCustom,
  }) {
    return _InterestDraft(
      name: name ?? this.name,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

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
          TextButton(
            onPressed: onRetry,
            child: const Text("Retry"),
          ),
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
