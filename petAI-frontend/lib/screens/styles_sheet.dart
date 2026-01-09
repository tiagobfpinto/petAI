import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/rive_input_value.dart';
import '../models/style_inventory_item.dart';
import '../services/api_service.dart';
import '../widgets/item_asset_preview.dart';

class _StyleCategory {
  const _StyleCategory({
    required this.label,
    required this.emptyLabel,
    required this.triggerName,
    required this.icon,
    required this.typeMatchers,
  });

  final String label;
  final String emptyLabel;
  final String triggerName;
  final IconData icon;
  final Set<String> typeMatchers;
}

const List<_StyleCategory> _styleCategories = [
  _StyleCategory(
    label: "Hats",
    emptyLabel: "hats",
    triggerName: "hat",
    icon: Icons.checkroom_rounded,
    typeMatchers: {"hat", "headwear", "head", "cap"},
  ),
  _StyleCategory(
    label: "Sunglasses",
    emptyLabel: "sunglasses",
    triggerName: "sunglasses",
    icon: Icons.visibility_rounded,
    typeMatchers: {"sunglasses", "glasses", "shade", "shades", "face", "sunglass"},
  ),
  _StyleCategory(
    label: "Background",
    emptyLabel: "backgrounds",
    triggerName: "background",
    icon: Icons.landscape_rounded,
    typeMatchers: {"background", "bg", "backdrop"},
  ),
  _StyleCategory(
    label: "Color",
    emptyLabel: "colors",
    triggerName: "color",
    icon: Icons.palette_rounded,
    typeMatchers: {"color", "colour"},
  ),
];

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

  List<StyleInventoryItem> _itemsForCategory(_StyleCategory category) {
    if (_items.isEmpty) return const [];
    return _items.where((item) => _matchesCategory(item, category)).toList();
  }

  bool _matchesCategory(StyleInventoryItem item, _StyleCategory category) {
    final type = item.type.trim().toLowerCase();
    if (type.isNotEmpty && category.typeMatchers.contains(type)) return true;

    bool containsMatch(String? value) {
      final normalized = (value ?? "").trim().toLowerCase();
      if (normalized.isEmpty) return false;
      for (final token in category.typeMatchers) {
        if (normalized.contains(token)) return true;
      }
      return false;
    }

    return containsMatch(item.layerName) ||
        containsMatch(item.trigger) ||
        containsMatch(item.name);
  }

  void _unequipCategory(_StyleCategory category) {
    final triggerName = category.triggerName.trim();
    if (triggerName.isEmpty || widget.onTrigger == null) return;
    widget.onTrigger?.call(RiveInputValue.number(triggerName, 0));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unequipped ${category.label.toLowerCase()}')),
    );
  }

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
      if (kDebugMode) {
        final itemTrigger = item.trigger ?? "";
        final itemValue = item.triggerValue?.toString() ?? "null";
        final responseTrigger = response.data?.trigger ?? "";
        final responseValue = response.data?.triggerValue?.toString() ?? "null";
        debugPrint(
          "[style] equip item=${item.itemId} name=\"${item.name}\" "
          "itemTrigger=\"$itemTrigger\" itemValue=$itemValue "
          "responseTrigger=\"$responseTrigger\" responseValue=$responseValue",
        );
      }
      final triggerName = (item.trigger ?? "").trim().isNotEmpty
          ? item.trigger
          : response.data?.trigger;
      final triggerValue = item.triggerValue ?? response.data?.triggerValue;
      final triggerInput = RiveInputValue.fromTriggerValue(triggerName, triggerValue);
      if (kDebugMode) {
        if (triggerInput == null) {
          debugPrint(
            "[style] equip item=${item.itemId} resolved trigger is empty "
            "(name=\"${triggerName ?? ""}\" value=${triggerValue?.toString() ?? "null"})",
          );
        } else {
          debugPrint(
            "[style] equip item=${item.itemId} resolved trigger=\"${triggerInput.name}\" "
            "value=${triggerInput.value?.toString() ?? "null"}",
          );
        }
      }
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

  Widget _buildCategoryTabs(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: [
          for (final category in _styleCategories)
            Tab(
              icon: Icon(category.icon, size: 18),
              text: category.label,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(_StyleCategory category) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
      );
    }

    final items = _itemsForCategory(category);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "No ${category.emptyLabel} yet. Buy something in the store!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isEquipping = _equippingItemId == item.itemId;
        return _InventoryCard(
          item: item,
          isBusy: isEquipping,
          onTap: () => _equip(item),
        );
      },
    );
  }

  Widget _buildCategoryTab(_StyleCategory category) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: widget.onTrigger == null ? null : () => _unequipCategory(category),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            label: const Text("Unequip"),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildCategoryContent(category)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.75;
    return DefaultTabController(
      length: _styleCategories.length,
      child: SizedBox(
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
                _buildCategoryTabs(theme),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      for (final category in _styleCategories)
                        _buildCategoryTab(category),
                    ],
                  ),
                ),
              ],
            ),
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
