import 'package:flutter/material.dart';

import '../models/pet_state.dart';
import '../models/rive_input_value.dart';
import '../models/store_listing.dart';
import '../services/api_service.dart';
import '../widgets/item_asset_preview.dart';
import '../widgets/pet_avatar.dart';

Color _rarityAccent(String? rarity) {
  switch ((rarity ?? "").trim().toLowerCase()) {
    case "rare":
      return Colors.blue;
    case "epic":
      return Colors.deepPurple;
    case "legendary":
      return Colors.orange;
    case "common":
    default:
      return Colors.grey;
  }
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.apiService,
    required this.onError,
    required this.pet,
    this.onBalanceChanged,
  });

  final ApiService apiService;
  final void Function(String message) onError;
  final PetState pet;
  final void Function(int balance)? onBalanceChanged;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _loading = true;
  String? _error;
  List<StoreListing> _listings = const [];
  int? _buyingListingId;
  int? _balance;

  @override
  void initState() {
    super.initState();
    _balance = widget.pet.coins;
    _loadStore();
  }

  @override
  void didUpdateWidget(covariant ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.coins != widget.pet.coins && widget.pet.coins != _balance) {
      setState(() => _balance = widget.pet.coins);
    }
  }

  Future<void> _loadStore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await widget.apiService.fetchStoreListings();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _listings = response.data!;
        _loading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? "Failed to load store";
        _loading = false;
      });
    }
  }

  Future<void> _buy(StoreListing listing) async {
    if (_buyingListingId != null) return;
    setState(() => _buyingListingId = listing.id);
    final response = await widget.apiService.buyStoreListing(listing.id);
    if (!mounted) return;
    setState(() => _buyingListingId = null);

    if (response.isSuccess && response.data != null) {
      final result = response.data!;
      setState(() => _balance = result.remainingCoins);
      widget.onBalanceChanged?.call(result.remainingCoins);

      setState(() {
        _listings = _listings.map((entry) {
          if (entry.id != listing.id) return entry;
          var ownedQuantity = entry.ownedQuantity + result.quantity;
          final maxQuantity = entry.item.maxQuantity;
          if (maxQuantity != null && ownedQuantity > maxQuantity) {
            ownedQuantity = maxQuantity;
          }
          final isMaxed = maxQuantity != null && ownedQuantity >= maxQuantity;

          var updated = entry.copyWith(
            ownedQuantity: ownedQuantity,
            isMaxed: isMaxed,
          );

          if (entry.stock != null && result.stockRemaining != null) {
            updated = updated.copyWith(stock: result.stockRemaining);
          }

          return updated;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Purchased ${listing.item.name}!")),
      );
    } else {
      widget.onError(response.error ?? "Purchase failed");
    }
  }

  Future<void> _preview(StoreListing listing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemPreviewSheet(
        pet: widget.pet,
        listing: listing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _errorPlaceholder(_error!);
    }

    return RefreshIndicator(
      onRefresh: _loadStore,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.64,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final listing = _listings[index];
                  return _StoreListingCard(
                    listing: listing,
                    pet: widget.pet,
                    buying: _buyingListingId == listing.id,
                    onBuy: () => _buy(listing),
                    onPreview: () => _preview(listing),
                  );
                },
                childCount: _listings.length,
              ),
            ),
          ),
          if (_listings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  "No items for sale right now.",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final balance = _balance ?? widget.pet.coins;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Store",
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.monetization_on_outlined,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$balance",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadStore,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Refresh"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Tap Buy to add items to your inventory.",
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _errorPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_mall_directory_outlined, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadStore,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreListingCard extends StatelessWidget {
  const _StoreListingCard({
    required this.listing,
    required this.pet,
    required this.onBuy,
    required this.onPreview,
    this.buying = false,
  });

  final StoreListing listing;
  final PetState pet;
  final VoidCallback onBuy;
  final VoidCallback onPreview;
  final bool buying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = listing.item;
    final isCoinCurrency = listing.currency.trim().toLowerCase() == "coins";
    final disabled = buying || !listing.canBuy;
    final owned = listing.isMaxed;

    final maxQuantity = item.maxQuantity;
    final ownedQuantity = listing.ownedQuantity;

    String buttonLabel;
    if (buying) {
      buttonLabel = "Buying...";
    } else if (owned) {
      buttonLabel = "Owned";
    } else if (!listing.isInStock) {
      buttonLabel = "Sold out";
    } else {
      buttonLabel = "Buy";
    }

    return InkWell(
      onTap: disabled ? null : onBuy,
      onLongPress: onPreview,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: owned ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Opacity(
          opacity: owned ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ItemAssetPreview(
                        assetPath: item.assetPath,
                        assetType: item.assetType,
                        placeholderIcon: Icons.shopping_bag_rounded,
                        placeholderIconSize: 40,
                      ),
                      if (buying)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description.isNotEmpty ? item.description : (item.type.isNotEmpty ? item.type : "Item"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isCoinCurrency) ...[
                      Icon(
                        Icons.monetization_on_outlined,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      "${listing.price}",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!isCoinCurrency) ...[
                      const SizedBox(width: 4),
                      Text(
                        listing.currency,
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        if (maxQuantity != null && maxQuantity > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: listing.isMaxed
                                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "Owned $ownedQuantity/$maxQuantity",
                              style: TextStyle(
                                color: listing.isMaxed ? theme.colorScheme.primary : Colors.grey.shade700,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (listing.stock != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "Stock ${listing.stock}",
                              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPreview,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Preview"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: disabled ? null : onBuy,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.92),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(buttonLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemPreviewSheet extends StatelessWidget {
  const _ItemPreviewSheet({
    required this.pet,
    required this.listing,
  });

  final PetState pet;
  final StoreListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = listing.item;
    final styleInput = RiveInputValue.fromTriggerValue(item.trigger, item.triggerValue);
    final hasStyleInput = styleInput != null;
    final accent = _rarityAccent(item.rarity);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Preview",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.name,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        accent.withValues(alpha: 0.08),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                      child: !hasStyleInput
                          ? ItemAssetPreview(
                              assetPath: item.assetPath,
                              assetType: item.assetType,
                              placeholderIcon: Icons.shopping_bag_rounded,
                            )
                          : PetAvatar(
                              stage: pet.stage,
                              level: pet.level,
                              petType: pet.petType,
                              currentSprite: pet.currentSprite,
                              styleTriggers: [styleInput!],
                              showCosmetics: false,
                            ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
                !hasStyleInput
                  ? "No pet preview available for this item."
                  : "This is just a preview — it won't equip the item.",
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
