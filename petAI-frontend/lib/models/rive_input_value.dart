class RiveInputValue {
  const RiveInputValue({required this.name, this.value});

  const RiveInputValue.trigger(String name) : this(name: name);

  const RiveInputValue.number(String name, double value) : this(name: name, value: value);

  final String name;
  final double? value;

  bool get hasValue => value != null;

  String get signature {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "";
    if (value == null) return trimmed;
    return "$trimmed:${value!.toString()}";
  }

  static RiveInputValue? fromTriggerValue(String? trigger, num? triggerValue) {
    final name = (trigger ?? "").trim();
    if (name.isEmpty) return null;
    final value = triggerValue == null ? null : triggerValue.toDouble();
    return RiveInputValue(name: name, value: value);
  }

  static RiveInputValue? fromDynamic(dynamic entry) {
    if (entry is Map<String, dynamic>) {
      final trigger = entry["trigger"]?.toString();
      final value = entry["trigger_value"] as num?;
      return fromTriggerValue(trigger, value);
    }
    if (entry == null) return null;
    final trigger = entry.toString().trim();
    if (trigger.isEmpty) return null;
    return RiveInputValue.trigger(trigger);
  }

  static List<RiveInputValue> listFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    final inputs = <RiveInputValue>[];
    for (final entry in raw) {
      final input = fromDynamic(entry);
      if (input != null) inputs.add(input);
    }
    return inputs;
  }
}
