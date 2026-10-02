import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// RevenueCat Offering / Package IDs
// ※ RevenueCatダッシュボード側で同名Offering/Packageを作成しておくこと
// カード作成はコイン消費(kCardCreationCoinCostByTier)に一本化しており、
// 実売購入としてのcard_create Offeringは廃止した。
const String kStarterPackOffering = 'starter_pack'; // ¥300（3枚分）
const String kCurrencyShopOffering = 'currency_shop'; // コイン/ジェムパック各種
const String kVipPassOffering = 'vip_pass'; // 月額サブスクリプション
// RevenueCatダッシュボードでvip_pass商品に紐付けるEntitlement識別子。
// サブスクは消費型パッケージと異なりEntitlement経由で有効/期限切れを判定する。
const String kVipEntitlementId = 'vip';

// スターターパック購入時に付与する額（コイン単体購入より割安なバンドル）
const int kStarterPackCoins = 350;
const int kStarterPackGems = 5;

const String kRevenueCatApiKeyAndroid = 'goog_gBSlgBnofzpIFbHUgzEyfFLUSmb';
const String kRevenueCatApiKeyIos = 'YOUR_REVENUECAT_IOS_API_KEY';

// コイン/ジェムパック定義（RevenueCat側のPackage識別子と1:1で対応させる）
class CurrencyPackageDef {
  final String packageId; // RevenueCat Package identifier
  final String label;
  final int amount; // ボーナス込みの実際の付与量
  final String fallbackPriceLabel; // ストア価格が取得できない場合の表示用
  final bool isGem;

  const CurrencyPackageDef({
    required this.packageId,
    required this.label,
    required this.amount,
    required this.fallbackPriceLabel,
    required this.isGem,
  });
}

const List<CurrencyPackageDef> kCoinPackages = [
  CurrencyPackageDef(
    packageId: 'coin_100',
    label: 'コイン100枚',
    amount: 100,
    fallbackPriceLabel: '¥120',
    isGem: false,
  ),
  CurrencyPackageDef(
    packageId: 'coin_500',
    label: 'コイン500枚 +ボーナス50枚',
    amount: 550,
    fallbackPriceLabel: '¥480',
    isGem: false,
  ),
  CurrencyPackageDef(
    packageId: 'coin_1200',
    label: 'コイン1200枚 +ボーナス200枚',
    amount: 1400,
    fallbackPriceLabel: '¥980',
    isGem: false,
  ),
];

const List<CurrencyPackageDef> kGemPackages = [
  CurrencyPackageDef(
    packageId: 'gem_10',
    label: 'ジェム10個',
    amount: 10,
    fallbackPriceLabel: '¥120',
    isGem: true,
  ),
  CurrencyPackageDef(
    packageId: 'gem_50',
    label: 'ジェム50個 +ボーナス5個',
    amount: 55,
    fallbackPriceLabel: '¥480',
    isGem: true,
  ),
  CurrencyPackageDef(
    packageId: 'gem_120',
    label: 'ジェム120個 +ボーナス20個',
    amount: 140,
    fallbackPriceLabel: '¥980',
    isGem: true,
  ),
];

class PurchaseService {
  static bool _initialized = false;

  // 直近の購入エラーの内容(エラーコード名)。購入失敗時に画面へ出して原因を特定しやすくする。
  static String? lastErrorDetail;

  // RevenueCatのユーザーをFirebase uidに紐付ける（購入が端末/再インストールをまたいで
  // 同じアカウントに残るようにする）。未初期化・失敗時は何もしない。
  static Future<void> syncUser(String uid) async {
    if (!_initialized) return;
    try {
      if (await Purchases.appUserID != uid) {
        await Purchases.logIn(uid);
      }
    } catch (e) {
      debugPrint('RevenueCat logIn failed: $e');
    }
  }

  static Future<void> init() async {
    if (_initialized) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

    PurchasesConfiguration config;
    if (defaultTargetPlatform == TargetPlatform.android) {
      config = PurchasesConfiguration(kRevenueCatApiKeyAndroid);
    } else {
      config = PurchasesConfiguration(kRevenueCatApiKeyIos);
    }

    await Purchases.configure(config);
    _initialized = true;
  }

