import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Firestoreから読み込んだ値をローカル状態へ「ユーザーごとに1回だけ」反映してよいとき、
/// 反映すべき値を返す。反映すべきでなければnull。
///
/// 重要: Riverpodはuid変更でFutureProviderを再実行する間、AsyncLoadingに直前の値
/// （uid未確定時の初期値＝コイン100・受取日なし等）を引き継ぐ。`value`だけを見ると
/// この「古い初期値」を本物として反映し、ハイドレート済みにしてしまい、後から届く
/// 実データが無視される（再起動のたびに初期状態へ戻るバグ）。そのためロード中・
/// エラー中は反映しない。
T? valueToHydrate<T>(AsyncValue<T> next, {required String? uid, required String? hydratedUid}) {
  if (uid == null || hydratedUid == uid) return null;
  if (next.isLoading || next.hasError || !next.hasValue) return null;
  return next.value;
}
