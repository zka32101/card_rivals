import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:card_rivals/models/card_design_words.dart';
import 'package:card_rivals/models/card_design_words_en.dart';
import 'package:card_rivals/providers/collection_provider.dart';
import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:card_rivals/theme/kingdom_theme.dart';
import 'package:card_rivals/widgets/card_reveal_dialog.dart';

import 'helpers/screen_harness.dart';

/// カード作成5ステップ（サーバー関数はFakeServerで差し替え）。
void main() {
  setUpAll(loadTestFonts);

  late FakeServer server;
  late List<Map<String, dynamic>> createCalls;

  setUp(() {
    createCalls = [];
    server = FakeServer();
    server.handlers['generateCardName'] = (_) => {'names': ['Alpha', 'Beta', 'Gamma']};
    server.handlers['generateCardImage'] = (_) => {'imageUrl': ''};
    server.handlers['createCard'] = (p) {
      createCalls.add(p);
      return {'cardId': 'new1', 'newCoinBalance': 400, 'cost': 1, 'skillId': null, 'moveId': null};
    };
    server.handlers['getPeriodLeaderboard'] = (_) => {'leaderboard': fakeBoard()};
    server.install();
  });
  tearDown(() => server.uninstall());

  final words = kCardDesignWords.take(4).map((w) => designWordLabel(w, 'en')).toList();

  Finder royal(String label) => find.byWidgetPredicate((w) => w is RoyalButton && w.label == label);
  bool enabled(WidgetTester tester, String label) => tester.widget<RoyalButton>(royal(label)).onPressed != null;

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).first;
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapRoyal(WidgetTester tester, String label) async {
    await tester.ensureVisible(royal(label));
    await tester.tap(royal(label));
    await settle(tester, frames: 3);
  }

  /// ホーム→カードタブ→「カード作成」で作成画面を開く。
  Future<ProviderContainer> openCreation(WidgetTester tester,
      {int coins = 500, Locale locale = const Locale('en'), ScreenSpec? vp}) async {
    final v = vp ?? viewports.first;
    setViewport(tester, v);
    await tester.pumpWidget(wrapRouter(
        location: '/', locale: locale, textScale: v.textScale, overrides: populatedOverrides(coins: coins)));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.style_outlined)));
    await settle(tester);
    await tester.tap(find.byType(FloatingActionButton).first);
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));
  }

  Future<void> toParameterStep(WidgetTester tester) async {
    for (final w in words.take(3)) {
      await tapText(tester, w);
    }
    await tapRoyal(tester, 'Next →');
    await tapText(tester, 'Joy');
    await tapRoyal(tester, 'Next →');
    await tapRoyal(tester, '🎲 Roll');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester, frames: 2);
  }

  Future<void> toNamingStep(WidgetTester tester) async {
    await toParameterStep(tester);
    await tapRoyal(tester, 'Next →');
    await tapRoyal(tester, 'Generate Name →');
    await settle(tester);
  }

  testWidgets('各ステップの「次へ」は条件を満たすまで無効、デザイン言葉は3つまで', (tester) async {
    final errors = await collectErrors(() async {
      await openCreation(tester);
      expect(enabled(tester, 'Next →'), isFalse, reason: '言葉0個');
      await tapText(tester, words[0]);
      await tapText(tester, words[1]);
      expect(enabled(tester, 'Next →'), isFalse, reason: '言葉2個');
      await tapText(tester, words[2]);
      expect(enabled(tester, 'Next →'), isTrue);
      await tapText(tester, words[3]); // 4つ目は追加されない
      expect(find.text('✓ Selected (3/3)'), findsOneWidget);
      await tapRoyal(tester, 'Next →');

      expect(enabled(tester, 'Next →'), isFalse, reason: '属性未選択');
      await tapText(tester, 'Joy');
      expect(enabled(tester, 'Next →'), isTrue);
      await tapRoyal(tester, 'Next →');

      expect(enabled(tester, 'Next →'), isFalse, reason: 'パラメータ未抽選');
      await tapRoyal(tester, '🎲 Roll');
      await tester.pump(const Duration(seconds: 1));
      await settle(tester, frames: 2);
      expect(enabled(tester, 'Next →'), isTrue);
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });

  testWidgets('戻るボタンで前のステップに戻っても、属性とデザイン言葉の選択が残る', (tester) async {
    await openCreation(tester);
    await toParameterStep(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '← Back'));
    await settle(tester);
    expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: '属性の選択が残る');
    expect(enabled(tester, 'Next →'), isTrue);
    await tester.tap(find.widgetWithText(OutlinedButton, '← Back'));
    await settle(tester);
    expect(find.text('✓ Selected (3/3)'), findsOneWidget, reason: '言葉の選択が残る');
  });

  testWidgets('名前生成中はローディングを表示し、完了後に候補が出る', (tester) async {
    final gate = Completer<Map<String, dynamic>>();
    server.handlers['generateCardName'] = (_) => gate.future;
    await openCreation(tester);
    await toParameterStep(tester);
    await tapRoyal(tester, 'Next →');
    await tapRoyal(tester, 'Generate Name →');
    expect(find.byType(CircularProgressIndicator), findsWidgets, reason: '生成中のインジケータ');
    expect(enabled(tester, 'Create for 🪙100'), isFalse);
    gate.complete({
      'names': ['Alpha', 'Beta']
    });
    await settle(tester);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('名前を再生成すると、消えた候補を選択したままにしない（作成ボタンが無効に戻る）', (tester) async {
    await openCreation(tester);
    await toNamingStep(tester);
    await tapText(tester, 'Alpha');
    expect(enabled(tester, 'Create for 🪙100'), isTrue);
    server.handlers['generateCardName'] = (_) => {
          'names': ['Delta', 'Epsilon']
        };
    await tapText(tester, 'Generate More Options');
    await settle(tester);
    expect(find.text('Delta'), findsOneWidget);
    expect(enabled(tester, 'Create for 🪙100'), isFalse);
  });

  testWidgets('作成成功: 確認→作成→開封→コレクション追加、コインはサーバー値、画面が閉じる', (tester) async {
    final errors = await collectErrors(() async {
      final c = await openCreation(tester);
      await toNamingStep(tester);
      await tapText(tester, 'Beta');
      await tapRoyal(tester, 'Create for 🪙100');
      expect(find.text('Confirm Card Creation'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(ElevatedButton)));
      await settle(tester, frames: 4);
      expect(createCalls, hasLength(1));
      final p = createCalls.single;
      expect(p['cardNameJp'], 'Beta');
      expect((p['attackPower'] as int) + (p['defensePower'] as int) + (p['speed'] as int), inInclusiveRange(34, 40));
      // 開封ダイアログ
      expect(find.text('🎴 Tap to open'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(CardRevealDialog), matching: find.byType(GestureDetector)).first);
      await settle(tester);
      await tapRoyal(tester, 'Add to Collection');
      await settle(tester, frames: 8);
      expect(c.read(walletProvider).coinBalance, 400);
      expect(c.read(myCardsProvider).any((x) => x.cardId == 'new1'), isTrue);
      expect(find.text('Confirm Card Creation'), findsNothing);
      expect(find.byType(RoyalButton), findsNothing, reason: '作成画面が閉じてカード一覧に戻る');
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });

  testWidgets('コイン不足: スナックバーで知らせ、サーバーを呼ばず、ショップへ誘導できる', (tester) async {
    await openCreation(tester, coins: 50);
    await toNamingStep(tester);
    await tapText(tester, 'Alpha');
    await tapRoyal(tester, 'Create for 🪙100');
    expect(find.text('Not enough coins'), findsWidgets);
    expect(find.text('Confirm Card Creation'), findsNothing);
    expect(createCalls, isEmpty);
    await tester.tap(find.text('Go to Shop'));
    await settle(tester);
    expect(find.text('Restore Purchases'), findsOneWidget, reason: 'ショップが開く');
  });

  testWidgets('サーバーが日本語エラーを返しても、英語UIは日本語を出さずコインも減らない', (tester) async {
    server.handlers['createCard'] =
        (_) => throw FirebaseFunctionsException(message: 'コインが不足しています', code: 'failed-precondition');
    final c = await openCreation(tester);
    await toNamingStep(tester);
    await tapText(tester, 'Alpha');
    await tapRoyal(tester, 'Create for 🪙100');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(ElevatedButton)));
    await settle(tester, frames: 4);
    expect(find.text('Not enough coins'), findsWidgets);
    expect(japaneseTexts(tester), isEmpty, reason: japaneseTexts(tester).join(' / '));
    expect(c.read(walletProvider).coinBalance, 500);
    expect(find.text('Confirm Card Creation'), findsNothing);
    expect(find.byType(Dialog), findsNothing, reason: '読み込み中ダイアログが残らない');
  });

  testWidgets('通信失敗(コイン不足以外)では「コイン不足」と誤表示しない', (tester) async {
    server.handlers['createCard'] = (_) => throw StateError('network');
    await openCreation(tester);
    await toNamingStep(tester);
    await tapText(tester, 'Alpha');
    await tapRoyal(tester, 'Create for 🪙100');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(ElevatedButton)));
    await settle(tester, frames: 4);
    expect(find.textContaining("Couldn't create the card"), findsOneWidget);
    expect(find.text('Not enough coins'), findsNothing);
  });

  testWidgets('名前生成サーバーが失敗してもフォールバック名で先へ進める', (tester) async {
    server.handlers.remove('generateCardName');
    await openCreation(tester);
    await toNamingStep(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tapText(tester, 'Power Card');
    expect(enabled(tester, 'Create for 🪙100'), isTrue);
  });

  for (final lang in ['ja', 'en']) {
    for (final vp in viewports) {
      testWidgets('ステップ0〜4を進めても例外・オーバーフローが出ない [$lang/${vp.name}]', (tester) async {
        final errors = await collectErrors(() async {
          await openCreation(tester, locale: Locale(lang), vp: vp);
          for (final w in kCardDesignWords.take(3)) {
            await tapText(tester, designWordLabel(w, lang));
          }
          Future<void> next() async {
            final b = find.byType(RoyalButton).last;
            await tester.ensureVisible(b);
            await tester.tap(b);
            await settle(tester, frames: 3);
          }

          await next(); // → 属性
          await tapText(tester, lang == 'en' ? 'Joy' : '喜（Joy）');
          await next(); // → パラメータ
          await tester.tap(find.byType(RoyalButton).first);
          await tester.pump(const Duration(seconds: 1));
          await settle(tester, frames: 2);
          await next(); // → 口調
          await next(); // → 名前（フォールバック名）
          await settle(tester);
          if (lang == 'en') expect(japaneseTexts(tester), isEmpty, reason: japaneseTexts(tester).join(' / '));
        }, tag: 'create flow [$lang/${vp.name}]');
        expect(errors, isEmpty, reason: errors.join('; '));
      });
    }
  }
}