  // Offering内の最初の（通常唐一の）パッケージを購入する共通処理。
  // starter_packは「1回きりの解放」であり定期購読ではないため、
  // 特定の期間区分（.monthly等）を決め打ちで参照せず、Offeringが持つ
  // パッケージをそのまま使う（旧実装は存在しないsubscription用の.monthlyを
  // 参照しており常にnoProductになるバグがあった）。
  static Future<PurchaseResult> _purchaseFirstPackage(String offeringId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(offeringId);
      if (offering == null || offering.availablePackages.isEmpty) {
        return PurchaseResult.noProduct;
      }
      await Purchases.purchasePackage(offering.availablePackages.first);
      return PurchaseResult.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      debugPrint('Purchase error ($offeringId): ${e.message}');
      lastErrorDetail = code.name;
      return PurchaseResult.error;
    } catch (e) {
      debugPrint('Purchase error ($offeringId): $e');
      return PurchaseResult.error;
    }
  }

  // スターターパック ¥300（3枚分）
  static Future<PurchaseResult> purchaseStarterPack() =>
      _purchaseFirstPackage(kStarterPackOffering);

  // VIPパス（月額/年額サブスクリプション）
  // vip_pass Offeringには$rc_monthlyと$rc_annualの2パッケージがあるため、
  // 先頭決め打ちではなく期間区分で選ぶ。
  static Future<PurchaseResult> purchaseVipPass({bool yearly = false}) async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(kVipPassOffering);
      final type = yearly ? PackageType.annual : PackageType.monthly;
      Package? package;
      for (final p in offering?.availablePackages ?? const <Package>[]) {
        if (p.packageType == type) {
          package = p;
          break;
        }
      }
      if (package == null) return PurchaseResult.noProduct;
      await Purchases.purchasePackage(package);
      return PurchaseResult.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      debugPrint('Purchase error ($kVipPassOffering): ${e.message}');
      lastErrorDetail = code.name;
      return PurchaseResult.error;
    } catch (e) {
      debugPrint('Purchase error ($kVipPassOffering): $e');
      return PurchaseResult.error;
    }
  }

  // VIPパスが現在有効かどうか（RevenueCatのEntitlementで判定）
  static Future<bool> isVipActive() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(kVipEntitlementId);
    } catch (e) {
      debugPrint('VIP status check failed: $e');
      return false;
    }
  }

  // コイン/ジェムパック購入（currency_shop Offering内のpackageIdで指定）
  static Future<PurchaseResult> purchaseCurrencyPackage(String packageId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(kCurrencyShopOffering);
      if (offering == null) return PurchaseResult.noProduct;

      Package? package;
      for (final p in offering.availablePackages) {
        if (p.identifier == packageId) {
          package = p;
          break;
        }
      }
      if (package == null) return PurchaseResult.noProduct;

      await Purchases.purchasePackage(package);
      return PurchaseResult.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      debugPrint('Purchase error ($packageId): ${e.message}');
      lastErrorDetail = code.name;
      return PurchaseResult.error;
    } catch (e) {
      debugPrint('Purchase error ($packageId): $e');
      return PurchaseResult.error;
    }
  }

  // 購入履歴（非サブスクリプション取引一覧。RevenueCatのCustomerInfoから取得）
  static Future<List<StoreTransaction>> getPurchaseHistory() async {
    final info = await Purchases.getCustomerInfo();
    return info.nonSubscriptionTransactions;
  }

  // 購入復元
  // 戻り値: 復元できる購入（有効なEntitlementまたは購入履歴）が見つかったか。
  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.isNotEmpty || info.nonSubscriptionTransactions.isNotEmpty;
    } catch (e) {
      debugPrint('Restore purchases failed: $e');
      return false;
    }
  }
}

enum PurchaseResult { success, cancelled, noProduct, error }
