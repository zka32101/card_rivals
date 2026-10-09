// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'purchase_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoinPackage {

 String get productId; int get coins; String get price; double get discount;
/// Create a copy of CoinPackage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoinPackageCopyWith<CoinPackage> get copyWith => _$CoinPackageCopyWithImpl<CoinPackage>(this as CoinPackage, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CoinPackage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoinPackage&&(identical(other.productId, _this.productId) || other.productId == _this.productId)&&(identical(other.coins, _this.coins) || other.coins == _this.coins)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.discount, _this.discount) || other.discount == _this.discount));
}


@override
int get hashCode {
  final _this = this as CoinPackage;
  return Object.hash(runtimeType,_this.productId,_this.coins,_this.price,_this.discount);
}

@override
String toString() {
  final _this = this as CoinPackage;
  return 'CoinPackage(productId: ${_this.productId}, coins: ${_this.coins}, price: ${_this.price}, discount: ${_this.discount})';
}


}

/// @nodoc
abstract mixin class $CoinPackageCopyWith<$Res>  {
  factory $CoinPackageCopyWith(CoinPackage value, $Res Function(CoinPackage) _then) = _$CoinPackageCopyWithImpl;
@useResult
$Res call({
 String productId, int coins, String price, double discount
});




}
/// @nodoc
class _$CoinPackageCopyWithImpl<$Res>
    implements $CoinPackageCopyWith<$Res> {
  _$CoinPackageCopyWithImpl(this._self, this._then);

  final CoinPackage _self;
  final $Res Function(CoinPackage) _then;

/// Create a copy of CoinPackage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? coins = null,Object? price = null,Object? discount = null,}) {
  return _then(CoinPackage(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [CoinPackage].
extension CoinPackagePatterns on CoinPackage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoinPackage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoinPackage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoinPackage value)  $default,){
final _that = this;
switch (_that) {
case _CoinPackage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoinPackage value)?  $default,){
final _that = this;
switch (_that) {
case _CoinPackage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  int coins,  String price,  double discount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoinPackage() when $default != null:
return $default(_that.productId,_that.coins,_that.price,_that.discount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  int coins,  String price,  double discount)  $default,) {final _that = this;
switch (_that) {
case _CoinPackage():
return $default(_that.productId,_that.coins,_that.price,_that.discount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  int coins,  String price,  double discount)?  $default,) {final _that = this;
switch (_that) {
case _CoinPackage() when $default != null:
return $default(_that.productId,_that.coins,_that.price,_that.discount);case _:
  return null;

}
}

}

/// @nodoc


class _CoinPackage implements CoinPackage {
  const _CoinPackage({required this.productId, required this.coins, required this.price, required this.discount});
  

@override final  String productId;
@override final  int coins;
@override final  String price;
@override final  double discount;

/// Create a copy of CoinPackage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoinPackageCopyWith<_CoinPackage> get copyWith => __$CoinPackageCopyWithImpl<_CoinPackage>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoinPackage&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.coins, coins) || other.coins == coins)&&(identical(other.price, price) || other.price == price)&&(identical(other.discount, discount) || other.discount == discount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,productId,coins,price,discount);
}

@override
String toString() {
    return 'CoinPackage(productId: $productId, coins: $coins, price: $price, discount: $discount)';
}


}

/// @nodoc
abstract mixin class _$CoinPackageCopyWith<$Res> implements $CoinPackageCopyWith<$Res> {
  factory _$CoinPackageCopyWith(_CoinPackage value, $Res Function(_CoinPackage) _then) = __$CoinPackageCopyWithImpl;
@override @useResult
$Res call({
 String productId, int coins, String price, double discount
});




}
/// @nodoc
class __$CoinPackageCopyWithImpl<$Res>
    implements _$CoinPackageCopyWith<$Res> {
  __$CoinPackageCopyWithImpl(this._self, this._then);

  final _CoinPackage _self;
  final $Res Function(_CoinPackage) _then;

/// Create a copy of CoinPackage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? coins = null,Object? price = null,Object? discount = null,}) {
  return _then(_CoinPackage(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$SubscriptionPackage {

 String get productId; String get price; List<String> get features;
/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPackageCopyWith<SubscriptionPackage> get copyWith => _$SubscriptionPackageCopyWithImpl<SubscriptionPackage>(this as SubscriptionPackage, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SubscriptionPackage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPackage&&(identical(other.productId, _this.productId) || other.productId == _this.productId)&&(identical(other.price, _this.price) || other.price == _this.price)&&const DeepCollectionEquality().equals(other.features, _this.features));
}


@override
int get hashCode {
  final _this = this as SubscriptionPackage;
  return Object.hash(runtimeType,_this.productId,_this.price,const DeepCollectionEquality().hash(_this.features));
}

@override
String toString() {
  final _this = this as SubscriptionPackage;
  return 'SubscriptionPackage(productId: ${_this.productId}, price: ${_this.price}, features: ${_this.features})';
}


}

/// @nodoc
abstract mixin class $SubscriptionPackageCopyWith<$Res>  {
  factory $SubscriptionPackageCopyWith(SubscriptionPackage value, $Res Function(SubscriptionPackage) _then) = _$SubscriptionPackageCopyWithImpl;
@useResult
$Res call({
 String productId, String price, List<String> features
});




}
/// @nodoc
class _$SubscriptionPackageCopyWithImpl<$Res>
    implements $SubscriptionPackageCopyWith<$Res> {
  _$SubscriptionPackageCopyWithImpl(this._self, this._then);

  final SubscriptionPackage _self;
  final $Res Function(SubscriptionPackage) _then;

/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? price = null,Object? features = null,}) {
  return _then(SubscriptionPackage(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String,features: null == features ? _self.features : features // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionPackage].
extension SubscriptionPackagePatterns on SubscriptionPackage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionPackage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionPackage value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPackage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionPackage value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String price,  List<String> features)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
return $default(_that.productId,_that.price,_that.features);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String price,  List<String> features)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPackage():
return $default(_that.productId,_that.price,_that.features);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String price,  List<String> features)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
return $default(_that.productId,_that.price,_that.features);case _:
  return null;

}
}

}

