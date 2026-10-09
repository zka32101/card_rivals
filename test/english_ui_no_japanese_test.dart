import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:card_rivals/models/card_design_words.dart';
import 'package:card_rivals/models/card_design_words_en.dart';
import 'package:card_rivals/models/game_enrichment.dart' as ge;
import 'package:card_rivals/models/game_enrichment_en.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:card_rivals/screens/card_creation_screen_v2.dart';
import 'package:card_rivals/widgets/card_widget.dart';

final _jp = RegExp(r'[ぁ-んァ-ヶ一-龠]');

/// 画面上の全Textから日本語を含む文字列を集める。
List<String> _japaneseTexts(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText() ?? '';
    if (_jp.hasMatch(s)) out.add(s);
  }
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    final s = w.text.toPlainText();
    if (_jp.hasMatch(s)) out.add(s);
  }
  return out;
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: home)),
      ),
    );

void main() {
  test('全デザイン言葉・カテゴリに英語ラベルがあり、日本語を含まない', () {
    for (final entry in kCardDesignWordsByCategory.entries) {
      expect(kCardDesignCategoryLabelsEn[entry.key], isNotNull, reason: entry.key);
      expect(_jp.hasMatch(kCardDesignCategoryLabelsEn[entry.key]!), isFalse);
      for (final w in entry.value) {
        final en = kCardDesignWordLabelsEn[w];
        expect(en, isNotNull, reason: '英語ラベル未定義: $w');
        expect(_jp.hasMatch(en!), isFalse, reason: w);
      }
    }
    // 日本語表示では原文のまま（サーバー送信キーは常に日本語）
    expect(designWordLabel('炎', 'ja'), '炎');
    expect(designWordLabel('炎', 'en'), 'Flame');
  });

  testWidgets('ランク名は英語ロケールで英語になる', (tester) async {
    late AppLocalizations t;
    await tester.pumpWidget(_app(Builder(builder: (c) {
      t = AppLocalizations.of(c)!;
      return const SizedBox();
    })));
    for (final r in [0, 1300, 1600, 1900, 2300]) {
      final label = PlayerRank.fromRating(r).tierLabelOf(t);
      expect(_jp.hasMatch(label), isFalse, reason: '$r -> $label');
    }
    expect(PlayerRank.fromRating(0).tierLabelOf(t), 'Bronze');
  });

  testWidgets('カード表示の属性の世界名が英語になる', (tester) async {
    final card = PlayCard(
      cardId: 'x', attribute: 'anger', cost: 3, attackPower: 10,
      defensePower: 5, speed: 5, nameJp: '炎の子', nameEn: 'Child of Flame',
    );
    await tester.pumpWidget(_app(CardWidget(card: card, size: 160)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Volcanic Continent'), findsWidgets);
    expect(_japaneseTexts(tester), isEmpty);
  });

  testWidgets('カード作成のデザイン言葉選択が英語ロケールで日本語を出さない', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const SizedBox(height: 2000, child: CardCreationScreenV2())));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Flame'), findsWidgets);
    expect(find.text('Nature & Seasons'), findsWidgets);
    expect(_japaneseTexts(tester), isEmpty, reason: _japaneseTexts(tester).join(' / '));
  });

  testWidgets('カード作成の各ステップを英語ロケールで進めても日本語が出ない', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const SizedBox(height: 2000, child: CardCreationScreenV2())));
    await tester.pump(const Duration(milliseconds: 200));
    for (final w in ['Flame', 'Moon', 'Thunder']) {
      await tester.tap(find.text(w).first);
      await tester.pump();
    }
    expect(_japaneseTexts(tester), isEmpty, reason: _japaneseTexts(tester).join(' / '));
    // 次のステップへ（ボタンはステップごとに1つ）
    for (var step = 1; step <= 3; step++) {
      final next = find.byWidgetPredicate((w) => w is ElevatedButton && w.onPressed != null);
      if (next.evaluate().isEmpty) break;
      await tester.ensureVisible(next.first);
      await tester.tap(next.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_japaneseTexts(tester), isEmpty,
          reason: 'step $step: ${_japaneseTexts(tester).join(' / ')}');
    }
  });

  test('バッジ・実績の英語ラベルに日本語が残らない', () {
    for (final b in ge.kBadgeDefinitions) {
      expect(_jp.hasMatch(badgeNameFor(b, 'en')), isFalse, reason: b.id);
      expect(_jp.hasMatch(badgeDescriptionFor(b, 'en')), isFalse, reason: b.id);
    }
    final ach = ge.getAchievementProgress(
      wins: 0, losses: 0, rating: 0, cardsCreated: 0, dailyStreak: 0, unlockedBadges: const [],
    );
    for (final a in ach) {
      expect(_jp.hasMatch(achievementTitleFor(a, 'en')), isFalse, reason: a.id);
      expect(_jp.hasMatch(achievementDescriptionFor(a, 'en')), isFalse, reason: a.id);
      expect(_jp.hasMatch(achievementRewardFor(a, 'en')), isFalse, reason: a.id);
    }
  });
}
