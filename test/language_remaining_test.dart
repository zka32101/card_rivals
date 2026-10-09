import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:card_rivals/models/battle_log_text.dart';
import 'package:card_rivals/models/battle_models.dart';
import 'package:card_rivals/models/card_name.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/deck_presets_provider.dart';
import 'package:card_rivals/providers/migration_provider.dart';
import 'package:card_rivals/services/battle_engine.dart';
import 'package:card_rivals/services/purchase_service.dart';

final _jp = RegExp(r'[ぁ-んァ-ヶ一-龠]');

Future<AppLocalizations> _load(WidgetTester tester, Locale locale) async {
  late AppLocalizations t;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (c) {
      t = AppLocalizations.of(c)!;
      return const SizedBox();
    }),
  ));
  return t;
}

PlayCard _card(String id, String attr, String jp, String en, {int atk = 10, int def = 5, int spd = 5}) =>
    PlayCard(
      cardId: id, attribute: attr, cost: 2, attackPower: atk, defensePower: def,
      speed: spd, nameJp: jp, nameEn: en,
    );

void main() {
  test('英語ARBの値に日本語が混ざらない', () {
    final map = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final bad = <String>[];
    map.forEach((k, v) {
      if (k.startsWith('@')) return;
      if (v is String && _jp.hasMatch(v)) bad.add(k);
    });
    expect(bad, isEmpty);
  });

  test('カード名は表示言語に追従し、英語名が無ければ元の名前にフォールバックする', () {
    expect(pickCardName('en', jp: '炎の子', en: 'Child of Flame'), 'Child of Flame');
    expect(pickCardName('ja', jp: '炎の子', en: 'Child of Flame'), '炎の子');
    expect(pickCardName('en', jp: '炎の子', en: ''), '炎の子');
    expect(pickCardNameFromMap('en', {'jp': '光', 'en': 'Light'}), 'Light');
    expect(_card('a', 'joy', '光', 'Light').nameFor('en'), 'Light');
    expect(_card('a', 'joy', '光', 'Light').nameFor('ja'), '光');
  });

  testWidgets('英語ロケールでバトルログ・大陸名・パック名・プリセットエラーに日本語が出ない', (tester) async {
    final t = await _load(tester, const Locale('en'));

    final mine = [_card('m1', 'joy', '光の騎士', 'Knight of Light', atk: 15)];
    final foe = [_card('f1', 'anger', '怒りの王', 'King of Wrath', atk: 6, spd: 1)];
    final result = BattleEngine.simulate(mine, foe);
    expect(result.logs, isNotEmpty);
    for (final log in result.logs) {
      final text = battleLogText(t, log);
      expect(_jp.hasMatch(text), isFalse, reason: text);
      expect(text.contains('Knight of Light') || text.contains('King of Wrath'), isTrue, reason: text);
    }

    for (final a in ['joy', 'anger', 'sadness']) {
      expect(_jp.hasMatch(migrationAttributeLabel(t, a)), isFalse);
    }
    for (final p in [...kCoinPackages, ...kGemPackages]) {
      expect(_jp.hasMatch(p.labelOf(t)), isFalse, reason: p.packageId);
    }
    for (final e in DeckPresetError.values) {
      expect(_jp.hasMatch(DeckPresetException(e).message(t)), isFalse, reason: '$e');
    }
  });

  testWidgets('日本語ロケールでは日本語名・日本語ログになる', (tester) async {
    final t = await _load(tester, const Locale('ja'));
    final log = BattleLog(
      turn: 1, action: BattleActionKind.counter, damage: 3, attackerHp: 10, defenderHp: 10,
      attackingCard: _card('a', 'joy', '光の騎士', 'Knight of Light'),
      defendingCard: _card('b', 'anger', '怒りの王', 'King of Wrath'),
    );
    expect(battleLogText(t, log), contains('光の騎士'));
    expect(battleLogText(t, log), contains('反撃'));
  });
}
