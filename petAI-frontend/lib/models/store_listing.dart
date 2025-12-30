class StoreItem {
  const StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.assetType,
    this.assetPath,
    this.layerName,
    this.rarity,
    this.trigger,
    this.triggerValue,
    this.maxQuantity,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: (json["id"] as num?)?.toInt() ?? 0,
      name: json["name"] as String? ?? "Item",
      description: json["description"] as String? ?? "",
      type: json["type"]?.toString() ?? "",
      assetType: json["asset_type"]?.toString(),
      assetPath: json["asset_path"]?.toString(),
      layerName: json["layer_name"]?.toString(),
      rarity: json["rarity"]?.toString(),
      trigger: json["trigger"]?.toString(),
      triggerValue: (json["trigger_value"] as num?)?.toDouble(),
      maxQuantity: (json["max_quantity"] as num?)?.toInt(),
    );
  }

  final int id;
  final String name;
  final String description;
  final String type;
  final String? assetType;
  final String? assetPath;
  final String? layerName;
  final String? rarity;
  final String? trigger;
  final double? triggerValue;
  final int? maxQuantity;

  bool get hasAssetPath => (assetPath ?? "").trim().isNotEmpty;
}

class StoreListing {
  const StoreListing({
    required this.id,
    required this.price,
    required this.item,
    this.stock,
    this.currency = "coins",
    this.ownedQuantity = 0,
    this.isMaxed = false,
  });

  factory StoreListing.fromJson(Map<String, dynamic> json) {
    return StoreListing(
      id: (json["id"] as num?)?.toInt() ?? 0,
      price: (json["price"] as num?)?.toInt() ?? 0,
      stock: (json["stock"] as num?)?.toInt(),
      currency: json["currency"]?.toString() ?? "coins",
      ownedQuantity: (json["owned_quantity"] as num?)?.toInt() ?? 0,
      isMaxed: json["is_maxed"] as bool? ?? false,
      item: StoreItem.fromJson(json["item"] as Map<String, dynamic>? ?? {}),
    );
  }

  final int id;
  final int price;
  final int? stock;
  final String currency;
  final StoreItem item;
  final int ownedQuantity;
  final bool isMaxed;

  bool get isInStock => stock == null || stock! > 0;

  bool get canBuy => isInStock && !isMaxed;

  StoreListing copyWith({
    int? stock,
    int? ownedQuantity,
    bool? isMaxed,
  }) {
    return StoreListing(
      id: id,
      price: price,
      item: item,
      stock: stock ?? this.stock,
      currency: currency,
      ownedQuantity: ownedQuantity ?? this.ownedQuantity,
      isMaxed: isMaxed ?? this.isMaxed,
    );
  }
}

class StorePurchaseResult {
  const StorePurchaseResult({
    required this.listingId,
    required this.itemId,
    required this.quantity,
    required this.remainingCoins,
    this.stockRemaining,
  });

  factory StorePurchaseResult.fromJson(Map<String, dynamic> json) {
    return StorePurchaseResult(
      listingId: (json["listing_id"] as num?)?.toInt() ?? 0,
      itemId: (json["item_id"] as num?)?.toInt() ?? 0,
      quantity: (json["quantity"] as num?)?.toInt() ?? 0,
      remainingCoins: (json["remaining_coins"] as num?)?.toInt() ?? 0,
      stockRemaining: (json["stock_remaining"] as num?)?.toInt(),
    );
  }

  final int listingId;
  final int itemId;
  final int quantity;
  final int remainingCoins;
  final int? stockRemaining;
}