/// @nodoc


class _SubscriptionPackage implements SubscriptionPackage {
  const _SubscriptionPackage({required this.productId, required this.price, required  List<String> features}): _features = features;
  

@override final  String productId;
@override final  String price;
 final  List<String> _features;
@override List<String> get features {
  if (_features is EqualUnmodifiableListView) return _features;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_features);
}


/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionPackageCopyWith<_SubscriptionPackage> get copyWith => __$SubscriptionPackageCopyWithImpl<_SubscriptionPackage>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionPackage&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.price, price) || other.price == price)&&const DeepCollectionEquality().equals(other.features, _features));
}


@override
int get hashCode {
    return Object.hash(runtimeType,productId,price,const DeepCollectionEquality().hash(_features));
}

@override
String toString() {
    return 'SubscriptionPackage(productId: $productId, price: $price, features: $features)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionPackageCopyWith<$Res> implements $SubscriptionPackageCopyWith<$Res> {
  factory _$SubscriptionPackageCopyWith(_SubscriptionPackage value, $Res Function(_SubscriptionPackage) _then) = __$SubscriptionPackageCopyWithImpl;
@override @useResult
$Res call({
 String productId, String price, List<String> features
});




}
/// @nodoc
class __$SubscriptionPackageCopyWithImpl<$Res>
    implements _$SubscriptionPackageCopyWith<$Res> {
  __$SubscriptionPackageCopyWithImpl(this._self, this._then);

  final _SubscriptionPackage _self;
  final $Res Function(_SubscriptionPackage) _then;

/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? price = null,Object? features = null,}) {
  return _then(_SubscriptionPackage(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String,features: null == features ? _self._features : features // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$CustomerInfo {

 bool get hasActiveSubscription; bool get hasAdsRemoved; Set<String> get activeEntitlements;
/// Create a copy of CustomerInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerInfoCopyWith<CustomerInfo> get copyWith => _$CustomerInfoCopyWithImpl<CustomerInfo>(this as CustomerInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CustomerInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerInfo&&(identical(other.hasActiveSubscription, _this.hasActiveSubscription) || other.hasActiveSubscription == _this.hasActiveSubscription)&&(identical(other.hasAdsRemoved, _this.hasAdsRemoved) || other.hasAdsRemoved == _this.hasAdsRemoved)&&const DeepCollectionEquality().equals(other.activeEntitlements, _this.activeEntitlements));
}


@override
int get hashCode {
  final _this = this as CustomerInfo;
  return Object.hash(runtimeType,_this.hasActiveSubscription,_this.hasAdsRemoved,const DeepCollectionEquality().hash(_this.activeEntitlements));
}

@override
String toString() {
  final _this = this as CustomerInfo;
  return 'CustomerInfo(hasActiveSubscription: ${_this.hasActiveSubscription}, hasAdsRemoved: ${_this.hasAdsRemoved}, activeEntitlements: ${_this.activeEntitlements})';
}


}

/// @nodoc
abstract mixin class $CustomerInfoCopyWith<$Res>  {
  factory $CustomerInfoCopyWith(CustomerInfo value, $Res Function(CustomerInfo) _then) = _$CustomerInfoCopyWithImpl;
@useResult
$Res call({
 bool hasActiveSubscription, bool hasAdsRemoved, Set<String> activeEntitlements
});




}
/// @nodoc
class _$CustomerInfoCopyWithImpl<$Res>
    implements $CustomerInfoCopyWith<$Res> {
  _$CustomerInfoCopyWithImpl(this._self, this._then);

  final CustomerInfo _self;
  final $Res Function(CustomerInfo) _then;

/// Create a copy of CustomerInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hasActiveSubscription = null,Object? hasAdsRemoved = null,Object? activeEntitlements = null,}) {
  return _then(CustomerInfo(
hasActiveSubscription: null == hasActiveSubscription ? _self.hasActiveSubscription : hasActiveSubscription // ignore: cast_nullable_to_non_nullable
as bool,hasAdsRemoved: null == hasAdsRemoved ? _self.hasAdsRemoved : hasAdsRemoved // ignore: cast_nullable_to_non_nullable
as bool,activeEntitlements: null == activeEntitlements ? _self.activeEntitlements : activeEntitlements // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomerInfo].
extension CustomerInfoPatterns on CustomerInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomerInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomerInfo value)  $default,){
final _that = this;
switch (_that) {
case _CustomerInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomerInfo value)?  $default,){
final _that = this;
switch (_that) {
case _CustomerInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hasActiveSubscription,  bool hasAdsRemoved,  Set<String> activeEntitlements)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerInfo() when $default != null:
return $default(_that.hasActiveSubscription,_that.hasAdsRemoved,_that.activeEntitlements);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hasActiveSubscription,  bool hasAdsRemoved,  Set<String> activeEntitlements)  $default,) {final _that = this;
switch (_that) {
case _CustomerInfo():
return $default(_that.hasActiveSubscription,_that.hasAdsRemoved,_that.activeEntitlements);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hasActiveSubscription,  bool hasAdsRemoved,  Set<String> activeEntitlements)?  $default,) {final _that = this;
switch (_that) {
case _CustomerInfo() when $default != null:
return $default(_that.hasActiveSubscription,_that.hasAdsRemoved,_that.activeEntitlements);case _:
  return null;

}
}

}

