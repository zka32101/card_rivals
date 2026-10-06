import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/collection_provider.dart';
import 'package:card_rivals/screens/collection_screen.dart';

PlayCard _card(String id, String name, String attr, int cost, {int atk = 10}) => PlayCard(
      cardId: id,
      attribute: attr,
      cost: cost,
      attackPower: atk,
      defensePower: 5,
      speed: 5,
      nameJp: name,
    );

Future<void> _pump(WidgetTester tester, List<PlayCard> cards) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [myCollectionProvider.overrideWithValue(cards)],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CollectionScreen(embedded: true),
      ),
    ),
  );
  // EmotionMoteFieldが常時アニメーションするためpumpAndSettleは使えない
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final cards = [
    _card('a', 'ほのお', 'anger', 4, atk: 30),
    _card('b', 'ひかり', 'joy', 1),
    _card('c', 'つき', 'sadness', 2),
  ];

  testWidgets('全カード数と件数表示が出る', (tester) async {
    await _pump(tester, cards);
    expect(find.text('3枚を表示（全3枚）'), findsOneWidget);
  });

  testWidgets('カード名で検索すると絞り込まれ、リセットで戻る', (tester) async {
    await _pump(tester, cards);
    await tester.enterText(find.byType(TextField), 'ひかり');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1枚を表示（全3枚）'), findsOneWidget);

    await tester.tap(find.text('絞り込みをリセット'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('3枚を表示（全3枚）'), findsOneWidget);
  });

  testWidgets('属性フィルタで絞り込める', (tester) async {
    await _pump(tester, cards);
    // 絵文字は画像に置き換わったので、文字（怒）で探す。
    await tester.tap(find.textContaining('怒', findRichText: true).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1枚を表示（全3枚）'), findsOneWidget);
  });

  testWidgets('表示切替で一覧表示になりステータスが見える', (tester) async {
    await _pump(tester, cards);
    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('ATK'), findsWidgets);
  });
}
