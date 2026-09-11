import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  static const String _apiKey = 'goog_gBSlgBnofzpIFbHUgzEyfFLUSmb';

  // Product IDs
  static const String coins100 = 'coins100';
  static const String coins500 = 'coins500';
  static const String coins1000 = 'coins1000';
  static const String premiumMonthly = 'premium-monthly';
  static const String premiumYearly = 'premium-yearly';

  /// RevenueCat 初期化
  static Future<void> initialize() async {
    try {
      await Purchases.configure(
        PurchasesConfiguration(_apiKey),
      );
      print('✅ Purchases initialized');
    } catch (e) {
      print('❌ Purchases initialization error: $e');
      rethrow;
    }
  }

  /// 利用可能な商品を取得
  static Future<List<Package>> getAvailablePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? [];
      print('📦 Available packages: ${packages.length}');
      return packages;
    } catch (e) {
      print('❌ Get packages error: $e');
      return [];
    }
  }

  /// 商品を購入
  static Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      print('✅ Purchase successful: ${package.identifier}');
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        print('⚠️ Purchase cancelled by user');
      } else {
        print('❌ Purchase error: ${e.code}');
      }
      return false;
    } catch (e) {
      print('❌ Purchase error: $e');
      return false;
    }
  }

  /// ユーザーの購入状態を取得
  static Future<CustomerInfo> getCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final activeEntitlements = info.entitlements.active.keys.toSet();

      return CustomerInfo(
        hasActiveSubscription: activeEntitlements.isNotEmpty,
        hasAdsRemoved: activeEntitlements.contains('ad_free'),
        activeEntitlements: activeEntitlements,
      );
    } catch (e) {
      print('❌ Get customer info error: $e');
      return const CustomerInfo(
        hasActiveSubscription: false,
        hasAdsRemoved: false,
        activeEntitlements: {},
      );
    }
  }

  /// サブスクリプション確認
  static Future<bool> hasActiveSubscription() async {
    final info = await getCustomerInfo();
    return info.hasActiveSubscription;
  }

  /// 広告削除確認
  static Future<bool> hasAdsRemoved() async {
    final info = await getCustomerInfo();
    return info.hasAdsRemoved;
  }
}

// 購入情報モデル
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
