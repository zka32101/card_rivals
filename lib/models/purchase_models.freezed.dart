// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'purchase_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CoinPackage {
  String get productId => throw _privateConstructorUsedError;
  int get coins => throw _privateConstructorUsedError;
  String get price => throw _privateConstructorUsedError;
  double get discount => throw _privateConstructorUsedError;

  /// Create a copy of CoinPackage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CoinPackageCopyWith<CoinPackage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CoinPackageCopyWith<$Res> {
  factory $CoinPackageCopyWith(
    CoinPackage value,
    $Res Function(CoinPackage) then,
  ) = _$CoinPackageCopyWithImpl<$Res, CoinPackage>;
  @useResult
  $Res call({String productId, int coins, String price, double discount});
}

/// @nodoc
class _$CoinPackageCopyWithImpl<$Res, $Val extends CoinPackage>
    implements $CoinPackageCopyWith<$Res> {
  _$CoinPackageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CoinPackage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? coins = null,
    Object? price = null,
    Object? discount = null,
  }) {
    return _then(
      _value.copyWith(
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            coins: null == coins
                ? _value.coins
                : coins // ignore: cast_nullable_to_non_nullable
                      as int,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as String,
            discount: null == discount
                ? _value.discount
                : discount // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CoinPackageImplCopyWith<$Res>
    implements $CoinPackageCopyWith<$Res> {
  factory _$$CoinPackageImplCopyWith(
    _$CoinPackageImpl value,
    $Res Function(_$CoinPackageImpl) then,
  ) = __$$CoinPackageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String productId, int coins, String price, double discount});
}

/// @nodoc
class __$$CoinPackageImplCopyWithImpl<$Res>
    extends _$CoinPackageCopyWithImpl<$Res, _$CoinPackageImpl>
    implements _$$CoinPackageImplCopyWith<$Res> {
  __$$CoinPackageImplCopyWithImpl(
    _$CoinPackageImpl _value,
    $Res Function(_$CoinPackageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CoinPackage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? coins = null,
    Object? price = null,
    Object? discount = null,
  }) {
    return _then(
      _$CoinPackageImpl(
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        coins: null == coins
            ? _value.coins
            : coins // ignore: cast_nullable_to_non_nullable
                  as int,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as String,
        discount: null == discount
            ? _value.discount
            : discount // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$CoinPackageImpl implements _CoinPackage {
  const _$CoinPackageImpl({
    required this.productId,
    required this.coins,
    required this.price,
    required this.discount,
  });

  @override
  final String productId;
  @override
  final int coins;
  @override
  final String price;
  @override
  final double discount;

  @override
  String toString() {
    return 'CoinPackage(productId: $productId, coins: $coins, price: $price, discount: $discount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CoinPackageImpl &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.coins, coins) || other.coins == coins) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.discount, discount) ||
                other.discount == discount));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, productId, coins, price, discount);

  /// Create a copy of CoinPackage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CoinPackageImplCopyWith<_$CoinPackageImpl> get copyWith =>
      __$$CoinPackageImplCopyWithImpl<_$CoinPackageImpl>(this, _$identity);
}

abstract class _CoinPackage implements CoinPackage {
  const factory _CoinPackage({
    required final String productId,
    required final int coins,
    required final String price,
    required final double discount,
  }) = _$CoinPackageImpl;

  @override
  String get productId;
  @override
  int get coins;
  @override
  String get price;
  @override
  double get discount;

  /// Create a copy of CoinPackage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CoinPackageImplCopyWith<_$CoinPackageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SubscriptionPackage {
  String get productId => throw _privateConstructorUsedError;
  String get price => throw _privateConstructorUsedError;
  List<String> get features => throw _privateConstructorUsedError;

  /// Create a copy of SubscriptionPackage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubscriptionPackageCopyWith<SubscriptionPackage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubscriptionPackageCopyWith<$Res> {
  factory $SubscriptionPackageCopyWith(
    SubscriptionPackage value,
    $Res Function(SubscriptionPackage) then,
  ) = _$SubscriptionPackageCopyWithImpl<$Res, SubscriptionPackage>;
  @useResult
  $Res call({String productId, String price, List<String> features});
}

/// @nodoc
class _$SubscriptionPackageCopyWithImpl<$Res, $Val extends SubscriptionPackage>
    implements $SubscriptionPackageCopyWith<$Res> {
  _$SubscriptionPackageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubscriptionPackage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? price = null,
    Object? features = null,
  }) {
    return _then(
      _value.copyWith(
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as String,
            features: null == features
                ? _value.features
                : features // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SubscriptionPackageImplCopyWith<$Res>
    implements $SubscriptionPackageCopyWith<$Res> {
  factory _$$SubscriptionPackageImplCopyWith(
    _$SubscriptionPackageImpl value,
    $Res Function(_$SubscriptionPackageImpl) then,
  ) = __$$SubscriptionPackageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String productId, String price, List<String> features});
}

/// @nodoc
class __$$SubscriptionPackageImplCopyWithImpl<$Res>
    extends _$SubscriptionPackageCopyWithImpl<$Res, _$SubscriptionPackageImpl>
    implements _$$SubscriptionPackageImplCopyWith<$Res> {
  __$$SubscriptionPackageImplCopyWithImpl(
    _$SubscriptionPackageImpl _value,
    $Res Function(_$SubscriptionPackageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SubscriptionPackage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? price = null,
    Object? features = null,
  }) {
    return _then(
      _$SubscriptionPackageImpl(
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as String,
        features: null == features
            ? _value._features
            : features // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$SubscriptionPackageImpl implements _SubscriptionPackage {
  const _$SubscriptionPackageImpl({
    required this.productId,
    required this.price,
    required final List<String> features,
  }) : _features = features;

  @override
  final String productId;
  @override
  final String price;
  final List<String> _features;
  @override
  List<String> get features {
    if (_features is EqualUnmodifiableListView) return _features;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_features);
  }

  @override
  String toString() {
    return 'SubscriptionPackage(productId: $productId, price: $price, features: $features)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubscriptionPackageImpl &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.price, price) || other.price == price) &&
            const DeepCollectionEquality().equals(other._features, _features));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    productId,
    price,
    const DeepCollectionEquality().hash(_features),
  );

  /// Create a copy of SubscriptionPackage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubscriptionPackageImplCopyWith<_$SubscriptionPackageImpl> get copyWith =>
      __$$SubscriptionPackageImplCopyWithImpl<_$SubscriptionPackageImpl>(
        this,
        _$identity,
      );
}

abstract class _SubscriptionPackage implements SubscriptionPackage {
  const factory _SubscriptionPackage({
    required final String productId,
    required final String price,
    required final List<String> features,
  }) = _$SubscriptionPackageImpl;

  @override
  String get productId;
  @override
  String get price;
  @override
  List<String> get features;

  /// Create a copy of SubscriptionPackage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubscriptionPackageImplCopyWith<_$SubscriptionPackageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CustomerInfo {
  bool get hasActiveSubscription => throw _privateConstructorUsedError;
  bool get hasAdsRemoved => throw _privateConstructorUsedError;
  Set<String> get activeEntitlements => throw _privateConstructorUsedError;

  /// Create a copy of CustomerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CustomerInfoCopyWith<CustomerInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CustomerInfoCopyWith<$Res> {
  factory $CustomerInfoCopyWith(
    CustomerInfo value,
    $Res Function(CustomerInfo) then,
  ) = _$CustomerInfoCopyWithImpl<$Res, CustomerInfo>;
  @useResult
  $Res call({
    bool hasActiveSubscription,
    bool hasAdsRemoved,
    Set<String> activeEntitlements,
  });
}

/// @nodoc
class _$CustomerInfoCopyWithImpl<$Res, $Val extends CustomerInfo>
    implements $CustomerInfoCopyWith<$Res> {
  _$CustomerInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CustomerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasActiveSubscription = null,
    Object? hasAdsRemoved = null,
    Object? activeEntitlements = null,
  }) {
    return _then(
      _value.copyWith(
            hasActiveSubscription: null == hasActiveSubscription
                ? _value.hasActiveSubscription
                : hasActiveSubscription // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasAdsRemoved: null == hasAdsRemoved
                ? _value.hasAdsRemoved
                : hasAdsRemoved // ignore: cast_nullable_to_non_nullable
                      as bool,
            activeEntitlements: null == activeEntitlements
                ? _value.activeEntitlements
                : activeEntitlements // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CustomerInfoImplCopyWith<$Res>
    implements $CustomerInfoCopyWith<$Res> {
  factory _$$CustomerInfoImplCopyWith(
    _$CustomerInfoImpl value,
    $Res Function(_$CustomerInfoImpl) then,
  ) = __$$CustomerInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool hasActiveSubscription,
    bool hasAdsRemoved,
    Set<String> activeEntitlements,
  });
}

/// @nodoc
class __$$CustomerInfoImplCopyWithImpl<$Res>
    extends _$CustomerInfoCopyWithImpl<$Res, _$CustomerInfoImpl>
    implements _$$CustomerInfoImplCopyWith<$Res> {
  __$$CustomerInfoImplCopyWithImpl(
    _$CustomerInfoImpl _value,
    $Res Function(_$CustomerInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CustomerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasActiveSubscription = null,
    Object? hasAdsRemoved = null,
    Object? activeEntitlements = null,
  }) {
    return _then(
      _$CustomerInfoImpl(
        hasActiveSubscription: null == hasActiveSubscription
            ? _value.hasActiveSubscription
            : hasActiveSubscription // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasAdsRemoved: null == hasAdsRemoved
            ? _value.hasAdsRemoved
            : hasAdsRemoved // ignore: cast_nullable_to_non_nullable
                  as bool,
        activeEntitlements: null == activeEntitlements
            ? _value._activeEntitlements
            : activeEntitlements // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}

/// @nodoc

class _$CustomerInfoImpl implements _CustomerInfo {
  const _$CustomerInfoImpl({
    required this.hasActiveSubscription,
    required this.hasAdsRemoved,
    required final Set<String> activeEntitlements,
  }) : _activeEntitlements = activeEntitlements;

  @override
  final bool hasActiveSubscription;
  @override
  final bool hasAdsRemoved;
  final Set<String> _activeEntitlements;
  @override
  Set<String> get activeEntitlements {
    if (_activeEntitlements is EqualUnmodifiableSetView)
      return _activeEntitlements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_activeEntitlements);
  }

  @override
  String toString() {
    return 'CustomerInfo(hasActiveSubscription: $hasActiveSubscription, hasAdsRemoved: $hasAdsRemoved, activeEntitlements: $activeEntitlements)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CustomerInfoImpl &&
            (identical(other.hasActiveSubscription, hasActiveSubscription) ||
                other.hasActiveSubscription == hasActiveSubscription) &&
            (identical(other.hasAdsRemoved, hasAdsRemoved) ||
                other.hasAdsRemoved == hasAdsRemoved) &&
            const DeepCollectionEquality().equals(
              other._activeEntitlements,
              _activeEntitlements,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    hasActiveSubscription,
    hasAdsRemoved,
    const DeepCollectionEquality().hash(_activeEntitlements),
  );

  /// Create a copy of CustomerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CustomerInfoImplCopyWith<_$CustomerInfoImpl> get copyWith =>
      __$$CustomerInfoImplCopyWithImpl<_$CustomerInfoImpl>(this, _$identity);
}

abstract class _CustomerInfo implements CustomerInfo {
  const factory _CustomerInfo({
    required final bool hasActiveSubscription,
    required final bool hasAdsRemoved,
    required final Set<String> activeEntitlements,
  }) = _$CustomerInfoImpl;

  @override
  bool get hasActiveSubscription;
  @override
  bool get hasAdsRemoved;
  @override
  Set<String> get activeEntitlements;

  /// Create a copy of CustomerInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CustomerInfoImplCopyWith<_$CustomerInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
