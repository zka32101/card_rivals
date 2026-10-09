import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:card_rivals/data/seed_cards_data.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:card_rivals/screens/battle_result_screen_v2.dart';
import 'package:card_rivals/services/battle_engine.dart';
import 'package:card_rivals/theme/kingdom_theme.dart';
import 'package:card_rivals/widgets/card_widget.dart';

import 'helpers/screen_harness.dart';

/// AI練習バトル・PvP・結果画面。
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

  List<PlayCard> seedDeck(int from) => [
        for (final sc in seedCardsData.skip(from).take(5))
          PlayCard(
            cardId: sc.cardId,
            attribute: sc.attribute,
            cost: sc.cost,
            attackPower: sc.attackPower,
            defensePower: sc.defensePower,
            speed: sc.speed,
            nameJp: sc.nameJp,
            nameEn: sc.nameEn,
            isSeedCard: true,
          ),
      ];

  Finder royal(String label) => find.byWidgetPredicate((w) => w is RoyalButton && w.label == label);

  Future<void> tapRoyal(WidgetTester tester, String label) async {
    await tester.ensureVisible(royal(label));
    await tester.tap(royal(label));
    await settle(tester, frames: 3);
  }

  Future<ProviderContainer> pumpHome(WidgetTester tester, {ScreenSpec? vp, Locale locale = const Locale('en')}) async {
    final v = vp ?? viewports.first;
    setViewport(tester, v);
    await tester.pumpWidget(wrapRouter(
        location: '/', locale: locale, textScale: v.textScale, overrides: populatedOverrides(cards: <UserCard>[])));
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  }

  Future<void> tapCard(WidgetTester tester, int i) async {
    final f = find.byType(CardWidget).at(i);
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 50));
    // 下の行はビューポートに半分しか入らないことがあるので、見えている上端付近をタップする
    await tester.tapAt(tester.getTopLeft(f) + const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// デッキ選択画面で先頭5枚を選んで確定する。
  Future<void> pickDeck(WidgetTester tester) async {
    expect(royal('Confirm This Deck'), findsNothing, reason: '5枚選ぶまで確定ボタンは「あとN枚」表示');
    for (var i = 0; i < 5; i++) {
      await tapCard(tester, i);
    }
    await tapRoyal(tester, 'Confirm This Deck');
  }

  testWidgets('デッキ選択: 5枚未満は確定不可、6枚目は選べず、選び直しで確定できる', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.textContaining('AI Practice').first);
    await settle(tester);
    for (var i = 0; i < 4; i++) {
      await tapCard(tester, i);
    }
    expect(royal('Confirm This Deck'), findsNothing);
    await tapCard(tester, 4);
    expect(royal('Confirm This Deck'), findsOneWidget);
    await tapCard(tester, 5); // 6枚目 → 警告のスナックバー、選択数は5のまま
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).first); // 選択済みを1枚外す → 確定が無効に戻る
    await tester.pump(const Duration(milliseconds: 100));
    expect(royal('Confirm This Deck'), findsNothing);
  });

  testWidgets('AI練習: デッキ選択→開始→結果画面→「ホームに戻る」でホームへ。報酬/連勝は動かない', (tester) async {
    final errors = await collectErrors(() async {
      final c = await pumpHome(tester);
      final walletBefore = c.read(walletProvider);
      await tester.tap(find.textContaining('AI Practice').first);
      await settle(tester);
      await pickDeck(tester);
      expect(find.text('Your Deck (5 cards)'), findsOneWidget);
      await tapRoyal(tester, '⚔️ Start Battle');
      // ログを800msずつ再生 → 結果画面へ自動遷移
      for (var i = 0; i < 120 && find.byType(BattleResultScreenV2).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await settle(tester);
      expect(find.byType(BattleResultScreenV2), findsOneWidget);
      expect(find.textContaining('Victory').evaluate().length + find.textContaining('Defeat').evaluate().length, greaterThan(0));
      final w = c.read(walletProvider);
      expect(w.winStreak, walletBefore.winStreak, reason: '練習では連勝は動かない');
      expect(w.coinBalance, walletBefore.coinBalance, reason: '練習ではコインは増えない');
      await tester.ensureVisible(find.text('Back to Home'));
      await tester.tap(find.text('Back to Home'));
      await settle(tester);
      expect(find.byType(BattleResultScreenV2), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'ホームのシェルに戻る');
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });

  testWidgets('PvP: サーバー成功→バトル→結果(サーバー確定)でボーナスが付き、連勝が増える', (tester) async {
    final opp = seedDeck(10);
    server.handlers['pvpMatch'] = (_) => {
          'matchId': 'm1',
          'opponentName': 'Rival',
          'opponentTier': 'Silver',
          'opponentDeck': [
            for (final c in opp)
              {
                'cardId': c.cardId,
                'attribute': c.attribute,
                'cost': c.cost,
                'attackPower': c.attackPower,
                'defensePower': c.defensePower,
                'speed': c.speed,
                'nameJp': c.nameJp,
              }
          ],
        };
    server.handlers['pvpBattle'] = (p) {
      final mine = (p['attackerDeckCardIds'] as List).cast<String>();
      return {
        'attackerWon': true,
        'finalAttackerHp': 12,
        'finalDefenderHp': 0,
        'logs': [
          {
            'turn': 1,
            'damage': 30,
            'attackerHp': 12,
            'defenderHp': 0,
            'attackerCardId': mine.first,
            'defenderCardId': opp.first.cardId,
            'multiplier': 1.0,
          }
        ],
      };
    };
    final errors = await collectErrors(() async {
      final c = await pumpHome(tester);
      final before = c.read(walletProvider);
      await tester.tap(find.textContaining('PvP Battle').first);
      await settle(tester);
      await pickDeck(tester);
      for (var i = 0; i < 160 && find.byType(BattleResultScreenV2).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await settle(tester);
      expect(server.calls, containsAll(['pvpMatch', 'pvpBattle']));
      expect(find.byType(BattleResultScreenV2), findsOneWidget);
      expect(find.text('Victory'), findsOneWidget);
      final w = c.read(walletProvider);
      expect(w.winStreak, before.winStreak + 1);
      expect(w.coinBalance, before.coinBalance + 1, reason: 'PvP勝利ボーナス🪙1');
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });

  testWidgets('PvP: サーバー失敗時はローカル対戦で進行し、コインも連勝も動かさない', (tester) async {
    final errors = await collectErrors(() async {
      final c = await pumpHome(tester);
      final before = c.read(walletProvider);
      await tester.tap(find.textContaining('PvP Battle').first);
      await settle(tester);
      await pickDeck(tester);
      for (var i = 0; i < 200 && find.byType(BattleResultScreenV2).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await settle(tester);
      expect(find.byType(BattleResultScreenV2), findsOneWidget);
      final w = c.read(walletProvider);
      expect(w.winStreak, before.winStreak);
      expect(w.coinBalance, before.coinBalance);
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });

  // 結果画面: 勝敗 × PvP/練習 × 言語 × 画面サイズ
  for (final lang in ['ja', 'en']) {
    for (final vp in viewports) {
      for (final win in [true, false]) {
        for (final pvp in [true, false]) {
          testWidgets('結果画面 ${win ? "勝利" : "敗北"} ${pvp ? "PvP" : "練習"} [$lang/${vp.name}]', (tester) async {
            final my = seedDeck(0);
            final opp = seedDeck(10);
            final result = BattleEngine.simulate(my, opp);
            final forced = BattleResult(
              attackerWon: win,
              finalAttackerHp: win ? result.finalAttackerHp : 0,
              finalDefenderHp: win ? 0 : 7,
              logs: result.logs,
            );
            final errors = await collectErrors(() async {
              setViewport(tester, vp);
              await tester.pumpWidget(wrapApp(
                locale: Locale(lang),
                textScale: vp.textScale,
                overrides: populatedOverrides(),
                child: BattleResultScreenV2(
                  result: forced,
                  isPvP: pvp,
                  myDeck: my,
                  opponentDeck: opp,
                  opponentName: pvp ? 'Rival' : null,
                  opponentTier: pvp ? 'Silver' : null,
                  seasonPointsGained: pvp && win ? 25 : null,
                  seasonRankedUp: pvp && win,
                  seasonNewRank: pvp && win ? 3 : null,
                ),
              ));
              await settle(tester, frames: 8);
            }, tag: 'result win=$win pvp=$pvp [$lang/${vp.name}]');
            expect(errors, isEmpty, reason: errors.join('; '));
            if (lang == 'en') expect(japaneseTexts(tester), isEmpty, reason: japaneseTexts(tester).join(' / '));
          });
        }
      }
    }
  }

  testWidgets('結果画面: ログが空でも落ちない', (tester) async {
    final errors = await collectErrors(() async {
      setViewport(tester, viewports.first);
      await tester.pumpWidget(wrapApp(
        locale: const Locale('en'),
        textScale: 1.0,
        overrides: populatedOverrides(),
        child: BattleResultScreenV2(
          result: BattleResult(attackerWon: false, finalAttackerHp: 0, finalDefenderHp: 5, logs: const []),
          isPvP: false,
          myDeck: const [],
          opponentDeck: const [],
        ),
      ));
      await settle(tester, frames: 8);
    });
    expect(errors, isEmpty, reason: errors.join('; '));
  });
}
