import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CoinPackage {
  const CoinPackage({
    required this.id,
    required this.coins,
    required this.priceLabel,
    this.bonusLabel,
    this.highlight = false,
  });

  final String id;
  final int coins;
  final String priceLabel;
  final String? bonusLabel;
  final bool highlight;
}

class CoinStoreScreen extends StatefulWidget {
  const CoinStoreScreen({
    super.key,
    required this.apiService,
    required this.currentBalance,
    required this.onBalanceUpdated,
  });

  final ApiService apiService;
  final int currentBalance;
  final void Function(int newBalance) onBalanceUpdated;

  static final List<CoinPackage> _packages = [
    const CoinPackage(id: "pack_small", coins: 260, priceLabel: "€2.49"),
    const CoinPackage(id: "pack_medium", coins: 550, priceLabel: "€4.99", bonusLabel: "+10%"),
    const CoinPackage(
      id: "pack_large",
      coins: 1200,
      priceLabel: "€9.99",
      bonusLabel: "+20%",
      highlight: true,
    ),
    const CoinPackage(
      id: "pack_mega",
      coins: 2500,
      priceLabel: "€18.99",
      bonusLabel: "+30%",
    ),
  ];

  @override
  State<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends State<CoinStoreScreen> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buy coins"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _balanceCard(theme),
          const SizedBox(height: 16),
          ...CoinStoreScreen._packages.map((pack) => _packageTile(context, pack)),
          const SizedBox(height: 12),
          Text(
            "Purchases are mocked for now. Hook up to your payment provider when ready.",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monetization_on_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current balance",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.currentBalance} coins",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
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

  Widget _packageTile(BuildContext context, CoinPackage pack) {
    final theme = Theme.of(context);
    final color = pack.highlight ? theme.colorScheme.primary : Colors.grey.shade800;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pack.highlight ? theme.colorScheme.primary.withValues(alpha: 0.35) : Colors.grey.shade200,
          width: pack.highlight ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${pack.coins}c",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (pack.bonusLabel != null)
                  Text(
                    pack.bonusLabel!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.priceLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "One-time pack • No subscription",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _processing ? null : () => _confirmPurchase(context, pack),
            child: const Text("Buy"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurchase(BuildContext context, CoinPackage pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm purchase"),
        content: Text("Add ${pack.coins} coins for ${pack.priceLabel}? (mock purchase)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _processing = true);
      final response = await widget.apiService.purchaseCoinPack(pack.id);
      if (!mounted) return;
      setState(() => _processing = false);
      if (response.isSuccess && response.data != null) {
        widget.onBalanceUpdated(response.data!);
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("+${pack.coins} coins added to your wallet")),
        );
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error ?? "Purchase failed")),
        );
      }
    }
  }
}
