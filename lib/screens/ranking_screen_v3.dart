import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/game_state_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../models/leaderboard.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class RankingScreenV3 extends ConsumerStatefulWidget {
  const RankingScreenV3({super.key});

  @override
  ConsumerState<RankingScreenV3> createState() => _RankingScreenV3State();
}

class _RankingScreenV3State extends ConsumerState<RankingScreenV3> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final rank = ref.watch(myPlayerRankProvider).valueOrNull ?? const PlayerRank();

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text('🏆 ${t.ranking_title}', style: Kingdom.title(size: 17)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Kingdom.gilt,
          indicatorWeight: 2.0,
          labelColor: Kingdom.gilt,
          unselectedLabelColor: Kingdom.parchment.withValues(alpha: 0.5),
          tabs: [
            Tab(text: '📊 ${t.rankingV3_tabAllTime}'),
            Tab(text: '📅 ${t.rankingV3_tabWeekly}'),
            Tab(text: '📆 ${t.rankingV3_tabMonthly}'),
            Tab(text: '☀️ ${t.attribute_joy}'),
            Tab(text: '🔥 ${t.attribute_anger}'),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          Column(
            children: [
              // 自分のランクカード
              _buildMyRankCard(context, rank),

              // ランキングタブ
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AllTimeLeaderboard(),
                    _WeeklyLeaderboard(),
                    _MonthlyLeaderboard(),
                    _AttributeLeaderboard(attribute: 'joy'),
                    _AttributeLeaderboard(attribute: 'anger'),
                  ],
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildMyRankCard(BuildContext context, PlayerRank rank) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      child: OrnateFrame(
        accent: Kingdom.gilt,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(rank.tierEmoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: Kingdom.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rank.tierLabel, style: Kingdom.label(size: 16, color: Kingdom.gilt)),
                  Text(
                    t.rankingV3_statsLine(rank.rating, rank.wins, rank.losses),
                    style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: Kingdom.spaceXs),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7C9CDB), width: 1.0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#${rank.rating ~/ 100}',
                style: const TextStyle(fontSize: Kingdom.textBody, fontWeight: FontWeight.bold, color: Color(0xFF7C9CDB)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllTimeLeaderboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(allTimeLeaderboardProvider);
    return _LeaderboardListView(entries: entries);
  }
}

class _WeeklyLeaderboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final leaderboard = ref.watch(weeklyLeaderboardProvider);
    if (leaderboard == null) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          child: Text(t.rankingV3_weekLabel(leaderboard.weekNumber, leaderboard.year),
              style: Kingdom.label(size: Kingdom.textBody, color: const Color(0xFF7C9CDB))),
        ),
        Expanded(child: _LeaderboardListView(entries: leaderboard.entries)),
      ],
    );
  }
}

class _MonthlyLeaderboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final leaderboard = ref.watch(monthlyLeaderboardProvider);
    if (leaderboard == null) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          child: Text(t.rankingV3_monthLabel(leaderboard.year, leaderboard.month),
              style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.angerCrimson)),
        ),
        Expanded(child: _LeaderboardListView(entries: leaderboard.entries)),
      ],
    );
  }
}

class _AttributeLeaderboard extends ConsumerWidget {
  final String attribute;

  const _AttributeLeaderboard({required this.attribute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final leaderboard = switch (attribute) {
      'joy' => ref.watch(joyLeaderboardProvider),
      'anger' => ref.watch(angerLeaderboardProvider),
      'sadness' => ref.watch(sadnessLeaderboardProvider),
      _ => null,
    };

    if (leaderboard == null) return const SizedBox.shrink();

    final attrLabel = switch (attribute) {
      'joy' => t.attribute_joy,
      'anger' => t.attribute_anger,
      'sadness' => t.attribute_sadness,
      _ => attribute,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          child: Text(
            '${leaderboard.attributeEmoji} ${t.rankingV3_attributeLeague(attrLabel)}',
            style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.attributeColor(attribute)),
          ),
        ),
        Expanded(child: _LeaderboardListView(entries: leaderboard.entries)),
      ],
    );
  }
}

class _LeaderboardListView extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const _LeaderboardListView({required this.entries});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (entries.isEmpty) {
      return Center(
        child: Text(t.rankingV3_noData, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceMd),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final entry = entries[index];
        final isTopThree = entry.rank <= 3;
        final borderColor = switch (entry.rank) {
          1 => Kingdom.gilt,
          2 => const Color(0xFFB9C6D6),
          3 => const Color(0xFFB08D57),
          _ => const Color(0xFF7C9CDB),
        };

        return Container(
          margin: const EdgeInsets.only(bottom: Kingdom.spaceSm),
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          decoration: BoxDecoration(
            color: Kingdom.nightDeep,
            border: Border.all(color: borderColor, width: 1.0),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isTopThree
                ? [BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1)]
                : null,
          ),
          child: Row(
            children: [
              // ランク
              SizedBox(
                width: 32,
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(fontFamily: Kingdom.displayFont, fontSize: 14, fontWeight: FontWeight.bold, color: borderColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: Kingdom.spaceMd),

              // プレイヤー情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.userName,
                      style: TextStyle(fontSize: Kingdom.textBody, fontWeight: FontWeight.bold, color: Kingdom.parchment),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      t.rankingV3_statsLine(entry.rating, entry.wins, entry.losses),
                      style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.parchment.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),

              // ティアバッジ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 1.0),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  entry.tier.toUpperCase().substring(0, 1),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
