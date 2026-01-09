class ChestInventoryItem {
  const ChestInventoryItem({
    required this.itemId,
    required this.tier,
    this.quantity = 1,
    this.name,
    this.description,
    this.assetPath,
    this.assetType,
    this.ownershipId,
  });

  final int itemId;
  final String tier;
  final int quantity;
  final String? name;
  final String? description;
  final String? assetPath;
  final String? assetType;
  final int? ownershipId;

  static ChestInventoryItem? fromGrantJson(Map<String, dynamic> json) {
    final chest = json["chest"] as Map<String, dynamic>?;
    if (chest == null) return null;
    final itemId = (chest["item_id"] as num?)?.toInt() ?? 0;
    if (itemId <= 0) return null;
    final tier = (json["chest_tier"] ?? chest["tier"] ?? "common").toString();
    return ChestInventoryItem(
      itemId: itemId,
      tier: tier,
      quantity: 1,
      name: chest["name"] as String?,
      description: chest["description"] as String?,
      assetPath: chest["asset_path"] as String?,
      assetType: chest["asset_type"] as String?,
      ownershipId: (chest["ownership_id"] as num?)?.toInt(),
    );
  }

  factory ChestInventoryItem.fromListEntry(Map<String, dynamic> json) {
    return ChestInventoryItem(
      itemId: (json["item_id"] as num?)?.toInt() ?? 0,
      tier: (json["tier"] ?? "common").toString(),
      quantity: (json["quantity"] as num?)?.toInt() ?? 1,
      name: json["name"] as String?,
      description: json["description"] as String?,
      assetPath: json["asset_path"] as String?,
      assetType: json["asset_type"] as String?,
      ownershipId: (json["ownership_id"] as num?)?.toInt(),
    );
  }

  ChestInventoryItem copyWith({int? quantity}) {
    return ChestInventoryItem(
      itemId: itemId,
      tier: tier,
      quantity: quantity ?? this.quantity,
      name: name,
      description: description,
      assetPath: assetPath,
      assetType: assetType,
      ownershipId: ownershipId,
    );
  }
}
