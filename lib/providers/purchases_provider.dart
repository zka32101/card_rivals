import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchases_service.dart';

// Purchases 初期化
final purchasesInitProvider = FutureProvider<void>((ref) async {
  await PurchasesService.initialize();
});

// 利用可能な商品一覧
final availablePackagesProvider = FutureProvider<List<Package>>((ref) async {
  // 初期化を待つ
  await ref.watch(purchasesInitProvider.future);
  return PurchasesService.getAvailablePackages();
});

// ユーザーの購入情報
final customerInfoProvider = FutureProvider<CustomerInfo>((ref) async {
  return PurchasesService.getCustomerInfo();
});

// アクティブなサブスクリプション確認
final hasActiveSubscriptionProvider = FutureProvider<bool>((ref) async {
  return PurchasesService.hasActiveSubscription();
});

// 広告削除状態確認
final hasAdsRemovedProvider = FutureProvider<bool>((ref) async {
  return PurchasesService.hasAdsRemoved();
});

// 購入処理（StateNotifier）
final purchaseProvider =
    StateNotifierProvider<PurchaseNotifier, AsyncValue<bool>>(
  (ref) => PurchaseNotifier(),
);

class PurchaseNotifier extends StateNotifier<AsyncValue<bool>> {
  PurchaseNotifier() : super(const AsyncValue.data(false));

  Future<void> purchasePackage(Package package) async {
    state = const AsyncValue.loading();
    try {
      final success = await PurchasesService.purchasePackage(package);
      state = AsyncValue.data(success);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void reset() {
    state = const AsyncValue.data(false);
  }
}

// コイン購入パッケージ定義
final coinPackagesProvider = Provider<List<CoinPackageData>>((ref) {
  return [
    CoinPackageData(
      productId: 'coins100',
      coins: 100,
      price: '\$1.00',
      discount: 0.0,
    ),
    CoinPackageData(
      productId: 'coins500',
      coins: 500,
      price: '\$4.50',
      discount: 0.09,
    ),
    CoinPackageData(
      productId: 'coins1000',
      coins: 1000,
      price: '\$8.00',
      discount: 0.20,
    ),
  ];
});

// サブスクリプションパッケージ定義
final subscriptionPackagesProvider = Provider<List<SubscriptionPackageData>>((ref) {
  return [
    SubscriptionPackageData(
      productId: 'premium-monthly',
      price: '\$3.00/月',
      features: [
        '広告削除',
        '追加カード',
        'ランク報酬2倍',
      ],
    ),
    SubscriptionPackageData(
      productId: 'premium-yearly',
      price: '\$24.00/年',
      features: [
        '広告削除',
        '追加カード',
        'ランク報酬2倍',
      ],
    ),
  ];
});

// データモデル
class CoinPackageData {
  final String productId;
  final int coins;
  final String price;
  final double discount;

  CoinPackageData({
    required this.productId,
    required this.coins,
    required this.price,
    required this.discount,
  });

  double get costPerCoin => double.parse(price.replaceAll('\$', '')) / coins;
}

class SubscriptionPackageData {
  final String productId;
  final String price;
  final List<String> features;

  SubscriptionPackageData({
    required this.productId,
    required this.price,
    required this.features,
  });
}

class CustomerInfo {
  final bool hasActiveSubscription;
  final bool hasAdsRemoved;
  final Set<String> activeEntitlements;

  const CustomerInfo({
    required this.hasActiveSubscription,
    required this.hasAdsRemoved,
    required this.activeEntitlements,
  });
}
