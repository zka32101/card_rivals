import 'dart:convert';
import 'dart:io';

import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// 画面に出す「1日の上限コイン」の表記が、実際に強制する定数(kDailyBonusCoinCap)と
/// 食い違わないことを確認する（UI 20 / 実際 15 に食い違っていた不具合の回帰テスト）。
void main() {
  const keys = [
    'tutorial_page7Description',
    'home_todayCoinsProgress',
    'home_todayWinsProgress',
    'home_pvpRewardCaption',
  ];

  for (final lang in ['ja', 'en']) {
    test('$lang: 上限の表記は kDailyBonusCoinCap と一致する', () {
      final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
      for (final k in keys) {
        final text = arb[k] as String;
        expect(text, contains('$kDailyBonusCoinCap'), reason: '$lang/$k = $text');
        expect(text, isNot(contains('20')), reason: '$lang/$k に古い上限 20 が残っている: $text');
      }
    });
  }
}
