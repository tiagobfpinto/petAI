class StyleEquipResult {
  const StyleEquipResult({
    required this.itemId,
    this.slot,
    this.trigger,
    this.triggerValue,
    this.style,
  });

  factory StyleEquipResult.fromJson(Map<String, dynamic> json) {
    final equipped = json['equipped'] as Map<String, dynamic>? ?? {};
    return StyleEquipResult(
      itemId: (equipped['item_id'] as num?)?.toInt() ?? (json['item_id'] as num?)?.toInt() ?? 0,
      slot: equipped['slot']?.toString(),
      trigger: equipped['trigger']?.toString(),
      triggerValue: (equipped['trigger_value'] as num?)?.toDouble()
          ?? (json['trigger_value'] as num?)?.toDouble(),
      style: json['style'] as Map<String, dynamic>?,
    );
  }

  final int itemId;
  final String? slot;
  final String? trigger;
  final double? triggerValue;
  final Map<String, dynamic>? style;
}

