import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/season.dart';
import '../providers/season_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class SeasonScreen extends ConsumerWidget {
  const SeasonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final currentSeasonAsync = ref.watch(currentSeasonProvider);
    final userProgressAsync = ref.watch(userCurrentSeasonProgressProvider);
    // Season screen - displays current season info, leaderboard, and rewards

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text('⚔️ ${t.season_title}', style: Kingdom.title(size: 17)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: SafeArea(
        child: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          currentSeasonAsync.when(
            data: (season) {
              if (season == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        t.season_noActiveSeason,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.season_checkBackSoon,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return userProgressAsync.when(
                data: (progress) {
                  if (progress == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            t.season_noActiveSeason,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(Kingdom.spaceMd),
                    child: Column(
                      children: [
                        _buildSeasonHeader(context, season, t),
                        const SizedBox(height: Kingdom.spaceLg),
                        _buildUserProgressCard(context, progress, season, t),
                        const SizedBox(height: Kingdom.spaceLg),
                        _buildSeasonBonusCard(context, season, t),
                        const SizedBox(height: Kingdom.spaceLg),
                        _buildRankProgressCard(context, progress, season, t),
                        const SizedBox(height: Kingdom.spaceLg),
                        _buildBattleStatsCard(context, progress, t),
                        const SizedBox(height: Kingdom.spaceLg),
                        _buildActionButtons(context, t),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSeasonHeader(BuildContext context, Season season, AppLocalizations t) {
    final seasonTypeEmoji = _getSeasonTypeEmoji(season.type);
    final daysRemaining = season.daysRemaining;

    return OrnateFrame(
      accent: Kingdom.gilt,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(seasonTypeEmoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: Kingdom.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.season_label} ${season.number}',
                      style: Kingdom.label(size: 16, color: Kingdom.gilt),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      season.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Kingdom.spaceMd),
          if (season.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Kingdom.joyGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.season_daysRemaining(daysRemaining),
                style: TextStyle(fontSize: 12, color: Kingdom.joyGold),
              ),
            )
          else if (season.isUpcoming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Kingdom.parchment.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.season_upcoming,
                style: TextStyle(fontSize: 12, color: Kingdom.parchment),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Kingdom.angerCrimson.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.season_ended,
                style: TextStyle(fontSize: 12, color: Kingdom.angerCrimson),
              ),
            ),
          const SizedBox(height: Kingdom.spaceSm),
          Text(
            season.description,
            style: TextStyle(fontSize: 13, color: Kingdom.parchment.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProgressCard(
    BuildContext context,
    UserSeasonProgress progress,
    Season season,
    AppLocalizations t,
  ) {
    final progressPercent = (progress.currentRankPoints / 100) * 100;

    return OrnateFrame(
      accent: Kingdom.joyGold,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.season_yourProgress,
            style: Kingdom.label(size: 14, color: Kingdom.joyGold),
          ),
          const SizedBox(height: Kingdom.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                context,
                '${progress.currentRank}',
                t.season_currentRank,
                Kingdom.joyGold,
              ),
              _buildStatColumn(
                context,
                '${progress.highestRank}',
                t.season_highestRank,
                Kingdom.gilt,
              ),
              _buildStatColumn(
                context,
                '${progress.totalSeasonPoints}',
                t.season_totalPoints,
                Kingdom.lightSkyBlue,
              ),
            ],
          ),
          const SizedBox(height: Kingdom.spaceMd),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 20,
                  backgroundColor: Kingdom.parchment.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Kingdom.joyGold),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${progress.currentRankPoints}/100',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Kingdom.spaceSm),
          Text(
            t.season_rankPointsToNextRank(100 - progress.currentRankPoints),
            style: TextStyle(fontSize: 11, color: Kingdom.parchment.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonBonusCard(BuildContext context, Season season, AppLocalizations t) {
    final bonus = season.seasonBonus;

    return OrnateFrame(
      accent: Kingdom.lightSkyBlue,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.season_bonusTitle,
            style: Kingdom.label(size: 14, color: Kingdom.lightSkyBlue),
          ),
          const SizedBox(height: Kingdom.spaceMd),
          _buildBonusRow(
            context,
            t.season_damageBonusLabel,
            '${(bonus.damageMultiplier * 100).toStringAsFixed(0)}%',
            Kingdom.angerCrimson,
          ),
          const SizedBox(height: Kingdom.spaceSm),
          _buildBonusRow(
            context,
            t.season_coinBonusLabel,
            '${(bonus.coinBonusMultiplier * 100).toStringAsFixed(0)}%',
            Kingdom.joyGold,
          ),
          const SizedBox(height: Kingdom.spaceSm),
          _buildBonusRow(
            context,
            t.season_expBonusLabel,
            '${(bonus.expBonusMultiplier * 100).toStringAsFixed(0)}%',
            Kingdom.lightSkyBlue,
          ),
          const SizedBox(height: Kingdom.spaceMd),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Kingdom.lightSkyBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${t.season_bonusAttribute}: ${bonus.attribute}',
              style: TextStyle(fontSize: 11, color: Kingdom.lightSkyBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankProgressCard(
    BuildContext context,
    UserSeasonProgress progress,
    Season season,
    AppLocalizations t,
  ) {
    return OrnateFrame(
      accent: Kingdom.angerCrimson,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.season_rankProgressTitle,
            style: Kingdom.label(size: 14, color: Kingdom.angerCrimson),
          ),
          const SizedBox(height: Kingdom.spaceMd),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: season.maxRankTier,
            itemBuilder: (context, index) {
              final rank = index + 1;
              final isReached = rank <= progress.highestRank;
              return Container(
                decoration: BoxDecoration(
                  color: isReached
                      ? Kingdom.angerCrimson.withValues(alpha: 0.3)
                      : Kingdom.parchment.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isReached ? Kingdom.angerCrimson : Kingdom.parchment.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isReached ? Kingdom.angerCrimson : Kingdom.parchment.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBattleStatsCard(BuildContext context, UserSeasonProgress progress, AppLocalizations t) {
    return OrnateFrame(
      accent: Kingdom.lightSkyBlue,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.season_battleStats,
            style: Kingdom.label(size: 14, color: Kingdom.lightSkyBlue),
          ),
          const SizedBox(height: Kingdom.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                context,
                '${progress.battlesPlayed}',
                t.season_battlesPlayed,
                Kingdom.parchment,
              ),
              _buildStatColumn(
                context,
                '${progress.battlesWon}',
                t.season_battlesWon,
                Kingdom.joyGold,
              ),
              _buildStatColumn(
                context,
                '${(progress.winRate * 100).toStringAsFixed(1)}%',
                t.season_winRate,
                Kingdom.lightSkyBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations t) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.leaderboard),
            label: Text(t.season_viewLeaderboard),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SeasonLeaderboardScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Kingdom.joyGold,
              foregroundColor: Kingdom.night,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: Kingdom.spaceMd),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.card_giftcard),
            label: Text(t.season_viewRewards),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SeasonRewardsScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Kingdom.lightSkyBlue,
              foregroundColor: Kingdom.night,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Kingdom.parchment.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBonusRow(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getSeasonTypeEmoji(SeasonType type) {
    switch (type) {
      case SeasonType.spring:
        return '🌸';
      case SeasonType.summer:
        return '☀️';
      case SeasonType.autumn:
        return '🍂';
      case SeasonType.winter:
        return '❄️';
    }
  }
}

// Import the leaderboard screen
class SeasonLeaderboardScreen extends ConsumerWidget {
  const SeasonLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final currentSeasonAsync = ref.watch(currentSeasonProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text('🏆 ${t.season_leaderboard}', style: Kingdom.title(size: 17)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: SafeArea(
        child: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          currentSeasonAsync.when(
            data: (season) {
              if (season == null) {
                return Center(child: Text(t.season_noActiveSeason));
              }

              final leaderboardAsync = ref.watch(seasonLeaderboardProvider(season.id));

              return leaderboardAsync.when(
                data: (leaderboard) {
                  if (leaderboard.isEmpty) {
                    return Center(child: Text(t.season_noLeaderboardData));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(Kingdom.spaceMd),
                    itemCount: leaderboard.length,
                    itemBuilder: (context, index) {
                      final progress = leaderboard[index];
                      return _buildLeaderboardTile(context, progress, index + 1, t);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(
    BuildContext context,
    UserSeasonProgress progress,
    int position,
    AppLocalizations t,
  ) {
    final positionMedal = _getMedalEmoji(position);

    return Card(
      color: Kingdom.nightDeep,
      margin: const EdgeInsets.only(bottom: Kingdom.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(Kingdom.spaceMd),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Kingdom.joyGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(positionMedal, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: Kingdom.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$position',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        t.season_rank(progress.currentRank),
                        style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(width: Kingdom.spaceSm),
                      Text(
                        t.season_points(progress.totalSeasonPoints),
                        style: TextStyle(fontSize: 12, color: Kingdom.joyGold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${progress.battlesWon}W',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Kingdom.joyGold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress.winRate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: Kingdom.parchment.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMedalEmoji(int position) {
    switch (position) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '⭐';
    }
  }
}

// Import the rewards screen
class SeasonRewardsScreen extends ConsumerWidget {
  const SeasonRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final currentSeasonAsync = ref.watch(currentSeasonProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text('🎁 ${t.season_rewards}', style: Kingdom.title(size: 17)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: SafeArea(
        child: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          currentSeasonAsync.when(
            data: (season) {
              if (season == null) {
                return Center(child: Text(t.season_noActiveSeason));
              }

              final rewardsAsync = ref.watch(seasonRewardsProvider(season.id));
              final userProgressAsync = ref.watch(userCurrentSeasonProgressProvider);

              return rewardsAsync.when(
                data: (rewards) {
                  return userProgressAsync.when(
                    data: (userProgress) {
                      if (rewards.isEmpty) {
                        return Center(child: Text(t.season_noRewards));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(Kingdom.spaceMd),
                        itemCount: rewards.length,
                        itemBuilder: (context, index) {
                          final reward = rewards[index];
                          final isUnlocked = (userProgress?.currentRank ?? 1) >= reward.rankTier;
                          final isClaimed = userProgress?.unlockedRewards.contains(reward.id) ?? false;

                          return _buildRewardTile(
                            context,
                            season.id,
                            reward,
                            isUnlocked,
                            isClaimed,
                            t,
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildRewardTile(
    BuildContext context,
    String seasonId,
    SeasonRankReward reward,
    bool isUnlocked,
    bool isClaimed,
    AppLocalizations t,
  ) {
    final rewardEmoji = reward.gemsReward > 0 ? '💎' : '🪙';

    return Card(
      color: Kingdom.nightDeep,
      margin: const EdgeInsets.only(bottom: Kingdom.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(Kingdom.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? Kingdom.joyGold.withValues(alpha: 0.2)
                                  : Kingdom.parchment.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                isUnlocked ? rewardEmoji : '🔒',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: Kingdom.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reward.title,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.season_reachRank(reward.rankTier),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Kingdom.parchment.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Kingdom.spaceMd),
                      Text(
                        reward.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Kingdom.parchment.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Kingdom.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (reward.gemsReward > 0) ...[
                      Text(
                        '💎 ${reward.gemsReward}',
                        style: TextStyle(fontSize: 12, color: Kingdom.lightSkyBlue),
                      ),
                      const SizedBox(width: Kingdom.spaceMd),
                    ],
                    if (reward.coinsReward > 0)
                      Text(
                        '🪙 ${reward.coinsReward}',
                        style: TextStyle(fontSize: 12, color: Kingdom.joyGold),
                      ),
                  ],
                ),
                if (isUnlocked && !isClaimed)
                  _ClaimRewardButton(seasonId: seasonId, reward: reward)
                else if (isClaimed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Kingdom.parchment.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t.season_claimed,
                      style: TextStyle(fontSize: 11, color: Kingdom.parchment.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// リワード請求ボタン — claimSeasonReward Cloud Function経由でサーバー側の
// ランク到達判定・請求済みチェック・ジェム/コイン付与をアトミックに行う。
// タイル単体で読込中状態を持つため、リスト全体を巻き込まないConsumerStatefulWidgetにしている。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ClaimRewardButton extends ConsumerStatefulWidget {
  final String seasonId;
  final SeasonRankReward reward;

  const _ClaimRewardButton({required this.seasonId, required this.reward});

  @override
  ConsumerState<_ClaimRewardButton> createState() => _ClaimRewardButtonState();
}

class _ClaimRewardButtonState extends ConsumerState<_ClaimRewardButton> {
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    final error = await claimSeasonReward(
      ref,
      seasonId: widget.seasonId,
      rewardId: widget.reward.id,
    );
    if (!mounted) return;
    setState(() => _claiming = false);
    final t = AppLocalizations.of(context)!;
    if (error == null) {
      // 請求済みリワード一覧が変わったので再取得する
      ref.invalidate(userCurrentSeasonProgressProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.season_rewardClaimed)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.season_claimFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ElevatedButton(
      onPressed: _claiming ? null : _claim,
      style: ElevatedButton.styleFrom(
        backgroundColor: Kingdom.joyGold,
        foregroundColor: Kingdom.night,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: _claiming
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Kingdom.night),
            )
          : Text(t.season_claim, style: const TextStyle(fontSize: 11)),
    );
  }
}
