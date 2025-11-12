import 'package:flutter/material.dart';

import '../models/interest.dart';

class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({
    super.key,
    required this.interests,
    required this.onComplete,
    this.onBack,
  });

  final List<InterestBlueprint> interests;
  final void Function(List<SelectedInterest> data) onComplete;
  final VoidCallback? onBack;

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  late List<SelectedInterest> _configured;
  final Map<String, TextEditingController> _goalControllers = {};

  @override
  void initState() {
    super.initState();
    _configured = widget.interests.map((blueprint) {
      final preset = blueprint.presetFor(MotivationLevel.never);
      final selected = SelectedInterest(
        blueprint: blueprint,
        level: MotivationLevel.never,
        goal: preset.suggestion,
      );
      _goalControllers[blueprint.id] = TextEditingController(
        text: preset.suggestion,
      );
      return selected;
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _goalControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set your goals"),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.grey.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Pick a starting level for each interest — we will pre-fill a goal you can tweak.",
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                itemCount: _configured.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final item = _configured[index];
                  final controller = _goalControllers[item.blueprint.id]!;
                  return _GoalCard(
                    item: item,
                    controller: controller,
                    onLevelChanged: (level) => _updateLevel(index, level),
                    onGoalChanged: (goal) => _updateGoal(index, goal),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: const Text("Lock goals & continue"),
                  onPressed:
                      _configured.every((item) => item.goal.trim().isNotEmpty)
                      ? () => widget.onComplete(_configured)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateLevel(int index, MotivationLevel level) {
    final blueprint = _configured[index].blueprint;
    final preset = blueprint.presetFor(level);
    setState(() {
      _configured[index] = _configured[index].copyWith(
        level: level,
        goal: preset.suggestion,
      );
      final controller = _goalControllers[blueprint.id];
      if (controller != null) {
        controller.text = preset.suggestion;
      }
    });
  }

  void _updateGoal(int index, String goal) {
    setState(() {
      _configured[index] = _configured[index].copyWith(goal: goal);
    });
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.item,
    required this.controller,
    required this.onLevelChanged,
    required this.onGoalChanged,
  });

  final SelectedInterest item;
  final TextEditingController controller;
  final ValueChanged<MotivationLevel> onLevelChanged;
  final ValueChanged<String> onGoalChanged;

  @override
  Widget build(BuildContext context) {
    final blueprint = item.blueprint;
    final preset = blueprint.presetFor(item.level);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: blueprint.accentColor.withValues(alpha: 0.16),
                child: Icon(blueprint.icon, color: blueprint.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  blueprint.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                item.level.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: blueprint.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<MotivationLevel>(
            segments: MotivationLevel.values
                .map(
                  (level) =>
                      ButtonSegment(value: level, label: Text(level.label)),
                )
                .toList(),
            selected: {item.level},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onLevelChanged(selection.first),
          ),
          const SizedBox(height: 12),
          Text(
            preset.description,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: "Your goal",
              hintText: preset.suggestion,
            ),
            onChanged: onGoalChanged,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: blueprint.suggestedActivities
                .map(
                  (activity) => Chip(
                    label: Text(activity),
                    backgroundColor: Colors.grey.shade100,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
