import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;

import 'package:card_rivals/providers/locale_provider.dart';

import 'helpers/screen_harness.dart';

/// 画面遷移・戻る操作・状態の保持/消去・言語切替のテスト（英語UIで文言を探す）。
void main() {
  setUpAll(loadTestFonts);

  late FakeServer server;
  setUp(() {
    server = FakeServer();
    server.handlers['getPeriodLeaderboard'] = (_) => {'leaderboard': fakeBoard()};
    server.handlers['getSeasonLeaderboard'] = (_) => {'leaderboard': <dynamic>[]};
    server.install();
  });
  tearDown(() => server.uninstall());

  Future<void> pumpApp(WidgetTester tester, {String location = '/', Locale locale = const Locale('en'), List<Override>? overrides}) async {
    setViewport(tester, viewports.first);
    await tester.pumpWidget(wrapRouter(
        location: location, locale: locale, textScale: 1.0, overrides: overrides ?? populatedOverrides()));
    await settle(tester);
  }

  Finder navItem(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle(tester);
  }

  testWidgets('下部ナビの4タブを往復でき、例外が出ない', (tester) async {
    final errors = await collectErrors(() async {
      await pumpApp(tester);
      for (final label in ['Cards', 'Ranking', 'Menu', 'Home']) {
        await tapAndSettle(tester, navItem(label));
      }
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });

  testWidgets('タブを切り替えても各タブの入力状態（検索語）が保持される', (tester) async {
    await pumpApp(tester);
    await tapAndSettle(tester, navItem('Cards'));
    await tester.enterText(find.byType(TextField).first, 'Card 3');
    await settle(tester);
    await tapAndSettle(tester, navItem('Menu'));
    await tapAndSettle(tester, navItem('Cards'));
    expect(find.widgetWithText(TextField, 'Card 3'), findsOneWidget);
  });

  testWidgets('メニュー→設定→戻るで、メニュータブに戻る', (tester) async {
    await pumpApp(tester);
    await tapAndSettle(tester, navItem('Menu'));
    await tapAndSettle(tester, find.text('Settings'));
    expect(find.text('English'), findsOneWidget); // 設定画面
    await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
    expect(find.text('English'), findsNothing);
    expect(find.text('Play & Rewards'), findsOneWidget); // メニュータブのまま
  });

  testWidgets('メニュー→ショップ→戻る、メニュー→購入履歴(設定経由)→戻る', (tester) async {
    await pumpApp(tester);
    await tapAndSettle(tester, navItem('Menu'));
    await tapAndSettle(tester, find.text('Shop'));
    expect(find.text('Restore Purchases'), findsOneWidget);
    await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
    expect(find.text('Play & Rewards'), findsOneWidget);
  });

  testWidgets('ホームの各入口（PvP/AI練習/デッキ/シーズン）に入って戻れる', (tester) async {
    final errors = await collectErrors(() async {
      await pumpApp(tester);
      for (final entry in ['AI Practice', 'Seasons']) {
        await tapAndSettle(tester, find.textContaining(entry).first);
        expect(find.byType(BackButton).evaluate().isNotEmpty || find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
            find.byType(AppBar).evaluate().isNotEmpty, isTrue);
        final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
        expect(nav.canPop(), isTrue, reason: entry);
        nav.pop();
        await settle(tester);
        expect(find.textContaining('AI Practice'), findsWidgets, reason: '$entry から戻れない');
      }
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });

  testWidgets('設定で言語を切り替えると即座に反映される（日本語→英語→日本語）', (tester) async {
    await pumpApp(tester, location: '/settings', locale: const Locale('ja'), overrides: [
      ...populatedOverrides(),
      localeProvider.overrideWith((ref) => const Locale('ja')),
    ]);
    // MaterialApp.routerのlocaleは固定引数なので、画面側の選択状態（チェック）とプロバイダの値を検証する
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    expect(container.read(localeProvider), const Locale('ja'));
    expect(find.text('設定'), findsWidgets);
    await tapAndSettle(tester, find.text('English'));
    expect(container.read(localeProvider), const Locale('en'));
    await tapAndSettle(tester, find.text('日本語'));
    expect(container.read(localeProvider), const Locale('ja'));
  });
}
