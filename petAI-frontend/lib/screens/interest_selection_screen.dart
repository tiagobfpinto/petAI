import 'package:flutter/material.dart';

import '../data/interest_catalog.dart';
import '../models/interest.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({
    super.key,
    required this.catalog,
    required this.onContinue,
    this.onLogout,
  });

  final List<InterestBlueprint> catalog;
  final void Function(List<InterestBlueprint> selections) onContinue;
  final VoidCallback? onLogout;

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final Set<String> _selectedIds = {};
  final List<InterestBlueprint> _customInterests = [];
  int _colorCursor = 0;

  @override
  Widget build(BuildContext context) {
    final allInterests = [...widget.catalog, ..._customInterests];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose your interests"),
        actions: [
          if (widget.onLogout != null)
            TextButton(
              onPressed: widget.onLogout,
              child: const Text("Log out"),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tell PetAI what you care about and we will suggest the next micro-actions.",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.swipe_rounded, color: Colors.grey.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Select as many interests as you like. You can also add a custom track.",
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InterestsGrid(
                    interests: allInterests,
                    isWide: isWide,
                    selectedIds: _selectedIds,
                    onToggle: _toggleSelection,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text("Add custom interest"),
                          onPressed: _handleAddCustomInterest,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () {
                              final selected = allInterests
                                  .where(
                                    (interest) =>
                                        _selectedIds.contains(interest.id),
                                  )
                                  .toList();
                              widget.onContinue(selected);
                            },
                      child: Text(
                        "Continue with ${_selectedIds.length} interest${_selectedIds.length == 1 ? "" : "s"}",
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _handleAddCustomInterest() async {
    final blueprint = await showModalBottomSheet<InterestBlueprint>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CustomInterestSheet(
        accentColor:
            customInterestPalette[_colorCursor % customInterestPalette.length],
      ),
    );

    if (blueprint != null) {
      setState(() {
        _customInterests.add(blueprint);
        _selectedIds.add(blueprint.id);
        _colorCursor++;
      });
    }
  }
}

class _InterestsGrid extends StatelessWidget {
  const _InterestsGrid({
    required this.interests,
    required this.isWide,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<InterestBlueprint> interests;
  final bool isWide;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isWide ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: isWide ? 2.1 : 1.4,
      ),
      itemCount: interests.length,
      itemBuilder: (context, index) {
        final interest = interests[index];
        final isSelected = selectedIds.contains(interest.id);
        return _InterestCard(
          interest: interest,
          isSelected: isSelected,
          onTap: () => onToggle(interest.id),
        );
      },
    );
  }
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.interest,
    required this.isSelected,
    required this.onTap,
  });

  final InterestBlueprint interest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      interest.accentColor.withValues(alpha: isSelected ? 1 : 0.15),
      interest.accentColor.withValues(alpha: isSelected ? 0.9 : 0.05),
    ];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? interest.accentColor : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  child: Icon(interest.icon, color: interest.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    interest.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? interest.accentColor
                      : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              interest.description,
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interest.suggestedActivities
                  .map(
                    (activity) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        activity,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomInterestSheet extends StatefulWidget {
  const _CustomInterestSheet({required this.accentColor});

  final Color accentColor;

  @override
  State<_CustomInterestSheet> createState() => _CustomInterestSheetState();
}

class _CustomInterestSheetState extends State<_CustomInterestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _activitiesCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _activitiesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Custom interest",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Give it a name"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: "Describe what \"better\" means",
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Describe the goal"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _activitiesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Suggested activities",
                  hintText:
                      "Comma separated. Example: Brain dump, Research, Publish draft",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() != true) {
                      return;
                    }
                    final activities = _activitiesCtrl.text
                        .split(RegExp(r",|\n"))
                        .map((entry) => entry.trim())
                        .where((entry) => entry.isNotEmpty)
                        .toList();
                    final interest = InterestBlueprint(
                      id: "custom-${DateTime.now().millisecondsSinceEpoch}",
                      name: _nameCtrl.text.trim(),
                      description: _descriptionCtrl.text.trim(),
                      suggestedActivities: activities.isEmpty
                          ? [
                              "Brainstorm ideas",
                              "Ask PetAI for a micro-goal",
                              "Log a quick win",
                            ]
                          : activities,
                      goalPresets: _defaultCustomPresets(_nameCtrl.text.trim()),
                      accentColor: widget.accentColor,
                      icon: Icons.auto_awesome_motion_rounded,
                    );
                    Navigator.of(context).pop(interest);
                  },
                  child: const Text("Add interest"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<MotivationLevel, GoalPreset> _defaultCustomPresets(String name) {
    return {
      MotivationLevel.never: GoalPreset(
        title: "Ease into $name",
        description: "Start tiny so you can celebrate day one.",
        suggestion: "Spend 10 minutes exploring $name twice this week.",
      ),
      MotivationLevel.sometimes: GoalPreset(
        title: "Design a cadence",
        description: "Schedule it so momentum compounds.",
        suggestion:
            "Block three 20-minute sessions for $name and track one insight.",
      ),
      MotivationLevel.usually: GoalPreset(
        title: "Sharpen execution",
        description: "Add feedback loops to stay focused.",
        suggestion:
            "Ship two tangible outcomes for $name and journal learnings.",
      ),
      MotivationLevel.always: GoalPreset(
        title: "Optimize flow",
        description: "Refine the routine that already works.",
        suggestion:
            "Maintain four sessions for $name and review metrics weekly.",
      ),
    };
  }
}
