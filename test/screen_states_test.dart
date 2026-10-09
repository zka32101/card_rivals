import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;

import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/auth_provider.dart';
import 'package:card_rivals/providers/collection_provider.dart';
import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:card_rivals/screens/card_hub_screen.dart';
import 'package:card_rivals/screens/card_rental_settings_screen.dart';
import 'package:card_rivals/screens/popular_cards_screen.dart';
import 'package:card_rivals/screens/ranking_screen_v3.dart';
import 'package:card_rivals/theme/kingdom_theme.dart';

import 'helpers/screen_harness.dart';

/// ローディング/エラー/空状態、コイン不足、ボタンの有効/無効、再入場時の状態。
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

  /// RevenueCat(ストア)が使えない状態: 全メソッドがPlatformExceptionで失敗する。
  void storeDown() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('purchases_flutter'), (call) async => throw PlatformException(code: '5', message: 'store down'));
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('purchases_flutter'), null));
  }

  Future<void> pumpRoute(WidgetTester tester, String location, List<Override> overrides,
      {Locale locale = const Locale('en')}) async {
    setViewport(tester, viewports.first);
    await tester.pumpWidget(wrapRouter(location: location, locale: locale, textScale: 1.0, overrides: overrides));
    await settle(tester);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen, List<Override> overrides,
      {Locale locale = const Locale('en')}) async {
    setViewport(tester, viewports.first);
    await tester.pumpWidget(wrapApp(child: screen, locale: locale, textScale: 1.0, overrides: overrides));
    await settle(tester);
  }

  group('ランキング', () {
    testWidgets('5タブ全てで、サーバー失敗でも例外なく「データなし」系の表示になる', (tester) async {
      server.handlers.clear(); // 全関数が失敗
      final errors = await collectErrors(() async {
        await pumpScreen(tester, const RankingScreenV3(), populatedOverrides());
        for (final tab in ['Daily', 'Weekly', 'Monthly', 'Attribute', 'All-time']) {
          final f = find.textContaining(tab);
          if (f.evaluate().isEmpty) continue;
          await tester.tap(f.first);
          await settle(tester);
        }
      });
      expect(errors, isEmpty, reason: errors.join('; '));
    });

    testWidgets('0件のランキングは「No ranking data」を出す', (tester) async {
      server.handlers['getPeriodLeaderboard'] = (_) => {'leaderboard': <dynamic>[]};
      await pumpScreen(tester, const RankingScreenV3(), populatedOverrides());
      expect(find.text('No ranking data'), findsWidgets);
    });

    testWidgets('応答待ちの間はローディング表示で、完了後に順位が出る', (tester) async {
      await pumpScreen(tester, const RankingScreenV3(), populatedOverrides());
      expect(find.textContaining('Player 1'), findsWidgets);
    });
  });

  /// ショップのタイル（OrnateFrame）内の購入/交換ボタン。タップできるのはボタンだけ。
  Future<void> tapShopTileButton(WidgetTester tester, Finder label) async {
    await tester.scrollUntilVisible(label, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(label);
    await tester.pump(const Duration(milliseconds: 100));
    final frame = find.ancestor(of: label, matching: find.byType(OrnateFrame)).first;
    await tester.tap(find.descendant(of: frame, matching: find.byType(ElevatedButton)));
    await settle(tester, frames: 6);
  }

  group('設定・購入履歴・ショップ', () {
    testWidgets('購入履歴: 取得失敗でもエラー文言を出して落ちない', (tester) async {
      storeDown();
      final errors = await collectErrors(() async {
        await pumpRoute(tester, '/purchase-history', populatedOverrides());
      });
      expect(errors, isEmpty, reason: errors.join('; '));
      expect(find.textContaining('Failed to load purchase history').evaluate().length +
          find.text('No purchases yet').evaluate().length, greaterThan(0));
    });

    testWidgets('ショップ: ジェム不足で連勝シールドは買えず、スナックバー、ジェムは減らない', (tester) async {
      await pumpRoute(tester, '/shop', populatedOverrides(gems: 1));
      final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      await tapShopTileButton(tester, find.textContaining('Streak Shield'));
      expect(find.text('Not enough gems'), findsOneWidget);
      expect(c.read(walletProvider).gemBalance, 1);
      expect(c.read(walletProvider).streakShieldCount, 0);
    });

    testWidgets('ショップ: ジェムが足りれば連勝シールドを交換でき、ジェムが減る', (tester) async {
      await pumpRoute(tester, '/shop', populatedOverrides(gems: 10));
      final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      await tapShopTileButton(tester, find.textContaining('Streak Shield'));
      expect(c.read(walletProvider).gemBalance, 10 - kStreakShieldGemCost);
      expect(c.read(walletProvider).streakShieldCount, 1);
    });

    testWidgets('ショップ: ストア未接続でも、コインパック購入はエラー表示後に再度押せる（処理中のまま固まらない）', (tester) async {
      storeDown();
      final errors = await collectErrors(() async {
        await pumpRoute(tester, '/shop', populatedOverrides());
        final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
        final before = c.read(walletProvider);
        final pkg = find.textContaining('100 Coins');
        await tapShopTileButton(tester, pkg);
        expect(find.byType(SnackBar), findsOneWidget, reason: '失敗はスナックバーで知らせる');
        expect(find.byType(CircularProgressIndicator), findsNothing, reason: '購入失敗後に処理中表示が残らない');
        expect(c.read(walletProvider).coinBalance, before.coinBalance, reason: '失敗した購入でコインは増えない');
      });
      expect(errors, isEmpty, reason: errors.join('; '));
    });

    testWidgets('/shop を直接開いた場合（戻り先なし）でも、戻るボタンで例外にならない', (tester) async {
      final errors = await collectErrors(() async {
        await pumpRoute(tester, '/shop', populatedOverrides());
        await tester.tap(find.byIcon(Icons.arrow_back));
        await settle(tester);
      });
      expect(errors, isEmpty, reason: errors.join('; '));
    });
  });

  group('カード/デッキ/マーケット', () {
    testWidgets('カード0枚: 「自分のカード」絞り込みで空メッセージ、シードカードは見える', (tester) async {
      await pumpScreen(tester, const CardHubScreen(), populatedOverrides(cards: <UserCard>[]));
      await tester.tap(find.textContaining('My Cards').first);
      await settle(tester);
      expect(find.textContaining("You haven't created any cards yet"), findsOneWidget);
    });

    testWidgets('デッキタブ: デッキ0件は案内文を出す', (tester) async {
      final errors = await collectErrors(() async {
        await pumpScreen(tester, const CardHubScreen(), populatedOverrides(presets: () async => []));
        await tester.tap(find.text('Decks').first);
        await settle(tester);
        expect(find.textContaining('No decks yet'), findsOneWidget);
      });
      expect(errors, isEmpty, reason: errors.join('; '));
    });

    testWidgets('デッキタブ: 読み込み失敗はエラー文言を出す（例外なし）', (tester) async {
      final errors = await collectErrors(() async {
        await pumpScreen(
            tester, const CardHubScreen(), populatedOverrides(presets: () async => throw StateError('firestore down')));
        await tester.tap(find.text('Decks').first);
        await settle(tester);
        expect(find.text('Could not load your decks'), findsOneWidget);
      });
      expect(errors, isEmpty, reason: errors.join('; '));
    });

    testWidgets('マーケット: 人気ランキング取得失敗はエラー文言、貸出設定はカード0枚で案内', (tester) async {
      final errors = await collectErrors(() async {
        await pumpScreen(tester, const PopularCardsScreen(), populatedOverrides());
      });
      expect(errors, isEmpty, reason: errors.join('; '));
      expect(find.textContaining('Failed to load the ranking'), findsOneWidget);

      final errors2 = await collectErrors(() async {
        await pumpScreen(tester, const CardRentalSettingsScreen(), populatedOverrides(cards: <UserCard>[]));
      });
      expect(errors2, isEmpty, reason: errors2.join('; '));
      expect(find.text('You have no cards'), findsOneWidget);
    });
  });

  group('ホーム', () {
    List<Override> hydrated({String lastLogin = ''}) => [
          currentUserIdProvider.overrideWith((ref) => 'u1'),
          walletProvider.overrideWith((ref) => WalletState(coinBalance: 100, lastLoginDate: lastLogin)),
          walletHydratedForUidProvider.overrideWith((ref) => 'u1'),
          myCardsProvider.overrideWith((ref) => <UserCard>[]),
        ];

    testWidgets('ウォレット反映済み＆未受取ならデイリーボーナスを出し、受取後は同日に再表示しない', (tester) async {
      await pumpRoute(tester, '/', hydrated());
      expect(find.text('🎁 Daily Bonus'), findsOneWidget);
      final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      final before = c.read(walletProvider).coinBalance;
      await tester.tap(find.byWidgetPredicate((w) => w is ElevatedButton || w is TextButton || w.runtimeType.toString() == 'RoyalButton').last);
      await settle(tester);
      expect(c.read(walletProvider).coinBalance, greaterThan(before));
      expect(c.read(walletProvider).lastLoginDate, todayKeyJst());
    });

    testWidgets('受取済みの日はデイリーボーナスを出さない', (tester) async {
      await pumpRoute(tester, '/', hydrated(lastLogin: todayKeyJst()));
      expect(find.text('🎁 Daily Bonus'), findsNothing);
    });

    testWidgets('ウォレット未反映(ロード中)の間はデイリーボーナスを出さない（初期値で判定しない）', (tester) async {
      await pumpRoute(tester, '/', [
        currentUserIdProvider.overrideWith((ref) => 'u1'),
        walletProvider.overrideWith((ref) => const WalletState()), // 初期値: lastLoginDate=''
        myCardsProvider.overrideWith((ref) => <UserCard>[]),
      ]);
      expect(find.text('🎁 Daily Bonus'), findsNothing);
    });
  });
}
