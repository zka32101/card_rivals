import 'package:freezed_annotation/freezed_annotation.dart';

part 'purchase_models.freezed.dart';

@freezed
abstract class CoinPackage with _$CoinPackage {
  const factory CoinPackage({
    required String productId,
    required int coins,
    required String price,
    required double discount,
  }) = _CoinPackage;
}

@freezed
abstract class SubscriptionPackage with _$SubscriptionPackage {
  const factory SubscriptionPackage({
    required String productId,
    required String price,
    required List<String> features,
  }) = _SubscriptionPackage;
}

@freezed
abstract class CustomerInfo with _$CustomerInfo {
  const factory CustomerInfo({
    required bool hasActiveSubscription,
    required bool hasAdsRemoved,
    required Set<String> activeEntitlements,
  }) = _CustomerInfo;
}
