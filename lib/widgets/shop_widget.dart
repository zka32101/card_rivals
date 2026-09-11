import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/purchases_provider.dart';

class ShopWidget extends HookConsumerWidget {
  const ShopWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(availablePackagesProvider);
    final purchaseState = ref.watch(purchaseProvider);
    final coinPackages = ref.watch(coinPackagesProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // タブバー
          TabBar(
            tabs: const [
              Tab(text: 'コイン'),
              Tab(text: 'プレミアム'),
            ],
          ),
          // タブコンテンツ
          Expanded(
            child: TabBarView(
              children: [
                // コインタブ
                packagesAsync.when(
                  data: (packages) => _CoinShop(
                    packages: packages,
                    purchaseState: purchaseState,
                    onPurchase: (package) {
                      ref.read(purchaseProvider.notifier).purchasePackage(package);
                    },
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, stack) => Center(
                    child: Text('エラー: $err'),
                  ),
                ),
                // プレミアムタブ
                packagesAsync.when(
                  data: (packages) => _SubscriptionShop(
                    packages: packages,
                    purchaseState: purchaseState,
                    onPurchase: (package) {
                      ref.read(purchaseProvider.notifier).purchasePackage(package);
                    },
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, stack) => Center(
                    child: Text('エラー: $err'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// コインショップ
class _CoinShop extends HookConsumerWidget {
  final List<Package> packages;
  final AsyncValue<bool> purchaseState;
  final Function(Package) onPurchase;

  const _CoinShop({
    required this.packages,
    required this.purchaseState,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coinPackages = ref.watch(coinPackagesProvider);

    return ListView.builder(
      itemCount: coinPackages.length,
      itemBuilder: (context, index) {
        final coinPkg = coinPackages[index];
        final googlePkg = packages.firstWhere(
          (p) => p.identifier == coinPkg.productId,
          orElse: () => packages.first,
        );

        return _CoinCard(
          coinPackage: coinPkg,
          googlePackage: googlePkg,
          isLoading: purchaseState.isLoading,
          onTap: () => onPurchase(googlePkg),
        );
      },
    );
  }
}

// コインカード
class _CoinCard extends StatelessWidget {
  final CoinPackageData coinPackage;
  final Package googlePackage;
  final bool isLoading;
  final VoidCallback onTap;

  const _CoinCard({
    required this.coinPackage,
    required this.googlePackage,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // コイン数
            Text(
              '${coinPackage.coins} Coins',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // 価格
            Text(
              coinPackage.price,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            // 割引バッジ
            if (coinPackage.discount > 0)
              Chip(
                label: Text(
                  '${(coinPackage.discount * 100).toStringAsFixed(0)}% OFF',
                ),
                backgroundColor: Colors.green,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            const SizedBox(height: 8),
            // 1コイン当たりの価格
            Text(
              '1コイン: \$${coinPackage.costPerCoin.toStringAsFixed(4)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            // 購入ボタン
            ElevatedButton(
              onPressed: isLoading ? null : onTap,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('購入'),
            ),
          ],
        ),
      ),
    );
  }
}

// プレミアムショップ
class _SubscriptionShop extends HookConsumerWidget {
  final List<Package> packages;
  final AsyncValue<bool> purchaseState;
  final Function(Package) onPurchase;

  const _SubscriptionShop({
    required this.packages,
    required this.purchaseState,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subPackages = ref.watch(subscriptionPackagesProvider);

    return ListView.builder(
      itemCount: subPackages.length,
      itemBuilder: (context, index) {
        final subPkg = subPackages[index];
        final googlePkg = packages.firstWhere(
          (p) => p.identifier == subPkg.productId,
          orElse: () => packages.first,
        );

        return _SubscriptionCard(
          subscriptionPackage: subPkg,
          googlePackage: googlePkg,
          isLoading: purchaseState.isLoading,
          onTap: () => onPurchase(googlePkg),
        );
      },
    );
  }
}

// サブスクリプションカード
class _SubscriptionCard extends StatelessWidget {
  final SubscriptionPackageData subscriptionPackage;
  final Package googlePackage;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubscriptionCard({
    required this.subscriptionPackage,
    required this.googlePackage,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトルと価格
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subscriptionPackage.productId.contains('yearly')
                      ? 'プレミアム年間'
                      : 'プレミアム月間',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subscriptionPackage.price,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 機能リスト
            ...subscriptionPackage.features
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(feature),
                      ],
                    ),
                  ),
                )
                .toList(),
            const SizedBox(height: 16),
            // 購入ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onTap,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('購入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
