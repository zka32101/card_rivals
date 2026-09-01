import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/game_state_provider.dart';
import '../widgets/card_widget.dart';
import '../theme/kingdom_theme.dart';
import 'card_creation_screen_v2.dart';
import 'tutorial_battle_screen.dart';
import 'pvp_battle_screen_v2.dart';
import 'defense_deck_screen.dart';
import 'ranking_screen_v3.dart';
import 'tutorial_screen.dart';
import 'achievements_screen.dart';
import 'event_challenges_widget.dart';
import '../services/sound_service.dart';
import '../widgets/daily_quests_widget.dart';
import '../widgets/daily_missions_widget.dart';
import '../widgets/daily_reward_dialog.dart';
import 'collection_screen.dart';
import 'popular_cards_screen.dart';
import 'card_rental_settings_screen.dart';
import 'season_screen.dart';
import '../providers/migration_provider.dart';
import '../l10n/app_localizations.dart';

class HomeScreenV2 extends ConsumerStatefulWidget {
  const HomeScreenV2({super.key});

  @override
  ConsumerState<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends ConsumerState<HomeScreenV2> {
  bool _dailyRewardChecked = false;

  void _maybeShowDailyReward() {
    if (_dailyRewardChecked || !mounted) return;
    _dailyRewardChecked = true;
    final wallet = ref.read(walletProvider);
    if (!wallet.canClaimDailyLogin) return; // 本日は既に受取済み
    _showDailyReward();
  }

  void _showDailyReward() {
    final day = ref.read(walletProvider).pendingLoginStreakDay;
    DailyRewardDialog.show(
      context,
      currentDay: day,
      onClaim: (coins) {
        final w = ref.read(walletProvider);
        final updated = w.claimDailyLogin(coins);
        ref.read(walletProvider.notifier).state = updated;
        final userId = ref.read(currentUserIdProvider);
        if (userId != null) updateWallet(userId, updated);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final rank = ref.watch(myPlayerRankProvider).valueOrNull ?? const PlayerRank();
    final wallet = ref.watch(walletProvider);
    final defenseDeck = ref.watch(defenseDeckProvider);

    // walletProviderのハイドレーション完了（Firestoreからの実データ反映）を待ってから
    // デイリーログイン受取可否を判定する。ハイドレーション前のデフォルト値
    // （lastLoginDate=''）で判定すると、再起動のたびに何度でも受け取れてしまう。
    final uid = ref.watch(currentUserIdProvider);
    final hydratedUid = ref.watch(walletHydratedForUidProvider);
    if (uid != null && hydratedUid == uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDailyReward());
    }

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        titleSpacing: 12,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CrestTitle(title: t.home_appTitle, subtitle: t.home_appSubtitle),
        ),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
        actions: [
          // 🔥 連勝ストリーク
          if (wallet.winStreak >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: Kingdom.spaceSm),
              child: _AppBarChip(
                text: t.home_winStreakChip(wallet.winStreak),
                color: Kingdom.angerCrimson,
              ),
            ),
          // 🪙 コイン残高 / 💎 ジェム残高（タップでショップへ）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceXs, vertical: Kingdom.spaceSm),
            child: GestureDetector(
              onTap: () => context.push('/shop'),
              child: SizedBox(
                height: Kingdom.minTapTarget,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AppBarChip(text: '🪙${wallet.coinBalance}', color: Kingdom.gilt),
                      const SizedBox(width: Kingdom.spaceXs),
                      _AppBarChip(text: '💎${wallet.gemBalance}', color: Kingdom.sadnessIndigo),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ティアバッジ
          Padding(
            padding: const EdgeInsets.only(right: Kingdom.spaceXs),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RankingScreenV3())),
              child: SizedBox(
                height: Kingdom.minTapTarget,
                child: Center(
                  child: _AppBarChip(text: '${rank.tierEmoji} ${rank.tierLabel}', color: Kingdom.sadnessIndigo),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard_outlined, color: Kingdom.gilt),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
            tooltip: t.home_achievementsTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Kingdom.gilt),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
            tooltip: t.home_tutorialTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.library_books_outlined, color: Kingdom.gilt),
            onPressed: () => context.push('/explanation'),
            tooltip: t.home_explanationTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Kingdom.gilt),
            onPressed: () => context.push('/settings'),
            tooltip: t.home_settingsTooltip,
          ),
        ],
      ),
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Kingdom.night, Kingdom.nightDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SizedBox.expand(),
          ),
          const Positioned.fill(child: EmotionMoteField()),
          RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Kingdom.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // セクション1: ボーナス情報
                _SectionHeader(title: t.home_todayStatusHeader),
                const SizedBox(height: Kingdom.spaceSm),
                GestureDetector(
                  onTap: () => context.push('/bonus-detail'),
                  child: _BonusBannerV2(wallet: wallet),
                ),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション1.5: デイリークエスト
                _SectionHeader(title: t.home_dailyQuestsHeader),
                const SizedBox(height: Kingdom.spaceSm),
                const DailyQuestsWidget(),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション1.75: 本日のミッション
                const DailyMissionsWidget(),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション1.9: 属性の国への移住
                const _MigrationBannerV2(),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション2: メインアクション
                _SectionHeader(title: t.home_startBattleHeader),
                const SizedBox(height: Kingdom.spaceSm),
                _MainActionsV2(context: context),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション2.5: イベントチャレンジ
                const EventChallengesWidget(),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション2.75: カードマーケット
                _SectionHeader(title: t.home_cardMarketHeader),
                const SizedBox(height: Kingdom.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PopularCardsScreen()),
                        ),
                        child: OrnateFrame(
                          accent: Kingdom.sadnessIndigo,
                          padding: const EdgeInsets.all(Kingdom.spaceMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.home_rentCardTitle,
                                  style: Kingdom.label(size: 12, color: const Color(0xFF7C9CDB))),
                              const SizedBox(height: Kingdom.spaceXs),
                              Text(t.home_popularityRankingLabel,
                                  style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.parchment.withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Kingdom.spaceSm),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CardRentalSettingsScreen()),
                        ),
                        child: OrnateFrame(
                          accent: Kingdom.joyGold,
                          padding: const EdgeInsets.all(Kingdom.spaceMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.home_lendCardTitle,
                                  style: Kingdom.label(size: 12, color: const Color(0xFFE8C368))),
                              const SizedBox(height: Kingdom.spaceXs),
                              Text(t.home_publicSettingsRevenueLabel,
                                  style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.parchment.withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション3: デッキ管理
                _SectionHeader(title: t.home_defenseDeckHeader),
                const SizedBox(height: Kingdom.spaceSm),
                _DefenseDeckSectionV2(defenseDeck: defenseDeck, context: context),
                const SizedBox(height: Kingdom.spaceXxl),

                // セクション4: カード管理
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(title: t.home_yourCardsHeader),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionScreen())),
                      icon: const Icon(Icons.grid_view, size: 14, color: Kingdom.gilt),
                      label: Text(t.home_viewAllButton, style: TextStyle(fontSize: 12, color: Kingdom.gilt)),
                    ),
                  ],
                ),
                const SizedBox(height: Kingdom.spaceSm),
                _CardSectionV2(context: context),
                SizedBox(height: Kingdom.spaceLg + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _AppBarChip extends StatelessWidget {
  final String text;
  final Color color;
  const _AppBarChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: Kingdom.spaceXs),
      decoration: BoxDecoration(
        color: Kingdom.night,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
      ),
      child: Text(text,
          style: TextStyle(fontSize: Kingdom.textCaption, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceXs),
      child: Text(title, style: Kingdom.title(size: 16)),
    );
  }
}

