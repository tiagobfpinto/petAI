import 'package:flutter/material.dart';

import '../data/cosmetic_catalog.dart';
import '../models/cosmetics.dart';
import '../models/shop.dart';
import '../services/api_service.dart';
import '../utils/test_coins.dart';
import '../widgets/cosmetic_art.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.apiService,
    required this.onError,
    this.onBalanceChanged,
    this.petCoins,
    this.onCosmeticsChanged,
  });

  final ApiService apiService;
  final void Function(String message) onError;
  final void Function(int balance)? onBalanceChanged;
  final int? petCoins;
  final void Function(PetCosmeticLoadout loadout)? onCosmeticsChanged;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ShopState? _state;
  bool _loading = true;
  String? _buyingId;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void didUpdateWidget(covariant ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_state != null &&
        widget.petCoins != null &&
        widget.petCoins != _state!.balance) {
      setState(() {
        _state = ShopState(
          balance: widget.petCoins!,
          items: _state!.items,
          equippedCosmetics: _state!.equippedCosmetics,
        );
      });
    }
  }

  Future<void> _loadShop() async {
    setState(() => _loading = true);
    final response = await widget.apiService.fetchShop();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _state = response.data;
        _loading = false;
      });
      widget.onBalanceChanged?.call(response.data!.balance);
      widget.onCosmeticsChanged?.call(response.data!.equippedCosmetics);
    } else {
      setState(() => _loading = false);
      widget.onError(response.error ?? "Failed to load shop");
    }
  }

  Future<void> _purchase(ShopItem item) async {
    if (item.owned) return;
    setState(() => _buyingId = item.id);
    final response = await widget.apiService.purchaseItem(item.id);
    if (!mounted) return;
    setState(() => _buyingId = null);
    if (response.isSuccess && response.data != null) {
      setState(() => _state = response.data);
      widget.onBalanceChanged?.call(response.data!.balance);
      widget.onCosmeticsChanged?.call(response.data!.equippedCosmetics);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Purchased ${item.name}!")),
      );
    } else {
      final errorText = (response.error ?? "").toLowerCase();
      final insufficient = errorText.contains("insufficient") || errorText.contains("not enough");
      if (insufficient && spendTestCoins(item.price) && _state != null) {
        final updatedBalance = (_state!.balance - item.price).clamp(0, 1 << 31);
        final currentLoadout = _state!.equippedCosmetics;
        final newLoadout =
            item.slot != null ? currentLoadout.copyWithSlot(item.slot!, item.id) : currentLoadout;
        final updatedItems = _state!.items.map((i) {
          final isEquipped = i.slot != null && newLoadout.itemForSlot(i.slot!) == i.id;
          final isOwned = i.id == item.id ? true : i.owned;
          return ShopItem(
            id: i.id,
            name: i.name,
            price: i.price,
            rarity: i.rarity,
            tag: i.tag,
            description: i.description,
            accent: i.accent,
            owned: isOwned,
            slot: i.slot,
            imageKey: i.imageKey,
            equipped: isEquipped,
            type: i.type,
          );
        }).toList();
        final fallbackState = ShopState(
          balance: updatedBalance,
          items: updatedItems,
          equippedCosmetics: newLoadout,
        );
        setState(() => _state = fallbackState);
        widget.onBalanceChanged?.call(updatedBalance);
        widget.onCosmeticsChanged?.call(newLoadout);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Purchased ${item.name}! (mock spend)")),
        );
      } else {
        widget.onError(response.error ?? "Could not complete purchase");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state == null) {
      return _errorPlaceholder();
    }

    return RefreshIndicator(
      onRefresh: _loadShop,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _balanceCard(context),
          const SizedBox(height: 16),
          _catalogGrid(),
        ],
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Shop is resting. Pull to retry."),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadShop,
            child: const Text("Try again"),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(BuildContext context) {
    final theme = Theme.of(context);
    final balance = widget.petCoins ?? _state?.balance ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.9),
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "petAI Shop",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Curated boosts and cosmetics for your buddy.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Coins",
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  balance.toString(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catalogGrid() {
    final items = _state?.items ?? [];
    if (items.isEmpty) {
      return const Text("No items available right now.");
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final itemWidth = (maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _shopItemCard(item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _shopItemCard(ShopItem item) {
    final theme = Theme.of(context);
    final isBuying = _buyingId == item.id;
    final owned = item.owned;
    final equipped = _state?.isEquipped(item) ?? item.equipped;
    final artKey =
        item.imageKey ?? CosmeticCatalog.definitionFor(item.id)?.previewKey ?? item.slotLabel ?? item.id;
    final slotLabel = item.slotLabel?.toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: owned
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.tag.isNotEmpty ? item.tag : (slotLabel ?? "Cosmetic"),
                  style: TextStyle(
                    color: item.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (equipped)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Equipped",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  item.rarityLabel,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: CosmeticPreview(
              artKey: artKey,
              color: item.accentColor,
              size: 90,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (slotLabel != null) ...[
            Text(
              "Slot: $slotLabel",
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            item.description,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item.price}c",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (equipped)
                    Text(
                      "Active on pet",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: (owned || isBuying) ? null : () => _purchase(item),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  backgroundColor: owned
                      ? Colors.grey.shade300
                      : theme.colorScheme.primary.withValues(alpha: 0.9),
                  foregroundColor: owned ? Colors.grey.shade800 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isBuying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(owned ? (equipped ? "Equipped" : "Owned") : "Buy"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
