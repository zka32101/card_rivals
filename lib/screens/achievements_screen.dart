import 'package:flutter/material.dart' hide Badge;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/game_enrichment.dart';
import '../providers/game_state_provider.dart';
import '../providers/collection_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final rank = ref.watch(myPlayerRankProvider).valueOrNull ?? const PlayerRank();
    final wallet = ref.watch(walletProvider);
    final cardsCreated = ref.watch(myCardsProvider).length;

    final unlockedBadges = computeUnlockedBadges(
      wins: rank.wins,
      rating: rank.rating,
      cardsCreated: cardsCreated,
      loginStreak: wallet.loginStreak,
    );

    final achievements = getAchievementProgress(
      wins: rank.wins,
      losses: rank.losses,
      rating: rank.rating,
      cardsCreated: cardsCreated,
      dailyStreak: wallet.loginStreak,
      unlockedBadges: unlockedBadges,
    );

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.achievements_title, style: Kingdom.title(size: 17)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: SafeArea(
        child: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          SingleChildScrollView(
        padding: const EdgeInsets.all(Kingdom.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // バッジセクション
            _SectionHeader(title: t.achievements_unlockedBadgesHeader),
            const SizedBox(height: Kingdom.spaceMd),
            if (unlockedBadges.isEmpty)
              Container(
                padding: const EdgeInsets.all(Kingdom.spaceXl),
                decoration: BoxDecoration(
                  color: Kingdom.nightDeep,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(t.achievements_noBadgesMessage, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
                ),
              )
            else
              Wrap(
                spacing: Kingdom.spaceMd,
                runSpacing: Kingdom.spaceMd,
                children: [
                  for (final badge in unlockedBadges)
                    Container(
                      width: 100,
                      padding: const EdgeInsets.all(Kingdom.spaceMd),
                      decoration: BoxDecoration(
                        color: Kingdom.gilt.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              badge.imageAsset,
                              width: 44,
                              height: 44,
                              errorBuilder: (_, _, _) => Text(badge.emoji, style: const TextStyle(fontSize: 36)),
                            ),
                          ),
                          const SizedBox(height: Kingdom.spaceSm),
                          Text(
                            badge.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Kingdom.parchment),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Kingdom.spaceXs),
                          Text(
                            badge.description,
                            style: TextStyle(fontSize: 10, color: Kingdom.parchment.withValues(alpha: 0.5)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: Kingdom.spaceXxxl),

            // 実績セクション
            _SectionHeader(title: t.achievements_inProgressHeader),
            const SizedBox(height: Kingdom.spaceMd),
            for (final achievement in achievements)
              Padding(
                padding: const EdgeInsets.only(bottom: Kingdom.spaceLg),
                child: _AchievementCard(achievement: achievement),
              ),
            const SizedBox(height: Kingdom.spaceXxxl),

            // ストリーク情報
            _SectionHeader(title: t.achievements_dailyBonusHeader),
            const SizedBox(height: Kingdom.spaceMd),
            _StreakCard(streak: wallet.winStreak),
          ],
        ),
          ),
        ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementProgress achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final accent = achievement.isUnlocked ? Kingdom.joyGold : Kingdom.bronze;
    return OrnateFrame(
      accent: accent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(achievement.title,
                        style: Kingdom.label(size: 14, color: Kingdom.parchment)),
                    Text(achievement.description,
                        style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              if (achievement.isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Kingdom.joyGold, borderRadius: BorderRadius.circular(20)),
                  child: Text(t.achievements_unlockedLabel,
                      style: TextStyle(color: Kingdom.night, fontSize: Kingdom.textCaption, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: achievement.percent,
              backgroundColor: Kingdom.parchment.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(achievement.isUnlocked ? Kingdom.joyGold : Kingdom.gilt),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${achievement.progress}/${achievement.target}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
              if (achievement.reward != null)
                Text(achievement.reward!, style: const TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.gilt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return OrnateFrame(
      accent: Kingdom.angerCrimson,
      gradient: const LinearGradient(
        colors: [Kingdom.angerCrimsonDeep, Color(0xFF7A3A1A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.achievements_streakBonusTitle, style: Kingdom.label(size: 16, color: Kingdom.parchment)),
          const SizedBox(height: Kingdom.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('$streak',
                      style: TextStyle(
                          fontFamily: Kingdom.displayFont, color: Kingdom.parchment, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text(t.achievements_streakLabel, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  Text('×${(1.0 + (streak * 0.05)).clamp(1.0, 1.5).toStringAsFixed(2)}',
                      style: TextStyle(
                          fontFamily: Kingdom.displayFont, color: Kingdom.gilt, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text(t.achievements_bonusMultiplierLabel, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Kingdom.spaceMd),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Kingdom.night.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
            child: Text(t.achievements_streakBonusDescription,
                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.85), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Kingdom.title(size: 16));
  }
}