class _BonusBannerV2 extends StatelessWidget {
  final WalletState wallet;
  const _BonusBannerV2({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final todayRatio = wallet.todayWins / 20.0;
    return OrnateFrame(
      accent: Kingdom.joyGold,
      gradient: const LinearGradient(
        colors: [Color(0xFF3D2C0A), Color(0xFF5A4110)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.bonusBanner_today, style: Kingdom.label(size: 12, color: Kingdom.parchment.withValues(alpha: 0.8))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: 2),
                decoration: BoxDecoration(
                  color: Kingdom.gilt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.6)),
                ),
                child: Text(t.home_tapForBonusLabel,
                    style: Kingdom.label(size: 10, color: Kingdom.gilt)),
              ),
            ],
          ),
          const SizedBox(height: Kingdom.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.home_todayCoinsProgress(wallet.todayPoints),
                  style: TextStyle(
                      fontFamily: Kingdom.displayFont,
                      color: Kingdom.gilt,
                      fontWeight: FontWeight.w900,
                      fontSize: 24)),
              Text(t.home_todayWinsProgress(wallet.todayWins),
                  style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.75), fontSize: Kingdom.textBody)),
            ],
          ),
          const SizedBox(height: Kingdom.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: todayRatio.clamp(0.0, 1.0),
              backgroundColor: Kingdom.night,
              valueColor: const AlwaysStoppedAnimation<Color>(Kingdom.gilt),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MigrationBannerV2 extends ConsumerWidget {
  const _MigrationBannerV2();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final favored = ref.watch(weeklyFavoredAttributeProvider);
    final active = ref.watch(activeMigrationAttributeProvider);
    final wallet = ref.watch(walletProvider);
    final isMigrated = active == favored;
    final emoji = migrationAttributeEmoji(favored);
    final label = migrationAttributeLabel(favored);
    final accent = Kingdom.attributeColor(favored);

    return OrnateFrame(
      accent: accent,
      gradient: LinearGradient(
        colors: Kingdom.attributeGradient(favored),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: Kingdom.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.home_weeklyFavoredLabel(label), style: Kingdom.label(size: Kingdom.textBody, color: accent)),
                const SizedBox(height: 2),
                Text(
                  isMigrated
                      ? t.home_migratedStatus
                      : t.home_migrationOffer(kMigrationCost),
                  style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.75), fontSize: Kingdom.textCaption),
                ),
              ],
            ),
          ),
          if (!isMigrated)
            RoyalButton(
              label: t.home_migrateButton,
              accent: accent,
              height: 36,
              onPressed: wallet.coinBalance >= kMigrationCost
                  ? () {
                      final success = migrateToFavoredAttribute(ref);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.home_migrationSuccessSnackbar(label))),
                        );
                      }
                    }
                  : null,
            )
          else
            Icon(Icons.verified, color: Kingdom.gilt, size: 28),
        ],
      ),
    );
  }
}

