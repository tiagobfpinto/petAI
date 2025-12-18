class StyleEquipResult {
  const StyleEquipResult({
    required this.itemId,
    this.slot,
    this.trigger,
    this.style,
  });

  factory StyleEquipResult.fromJson(Map<String, dynamic> json) {
    final equipped = json['equipped'] as Map<String, dynamic>? ?? {};
    return StyleEquipResult(
      itemId: (equipped['item_id'] as num?)?.toInt() ?? (json['item_id'] as num?)?.toInt() ?? 0,
      slot: equipped['slot']?.toString(),
      trigger: equipped['trigger']?.toString(),
      style: json['style'] as Map<String, dynamic>?,
    );
  }

  final int itemId;
  final String? slot;
  final String? trigger;
  final Map<String, dynamic>? style;
}

