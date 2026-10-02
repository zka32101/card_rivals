import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:card_rivals/models/deck_preset.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/collection_provider.dart';
import 'package:card_rivals/providers/deck_presets_provider.dart';
import 'package:card_rivals/screens/deck_list_screen.dart';

PlayCard _card(String id, String name) => PlayCard(
      cardId: id,
      attribute: 'joy',
      cost: 2,
      attackPower: 10,
      defensePower: 5,
      speed: 5,
      nameJp: name,
    );

DeckPreset _preset(String id, String name, List<String> cardIds) => DeckPreset(
      id: id,
      userId: 'u',
      name: name,
      description: '',
      cardIds: cardIds,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

Future<void> _pump(WidgetTester tester, List<DeckPreset> presets, List<PlayCard> cards) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userDeckPresetsProvider.overrideWith((ref) async => presets),
        battleEligibleCardsProvider.overrideWithValue(cards),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeckListScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  final cards = [for (var i = 0; i < 5; i++) _card('c$i', 'カード$i')];

  testWidgets('デッキが無いときは案内が出る', (tester) async {
    await _pump(tester, const [], cards);
    expect(find.textContaining('まだデッキがありません'), findsOneWidget);
    expect(find.text('新しいデッキ'), findsOneWidget);
  });

  testWidgets('保存済みデッキの名前・枚数・上限表示が出る', (tester) async {
    await _pump(tester, [_preset('a', '速攻デッキ', ['c0', 'c1', 'c2', 'c3', 'c4'])], cards);
    expect(find.text('速攻デッキ'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('1 / 10 デッキ'), findsOneWidget);
  });

  testWidgets('使えなくなったカードがあると警告が出る', (tester) async {
    await _pump(tester, [_preset('a', '古いデッキ', ['c0', 'gone1', 'gone2'])], cards);
    expect(find.textContaining('使えないカードが2枚'), findsOneWidget);
  });

  testWidgets('上限(10個)に達していると新規作成は止められる', (tester) async {
    final presets = [for (var i = 0; i < 10; i++) _preset('p$i', 'デッキ$i', ['c0'])];
    await _pump(tester, presets, cards);
    await tester.tap(find.text('新しいデッキ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('最大10個'), findsOneWidget);
  });
}
