class StyleInventoryItem {
  const StyleInventoryItem({
    required this.ownershipId,
    required this.itemId,
    required this.quantity,
    required this.name,
    required this.description,
    required this.type,
    this.assetType,
    this.assetPath,
    this.layerName,
    this.rarity,
    this.trigger,
    this.triggerValue,
  });

  factory StyleInventoryItem.fromJson(Map<String, dynamic> json) {
    return StyleInventoryItem(
      ownershipId: (json['ownership_id'] as num?)?.toInt() ?? 0,
      itemId: (json['item_id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Item',
      description: json['description'] as String? ?? '',
      type: json['type']?.toString() ?? '',
      assetType: json['asset_type']?.toString(),
      assetPath: json['asset_path']?.toString(),
      layerName: json['layer_name']?.toString(),
      rarity: json['rarity']?.toString(),
      trigger: json['trigger']?.toString(),
      triggerValue: (json['trigger_value'] as num?)?.toDouble(),
    );
  }

  final int ownershipId;
  final int itemId;
  final int quantity;
  final String name;
  final String description;
  final String type;
  final String? assetType;
  final String? assetPath;
  final String? layerName;
  final String? rarity;
  final String? trigger;
  final double? triggerValue;

  bool get hasAssetPath => (assetPath ?? '').trim().isNotEmpty;
}