class _MainActionsV2 extends StatelessWidget {
  final BuildContext context;
  const _MainActionsV2({required this.context});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      children: [
        // PvP ボタン（大きく目立たせる）
        SizedBox(
          height: 70,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Kingdom.angerCrimson, Kingdom.angerCrimsonDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.6), width: 1.4),
              boxShadow: [
                BoxShadow(color: Kingdom.angerCrimson.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  playSound(SoundEffect.tap);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PvpBattleScreenV2()));
                },
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.home_pvpButton,
                        style: TextStyle(
                            fontFamily: Kingdom.displayFont,
                            color: Kingdom.parchment,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(t.home_pvpRewardCaption,
                        style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.75), fontSize: Kingdom.textCaption)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // AI 練習 + ランキング（小さめ）
        Row(
          children: [
            Expanded(
              child: _KingdomActionTile(
                accent: Kingdom.sadnessIndigo,
                emoji: '🤖',
                title: t.home_aiPracticeTitle,
                subtitle: t.home_noBonusLabel,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TutorialBattleScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KingdomActionTile(
                accent: Kingdom.joyGold,
                emoji: '🏆',
                title: t.home_rankingTitle,
                subtitle: t.home_checkRankLabel,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RankingScreenV3())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // シーズン（フル幅）
        _KingdomActionTile(
          accent: Kingdom.lightSkyBlue,
          emoji: '⚔️',
          title: t.home_seasonTitle,
          subtitle: t.home_seasonSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SeasonScreen()),
          ),
          fullWidth: true,
        ),
      ],
    );
  }
}

class _KingdomActionTile extends StatelessWidget {
  final Color accent;
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool fullWidth;

  const _KingdomActionTile({
    required this.accent,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      height: fullWidth ? 70 : 60,
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$emoji $title',
                  style: Kingdom.label(size: Kingdom.textBody, color: accent)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: accent.withValues(alpha: 0.7), fontSize: 9)),
            ],
          ),
        ),
      ),
    );

    return tile;
  }
}

class _DefenseDeckSectionV2 extends StatelessWidget {
  final List<dynamic> defenseDeck;
  final BuildContext context;
  const _DefenseDeckSectionV2({required this.defenseDeck, required this.context});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return OrnateFrame(
      accent: Kingdom.bronze,
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                defenseDeck.isEmpty ? t.home_notSetLabel : t.home_deckCountSet(defenseDeck.length),
                style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.6)),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DefenseDeckScreen()),
                ),
                icon: const Icon(Icons.edit, size: 16, color: Kingdom.gilt),
                label: Text(t.home_changeButton, style: TextStyle(fontSize: 12, color: Kingdom.gilt)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          defenseDeck.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Kingdom.spaceXl),
                    child: Text(
                      t.home_tapToSetDeckHint,
                      style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: defenseDeck.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: CardThumbnail(card: defenseDeck[i], size: 70),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _CardSectionV2 extends StatelessWidget {
  final BuildContext context;
  const _CardSectionV2({required this.context});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return OrnateFrame(
      accent: Kingdom.sadnessIndigo,
      padding: const EdgeInsets.all(Kingdom.spaceLg),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, size: 40, color: Kingdom.sadnessIndigo),
          const SizedBox(height: Kingdom.spaceSm),
          Text(t.home_noCardsYetTitle,
              style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.85)),
              textAlign: TextAlign.center),
          const SizedBox(height: Kingdom.spaceXs),
          Text(t.home_aiAutoImageCaption,
              style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: Kingdom.spaceMd),
          RoyalButton(
            label: t.home_createCardButton,
            icon: Icons.add,
            onPressed: () {
              playSound(SoundEffect.tap);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CardCreationScreenV2()));
            },
          ),
        ],
      ),
    );
  }
}