/// @nodoc


class _CustomerInfo implements CustomerInfo {
  const _CustomerInfo({required this.hasActiveSubscription, required this.hasAdsRemoved, required  Set<String> activeEntitlements}): _activeEntitlements = activeEntitlements;
  

@override final  bool hasActiveSubscription;
@override final  bool hasAdsRemoved;
 final  Set<String> _activeEntitlements;
@override Set<String> get activeEntitlements {
  if (_activeEntitlements is EqualUnmodifiableSetView) return _activeEntitlements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_activeEntitlements);
}


/// Create a copy of CustomerInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerInfoCopyWith<_CustomerInfo> get copyWith => __$CustomerInfoCopyWithImpl<_CustomerInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerInfo&&(identical(other.hasActiveSubscription, hasActiveSubscription) || other.hasActiveSubscription == hasActiveSubscription)&&(identical(other.hasAdsRemoved, hasAdsRemoved) || other.hasAdsRemoved == hasAdsRemoved)&&const DeepCollectionEquality().equals(other.activeEntitlements, _activeEntitlements));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hasActiveSubscription,hasAdsRemoved,const DeepCollectionEquality().hash(_activeEntitlements));
}

@override
String toString() {
    return 'CustomerInfo(hasActiveSubscription: $hasActiveSubscription, hasAdsRemoved: $hasAdsRemoved, activeEntitlements: $activeEntitlements)';
}


}

/// @nodoc
abstract mixin class _$CustomerInfoCopyWith<$Res> implements $CustomerInfoCopyWith<$Res> {
  factory _$CustomerInfoCopyWith(_CustomerInfo value, $Res Function(_CustomerInfo) _then) = __$CustomerInfoCopyWithImpl;
@override @useResult
$Res call({
 bool hasActiveSubscription, bool hasAdsRemoved, Set<String> activeEntitlements
});




}
/// @nodoc
class __$CustomerInfoCopyWithImpl<$Res>
    implements _$CustomerInfoCopyWith<$Res> {
  __$CustomerInfoCopyWithImpl(this._self, this._then);

  final _CustomerInfo _self;
  final $Res Function(_CustomerInfo) _then;

/// Create a copy of CustomerInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hasActiveSubscription = null,Object? hasAdsRemoved = null,Object? activeEntitlements = null,}) {
  return _then(_CustomerInfo(
hasActiveSubscription: null == hasActiveSubscription ? _self.hasActiveSubscription : hasActiveSubscription // ignore: cast_nullable_to_non_nullable
as bool,hasAdsRemoved: null == hasAdsRemoved ? _self.hasAdsRemoved : hasAdsRemoved // ignore: cast_nullable_to_non_nullable
as bool,activeEntitlements: null == activeEntitlements ? _self._activeEntitlements : activeEntitlements // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
