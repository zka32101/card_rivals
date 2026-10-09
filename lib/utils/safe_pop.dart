import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafePop on BuildContext {
  /// 戻れる履歴があれば戻り、無ければホームへ移動する。
  /// 外部リンクや復元で `/shop` などから直接始まった場合に `context.pop()` が
  /// 「There is nothing to pop」で例外になるのを防ぐ。
  void popOrHome() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}
