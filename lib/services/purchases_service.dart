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
    } catch (e) {
      rethrow;
    }
  }

  /// 利用可能な商品を取得
  static Future<List<Package>> getAvailablePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 商品を購入
  static Future<bool> purchasePackage(Package package) async {
    try {
      final _ = await Purchases.purchasePackage(package);
      return true;
    } on PurchasesException catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        // Purchase cancelled by user - normal flow
      } else {
        // Handle other purchase errors
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// ユーザーの購入状態を取得
  static Future<Map<String, dynamic>> getCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final activeEntitlements = info.entitlements.active.keys.toSet();

      return {
        'hasActiveSubscription': activeEntitlements.isNotEmpty,
        'hasAdsRemoved': activeEntitlements.contains('ad_free'),
        'activeEntitlements': activeEntitlements,
      };
    } catch (e) {
      return {
        'hasActiveSubscription': false,
        'hasAdsRemoved': false,
        'activeEntitlements': <String>{},
      };
    }
  }

  /// サブスクリプション確認
  static Future<bool> hasActiveSubscription() async {
    final info = await getCustomerInfo();
    return info['hasActiveSubscription'] as bool;
  }

  /// 広告削除確認
  static Future<bool> hasAdsRemoved() async {
    final info = await getCustomerInfo();
    return info['hasAdsRemoved'] as bool;
  }
}
