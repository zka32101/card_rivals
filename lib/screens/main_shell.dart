import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/kingdom_theme.dart';
import 'collection_screen.dart';
import 'home_screen_v2.dart';
import 'menu_screen.dart';
import 'ranking_screen_v3.dart';

/// アプリの骨格。下部ナビで「ホーム／カード／ランキング／メニュー」を切り替える。
/// 各タブはIndexedStackで状態（検索語・スクロール位置）を保ったまま保持する。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Kingdom.night,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreenV2(),
          CollectionScreen(embedded: true),
          RankingScreenV3(),
          MenuScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Kingdom.nightDeep,
          indicatorColor: Kingdom.gilt.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
              color: states.contains(WidgetState.selected)
                  ? Kingdom.gilt
                  : Kingdom.parchment.withValues(alpha: 0.6),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Kingdom.gilt
                  : Kingdom.parchment.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: t.nav_home,
            ),
            NavigationDestination(
              icon: const Icon(Icons.style_outlined),
              selectedIcon: const Icon(Icons.style),
              label: t.nav_cards,
            ),
            NavigationDestination(
              icon: const Icon(Icons.emoji_events_outlined),
              selectedIcon: const Icon(Icons.emoji_events),
              label: t.nav_ranking,
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu),
              selectedIcon: const Icon(Icons.menu_open),
              label: t.nav_menu,
            ),
          ],
        ),
      ),
    );
  }
}
