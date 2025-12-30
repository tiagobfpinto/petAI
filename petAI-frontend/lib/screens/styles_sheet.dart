import 'package:flutter/material.dart';

import '../models/rive_input_value.dart';
import '../models/style_inventory_item.dart';
import '../services/api_service.dart';
import '../widgets/item_asset_preview.dart';

class StylesSheet extends StatefulWidget {
  const StylesSheet({
    super.key,
    required this.apiService,
    required this.onError,
    this.onTrigger,
    this.onEquipped,
  });

  final ApiService apiService;
  final void Function(String message) onError;
  final void Function(RiveInputValue input)? onTrigger;
  final VoidCallback? onEquipped;

  @override
  State<StylesSheet> createState() => _StylesSheetState();
}

class _StylesSheetState extends State<StylesSheet> {
  bool _loading = true;
  String? _error;
  List<StyleInventoryItem> _items = const [];
  int? _equippingItemId;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await widget.apiService.fetchStyleInventory();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _items = response.data!;
        _loading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? "Failed to load inventory";
        _loading = false;
      });
    }
  }

  Future<void> _equip(StyleInventoryItem item) async {
    if (_equippingItemId != null) return;
    setState(() => _equippingItemId = item.itemId);
    final response = await widget.apiService.equipStyleItem(item.itemId);
    if (!mounted) return;
    setState(() => _equippingItemId = null);

    if (response.isSuccess) {
      final triggerName = (item.trigger ?? "").trim().isNotEmpty
          ? item.trigger
          : response.data?.trigger;
      final triggerValue = item.triggerValue ?? response.data?.triggerValue;
      final triggerInput = RiveInputValue.fromTriggerValue(triggerName, triggerValue);
      if (triggerInput != null) {
        widget.onTrigger?.call(triggerInput);
      }
      widget.onEquipped?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipped ${item.name}')),
      );
    } else {
      widget.onError(response.error ?? "Failed to equip item");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.75;
    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
            Row(
              children: [
                Text(
                  "Styles",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _loadInventory,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text("Retry"),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  "No items yet. Buy something in the store!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            )
                          : GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.9,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final isEquipping = _equippingItemId == item.itemId;
                                return _InventoryCard(
                                  item: item,
                                  isBusy: isEquipping,
                                  onTap: () => _equip(item),
                                );
                              },
                            ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.onTap,
    this.isBusy = false,
  });

  final StyleInventoryItem item;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = (item.type).toString().trim();
    final preview = ItemAssetPreview(
      assetPath: item.assetPath,
      assetType: item.assetType,
      placeholderIcon: Icons.checkroom_rounded,
      placeholderIconSize: 38,
    );

    return InkWell(
      onTap: isBusy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    if (isBusy)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
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
              const SizedBox(height: 10),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle.isNotEmpty ? subtitle : "Item",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (item.quantity > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "x${item.quantity}",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
