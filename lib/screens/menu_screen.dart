import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../theme/kingdom_theme.dart';
import 'achievements_screen.dart';
import 'card_rental_settings_screen.dart';
import 'popular_cards_screen.dart';
import 'tutorial_screen.dart';

/// 「メニュー」タブ。ホーム上部に散らばっていたアイコン類（実績・チュートリアル・
/// ガイド・設定）と、ショップ・カードレンタル・シーズンをここに集約する。
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t.nav_menu, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Kingdom.spaceMd),
        children: [
          _Section(title: t.menu_sectionPlay, items: [
            _MenuItem(
              icon: Icons.storefront_outlined,
              color: Kingdom.gilt,
              label: t.shop_title,
              onTap: () => context.push('/shop'),
            ),
            _MenuItem(
              icon: Icons.workspace_premium_outlined,
              color: Kingdom.joyGold,
              label: t.home_seasonTitle,
              onTap: () => context.push('/season'),
            ),
            _MenuItem(
              icon: Icons.card_giftcard_outlined,
              color: Kingdom.joyGold,
              label: t.achievements_title,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
            ),
          ]),
          _Section(title: t.home_cardMarketHeader, items: [
            _MenuItem(
              icon: Icons.download_outlined,
              color: Kingdom.sadnessIndigo,
              label: t.home_rentCardTitle,
              caption: t.home_popularityRankingLabel,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PopularCardsScreen())),
            ),
            _MenuItem(
              icon: Icons.upload_outlined,
              color: Kingdom.joyGold,
              label: t.home_lendCardTitle,
              caption: t.home_publicSettingsRevenueLabel,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardRentalSettingsScreen())),
            ),
          ]),
          _Section(title: t.menu_sectionHelp, items: [
            _MenuItem(
              icon: Icons.library_books_outlined,
              color: Kingdom.gilt,
              label: t.home_explanationTooltip,
              onTap: () => context.push('/explanation'),
            ),
            _MenuItem(
              icon: Icons.help_outline,
              color: Kingdom.gilt,
              label: t.home_tutorialTooltip,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
            ),
            _MenuItem(
              icon: Icons.settings_outlined,
              color: Kingdom.gilt,
              label: t.settings_title,
              onTap: () => context.push('/settings'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Kingdom.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: Kingdom.spaceSm),
            child: Text(title, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Kingdom.nightDeep,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.25)),
            ),
            // 色付きContainerの中でListTileの波紋が見えなくなる(assertion)のを防ぐため、
            // 透明なMaterialで包む
            child: Material(
              type: MaterialType.transparency,
              child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1)
                    Divider(height: 1, indent: 56, color: Kingdom.parchment.withValues(alpha: 0.1)),
                ],
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? caption;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: Kingdom.minTapTarget,
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold)),
      subtitle: caption == null
          ? null
          : Text(caption!, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: Kingdom.parchment.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }
}
