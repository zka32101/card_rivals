import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_rivals/screens/card_creation_screen_v2.dart';
import 'package:card_rivals/screens/card_hub_screen.dart';
import 'package:card_rivals/screens/deck_list_screen.dart';
import 'package:card_rivals/screens/deck_selection_screen_v2.dart';
import 'package:card_rivals/screens/home_screen_v2.dart';
import 'package:card_rivals/screens/popular_cards_screen.dart';
import 'package:card_rivals/screens/pvp_battle_screen_v2.dart';
import 'package:card_rivals/screens/ranking_screen_v3.dart';
import 'package:card_rivals/screens/season_screen.dart';
import 'package:card_rivals/screens/tutorial_battle_screen.dart';

import 'helpers/screen_harness.dart';

/// データが入った状態（所持カード・デッキ・ランキング・コイン等）での全画面スモーク。
/// 空/失敗状態は all_screens_smoke_test.dart（Firebase未接続=全読み込み失敗）が担当。
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

  final routes = ['/', '/shop', '/settings', '/bonus-detail', '/purchase-history', '/season'];
  final screens = <String, Widget Function()>{
    'CardHub': () => const CardHubScreen(),
    'DeckList': () => const DeckListScreen(),
    'DeckSelection': () => DeckSelectionScreenV2(onConfirm: (_) {}),
    'CardCreation': () => const CardCreationScreenV2(),
    'Home': () => const HomeScreenV2(),
    'Ranking': () => const RankingScreenV3(),
    'PopularCards': () => const PopularCardsScreen(),
    'Pvp': () => const PvpBattleScreenV2(),
    'TutorialBattle': () => const TutorialBattleScreen(),
    'SeasonLeaderboard': () => const SeasonLeaderboardScreen(),
  };

  for (final lang in ['ja', 'en']) {
    for (final vp in viewports) {
      for (final r in routes) {
        testWidgets('データあり route $r [$lang/${vp.name}]', (tester) async {
          setViewport(tester, vp);
          final errors = await collectErrors(() async {
            await tester.pumpWidget(wrapRouter(
                location: r, locale: Locale(lang), textScale: vp.textScale, overrides: populatedOverrides()));
            await settle(tester);
          }, tag: 'data route $r [$lang/${vp.name}]');
          expect(errors, isEmpty, reason: errors.join('; '));
          if (lang == 'en') expect(japaneseTexts(tester), isEmpty, reason: japaneseTexts(tester).join(' / '));
        });
      }
      screens.forEach((name, build) {
        testWidgets('データあり screen $name [$lang/${vp.name}]', (tester) async {
          setViewport(tester, vp);
          final errors = await collectErrors(() async {
            await tester.pumpWidget(wrapApp(
                child: build(), locale: Locale(lang), textScale: vp.textScale, overrides: populatedOverrides()));
            await settle(tester);
          }, tag: 'data screen $name [$lang/${vp.name}]');
          expect(errors, isEmpty, reason: errors.join('; '));
          if (lang == 'en') expect(japaneseTexts(tester), isEmpty, reason: japaneseTexts(tester).join(' / '));
        });
      });
    }
  }
}
