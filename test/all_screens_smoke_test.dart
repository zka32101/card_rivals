import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_rivals/screens/achievements_screen.dart';
import 'package:card_rivals/screens/card_creation_screen_v2.dart';
import 'package:card_rivals/screens/card_hub_screen.dart';
import 'package:card_rivals/screens/card_rental_settings_screen.dart';
import 'package:card_rivals/screens/collection_screen.dart';
import 'package:card_rivals/screens/deck_list_screen.dart';
import 'package:card_rivals/screens/deck_selection_screen_v2.dart';
import 'package:card_rivals/screens/defense_deck_screen.dart';
import 'package:card_rivals/screens/home_screen_v2.dart';
import 'package:card_rivals/screens/menu_screen.dart';
import 'package:card_rivals/screens/popular_cards_screen.dart';
import 'package:card_rivals/screens/pvp_battle_screen_v2.dart';
import 'package:card_rivals/screens/ranking_screen_v3.dart';
import 'package:card_rivals/screens/season_screen.dart';
import 'package:card_rivals/screens/tutorial_battle_screen.dart';
import 'package:card_rivals/screens/tutorial_screen.dart';

import 'helpers/screen_harness.dart';

/// go_routerの全ルート + Navigator.pushで開く使用中の画面を、
/// ja/en × 通常/狭幅(360x640)×フォント1.3/2.0 で一括ビルドし、
/// 例外・RenderFlexオーバーフローが出ないこと、英語で日本語が出ないことを確認する。
void main() {
  setUpAll(loadTestFonts);
  final routes = <String>['/', '/settings', '/shop', '/bonus-detail', '/purchase-history', '/terms', '/contact', '/season', '/explanation'];
  final pushed = <String, Widget Function()>{
    'CardHub': () => const CardHubScreen(),
    'Collection': () => const CollectionScreen(),
    'DeckList': () => const DeckListScreen(),
    'DeckSelection': () => DeckSelectionScreenV2(onConfirm: (_) {}),
    'CardCreation': () => const CardCreationScreenV2(),
    'Home': () => const HomeScreenV2(),
    'Ranking': () => const RankingScreenV3(),
    'Menu': () => const MenuScreen(),
    'PopularCards': () => const PopularCardsScreen(),
    'CardRentalSettings': () => const CardRentalSettingsScreen(),
    'Pvp': () => const PvpBattleScreenV2(),
    'TutorialBattle': () => const TutorialBattleScreen(),
    'Achievements': () => const AchievementsScreen(),
    'Tutorial': () => const TutorialScreen(),
    'DefenseDeck': () => const DefenseDeckScreen(),
    'SeasonLeaderboard': () => const SeasonLeaderboardScreen(),
    'SeasonRewards': () => const SeasonRewardsScreen(),
  };

  for (final lang in ['ja', 'en']) {
    for (final vp in viewports) {
      for (final r in routes) {
        testWidgets('route $r [$lang/${vp.name}]', (tester) async {
          setViewport(tester, vp);
          final errors = await collectErrors(() async {
            await tester.pumpWidget(wrapRouter(location: r, locale: Locale(lang), textScale: vp.textScale));
            await settle(tester);
          }, tag: 'route $r [$lang/${vp.name}]');
          expect(errors, isEmpty, reason: errors.join('; '));
          if (lang == 'en') {
            expect(japaneseTexts(tester), isEmpty, reason: japaneseTexts(tester).join(' / '));
          }
        });
      }
      pushed.forEach((name, build) {
        testWidgets('screen $name [$lang/${vp.name}]', (tester) async {
          setViewport(tester, vp);
          final errors = await collectErrors(() async {
            await tester.pumpWidget(wrapApp(child: build(), locale: Locale(lang), textScale: vp.textScale));
            await settle(tester);
          }, tag: 'screen $name [$lang/${vp.name}]');
          expect(errors, isEmpty, reason: errors.join('; '));
          if (lang == 'en') {
            expect(japaneseTexts(tester), isEmpty, reason: japaneseTexts(tester).join(' / '));
          }
        });
      });
    }
  }
}
