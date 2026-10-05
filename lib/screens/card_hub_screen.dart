import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/kingdom_theme.dart';
import 'card_rental_settings_screen.dart';
import 'collection_screen.dart';
import 'deck_list_screen.dart';
import 'popular_cards_screen.dart';

/// 下部ナビの「カード」タブ。カード一覧・デッキ（防衛デッキ／対戦用のお気に入りデッキ）・
/// カードマーケット（レンタル）をひとつにまとめる。
class CardHubScreen extends StatelessWidget {
  const CardHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Kingdom.night,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(t.collection_title, style: Kingdom.title(size: 17)),
          backgroundColor: Kingdom.nightDeep,
          elevation: 0,
          bottom: TabBar(
            labelColor: Kingdom.gilt,
            unselectedLabelColor: Kingdom.parchment.withValues(alpha: 0.6),
            indicatorColor: Kingdom.gilt,
            tabs: [
              Tab(icon: const Icon(Icons.style, size: 18), text: t.cardHub_tabCards),
              Tab(icon: const Icon(Icons.dashboard_customize_outlined, size: 18), text: t.cardHub_tabDecks),
              Tab(icon: const Icon(Icons.storefront_outlined, size: 18), text: t.cardHub_tabMarket),
            ],
          ),
        ),
        // 各タブの状態（検索語・スクロール位置）は TabBarView が保持する
        body: const TabBarView(
          children: [
            CollectionScreen(embedded: true),
            DeckListScreen(embedded: true),
            _CardMarketTab(),
          ],
        ),
      ),
    );
  }
}

class _CardMarketTab extends StatelessWidget {
  const _CardMarketTab();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: Kingdom.spaceSm),
          child: Text(t.home_cardMarketHeader, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Kingdom.nightDeep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.25)),
          ),
          // 色付きContainerの中でListTileの波紋が見えなくなるのを防ぐ透明Material
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                _MarketTile(
                  icon: Icons.download_outlined,
                  color: Kingdom.sadnessIndigo,
                  label: t.home_rentCardTitle,
                  caption: t.home_popularityRankingLabel,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PopularCardsScreen()),
                  ),
                ),
                Divider(height: 1, indent: 56, color: Kingdom.parchment.withValues(alpha: 0.1)),
                _MarketTile(
                  icon: Icons.upload_outlined,
                  color: Kingdom.joyGold,
                  label: t.home_lendCardTitle,
                  caption: t.home_publicSettingsRevenueLabel,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CardRentalSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String caption;
  final VoidCallback onTap;
  const _MarketTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: Kingdom.minTapTarget,
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold)),
      subtitle: Text(caption, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: Kingdom.parchment.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }
}
