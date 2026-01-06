import "package:flutter/material.dart";

import "../models/user_summary.dart";
import "../services/admin_api_service.dart";

class UserDetailPanel extends StatefulWidget {
  const UserDetailPanel({
    super.key,
    required this.user,
    required this.api,
    required this.onUserUpdated,
  });

  final UserSummary user;
  final AdminApiService api;
  final ValueChanged<UserSummary> onUserUpdated;

  @override
  State<UserDetailPanel> createState() => _UserDetailPanelState();
}

class _UserDetailPanelState extends State<UserDetailPanel> {
  final _coinsController = TextEditingController();
  final _deltaController = TextEditingController();
  final _quantityController = TextEditingController(text: "1");
  final _itemIdController = TextEditingController();

  String _selectedTier = "any";
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _syncCoins();
  }

  @override
  void didUpdateWidget(covariant UserDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.coins != widget.user.coins) {
      _syncCoins();
    }
  }

  @override
  void dispose() {
    _coinsController.dispose();
    _deltaController.dispose();
    _quantityController.dispose();
    _itemIdController.dispose();
    super.dispose();
  }

  void _syncCoins() {
    _coinsController.text = widget.user.coins.toString();
  }

  Future<void> _setCoins() async {
    final value = int.tryParse(_coinsController.text.trim());
    if (value == null) {
      _notify("Enter a valid coins value.");
      return;
    }
    await _runBusy(() async {
      final result = await widget.api.updateCoins(
        userId: widget.user.id,
        coins: value,
      );
      if (!result.isSuccess) {
        _notify(result.error ?? "Failed to update coins.");
        return;
      }
      _notify("Coins updated to ${result.data}.");
      widget.onUserUpdated(widget.user.copyWith(coins: result.data ?? value));
    });
  }

  Future<void> _adjustCoins() async {
    final value = int.tryParse(_deltaController.text.trim());
    if (value == null) {
      _notify("Enter a valid coin delta.");
      return;
    }
    await _runBusy(() async {
      final result = await widget.api.updateCoins(
        userId: widget.user.id,
        delta: value,
      );
      if (!result.isSuccess) {
        _notify(result.error ?? "Failed to update coins.");
        return;
      }
      _notify("Coins adjusted. New balance: ${result.data}.");
      widget.onUserUpdated(
        widget.user.copyWith(coins: result.data ?? widget.user.coins),
      );
    });
  }

  Future<void> _grantChests() async {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity <= 0) {
      _notify("Quantity must be greater than zero.");
      return;
    }
    final itemIdText = _itemIdController.text.trim();
    final itemId = itemIdText.isEmpty ? null : int.tryParse(itemIdText);
    if (itemIdText.isNotEmpty && itemId == null) {
      _notify("Chest item id must be a number.");
      return;
    }
    final tier = _selectedTier == "any" ? null : _selectedTier;
    await _runBusy(() async {
      final result = await widget.api.grantChests(
        userId: widget.user.id,
        quantity: quantity,
        tier: tier,
        itemId: itemId,
      );
      if (!result.isSuccess) {
        _notify(result.error ?? "Failed to grant chests.");
        return;
      }
      final data = result.data ?? {};
      final grantedQty = data["quantity"] ?? quantity;
      _notify("Granted $grantedQty chest(s).");
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "User #${user.id}",
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _detailRow("Username", user.username ?? "—"),
          _detailRow("Email", user.email ?? "—"),
          _detailRow("Full name", user.fullName ?? "—"),
          _detailRow("Plan", user.plan ?? "—"),
          _detailRow(
            "Status",
            user.isActive ? "Active" : "Inactive",
          ),
          _detailRow("Guest", user.isGuest ? "Yes" : "No"),
          _detailRow(
            "Created",
            _formatDate(user.createdAt),
          ),
          _detailRow("Activity count", user.activityCount.toString()),
          const Divider(height: 32),
          Text("Coins", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _coinsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Set balance",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _busy ? null : _setCoins,
                child: const Text("Set"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deltaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Adjust by (+/-)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _busy ? null : _adjustCoins,
                child: const Text("Apply"),
              ),
            ],
          ),
          const Divider(height: 32),
          Text("Grant chests", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Quantity",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTier,
                  decoration: const InputDecoration(
                    labelText: "Tier",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "any", child: Text("Any")),
                    DropdownMenuItem(value: "common", child: Text("Common")),
                    DropdownMenuItem(value: "rare", child: Text("Rare")),
                    DropdownMenuItem(value: "epic", child: Text("Epic")),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedTier = value;
                          });
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _itemIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Specific chest item id (optional)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _grantChests,
              icon: const Icon(Icons.card_giftcard),
              label: const Text("Grant chests"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "—";
    final local = date.toLocal();
    return "${local.year}-${_two(local.month)}-${_two(local.day)} "
        "${_two(local.hour)}:${_two(local.minute)}";
  }

  String _two(int value) => value.toString().padLeft(2, "0");
}
