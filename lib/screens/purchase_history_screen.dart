import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchase_service.dart';
import '../theme/kingdom_theme.dart';
import '../utils/safe_pop.dart';
import '../l10n/app_localizations.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<StoreTransaction>? _transactions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await PurchaseService.getPurchaseHistory();
      // 新しい順に並べる（purchaseDateはISO8601文字列）
      list.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      if (!mounted) return;
      setState(() => _transactions = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  String _productLabel(AppLocalizations t, String productId) => switch (productId) {
        'starter_pack' => t.shop_purchaseHistoryStarterPack,
        'coin_100' => t.shop_purchaseHistoryCoin100,
        'coin_500' => t.shop_purchaseHistoryCoin500,
        'coin_1200' => t.shop_purchaseHistoryCoin1200,
        'gem_10' => t.shop_purchaseHistoryGem10,
        'gem_50' => t.shop_purchaseHistoryGem50,
        'gem_120' => t.shop_purchaseHistoryGem120,
        _ => productId,
      };

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${p2(local.month)}/${p2(local.day)} ${p2(local.hour)}:${p2(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.settings_purchaseHistory, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Kingdom.gilt),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          SafeArea(child: _buildBody(t)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations t) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Kingdom.spaceXl),
          child: Text(t.purchaseHistory_loadError,
              style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7)), textAlign: TextAlign.center),
        ),
      );
    }
    if (_transactions == null) {
      return const Center(child: CircularProgressIndicator(color: Kingdom.gilt));
    }
    if (_transactions!.isEmpty) {
      return Center(
        child: Text(t.purchaseHistory_empty, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Kingdom.spaceLg),
      itemCount: _transactions!.length,
      separatorBuilder: (_, _) => const SizedBox(height: Kingdom.spaceMd),
      itemBuilder: (context, i) {
        final tx = _transactions![i];
        return OrnateFrame(
          accent: Kingdom.gilt,
          showCorners: false,
          padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceLg, vertical: Kingdom.spaceMd),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: Kingdom.gilt),
              const SizedBox(width: Kingdom.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_productLabel(t, tx.productIdentifier),
                        style: TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(_formatDate(tx.purchaseDate),
                        style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
