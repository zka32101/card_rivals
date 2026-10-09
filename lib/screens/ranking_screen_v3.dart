import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/game_state_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../models/leaderboard.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_icon.dart';

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
    final rank = ref.watch(myPlayerRankProvider).value ?? const PlayerRank();

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text('🏆 ${t.ranking_title}', style: Kingdom.title(size: 17)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Kingdom.gilt,
          indicatorWeight: 2.0,
          labelColor: Kingdom.gilt,
          unselectedLabelColor: Kingdom.parchment.withValues(alpha: 0.5),
          tabs: [
            Tab(text: '📊 ${t.rankingV3_tabAllTime}'),
            Tab(text: '🗓️ ${t.rankingV3_tabDaily}'),
            Tab(text: '📅 ${t.rankingV3_tabWeekly}'),
            Tab(text: '📆 ${t.rankingV3_tabMonthly}'),
            Tab(text: '🎭 ${t.rankingV3_tabAttribute}'),
          ],
        ),
      ),
      body: Stack(
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
                  children: const [
                    _AllTimeLeaderboard(),
                    _DailyLeaderboard(),
                    _WeeklyLeaderboard(),
                    _MonthlyLeaderboard(),
                    _AttributeLeaderboard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankCard(BuildContext context, PlayerRank rank) {
    final t = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);
    // 全期間ランキング(上位100件)の中に自分がいれば実際の順位を表示する。
    // 圏外の場合は「-」（以前は rating ~/ 100 という意味のない式で常に何らかの
    // 数字を表示していたが、実際の順位ではなかった）。
    final myRank = ref.watch(allTimeLeaderboardProvider).maybeWhen(
          data: (entries) {
            for (final e in entries) {
              if (e.userId == userId) return e.rank;
            }
            return null;
          },
          orElse: () => null,
        );

    return Padding(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      child: OrnateFrame(
        accent: Kingdom.gilt,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconText(rank.tierEmoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: Kingdom.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconText(rank.tierLabelOf(AppLocalizations.of(context)!), style: Kingdom.label(size: 16, color: Kingdom.gilt)),
                  IconText(
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
                myRank != null ? '#$myRank' : '-',
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
  const _AllTimeLeaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allTimeLeaderboardProvider);
    return _AsyncLeaderboardListView(async: async);
  }
}

class _AttributeLeaderboard extends ConsumerStatefulWidget {
  const _AttributeLeaderboard();

  @override
  ConsumerState<_AttributeLeaderboard> createState() => _AttributeLeaderboardState();
}

class _AttributeLeaderboardState extends ConsumerState<_AttributeLeaderboard> {
  String _attribute = 'joy';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(attributeLeaderboardProvider(_attribute));
    final options = [
      ('joy', '☀️ ${t.attribute_joy}', Kingdom.joyGold),
      ('anger', '🔥 ${t.attribute_anger}', Kingdom.angerCrimson),
      ('sadness', '🌙 ${t.attribute_sadness}', Kingdom.sadnessIndigo),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Kingdom.spaceMd, Kingdom.spaceMd, Kingdom.spaceMd, 0),
          child: Row(
            children: [
              for (final o in options) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _attribute = o.$1),
                    child: Container(
                      height: Kingdom.minTapTarget,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _attribute == o.$1 ? o.$3 : Kingdom.nightDeep,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: o.$3.withValues(alpha: 0.6)),
                      ),
                      child: Text(o.$2,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _attribute == o.$1 ? Kingdom.night : Kingdom.parchment,
                          )),
                    ),
                  ),
                ),
                if (o != options.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          child: IconText(t.rankingV3_attributeNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.6))),
        ),
        Expanded(child: _AsyncLeaderboardListView(async: async)),
      ],
    );
  }
}

class _DailyLeaderboard extends ConsumerWidget {
  const _DailyLeaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(dailyLeaderboardProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(),
      data: (leaderboard) {
        if (leaderboard == null) return const SizedBox.shrink();
        final day = leaderboard.day;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Kingdom.spaceMd),
              child: IconText(t.rankingV3_dayLabel(day.year, day.month, day.day),
                  style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.joyGold)),
            ),
            Expanded(child: _LeaderboardListView(entries: leaderboard.entries)),
          ],
        );
      },
    );
  }
}

class _WeeklyLeaderboard extends ConsumerWidget {
  const _WeeklyLeaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(weeklyLeaderboardProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(),
      data: (leaderboard) {
        if (leaderboard == null) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Kingdom.spaceMd),
              child: IconText(t.rankingV3_weekLabel(leaderboard.weekNumber, leaderboard.year),
                  style: Kingdom.label(size: Kingdom.textBody, color: const Color(0xFF7C9CDB))),
            ),
            Expanded(child: _LeaderboardListView(entries: leaderboard.entries)),
          ],
        );
      },
    );
  }
}

class _MonthlyLeaderboard extends ConsumerWidget {
  const _MonthlyLeaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(monthlyLeaderboardProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(),
      data: (leaderboard) {
        if (leaderboard == null) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Kingdom.spaceMd),
              child: IconText(t.rankingV3_monthLabel(leaderboard.year, leaderboard.month),
                  style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.angerCrimson)),
            ),
            Expanded(child: _LeaderboardListView(entries: leaderboard.entries)),
          ],
        );
      },
    );
  }
}

class _AsyncLeaderboardListView extends StatelessWidget {
  final AsyncValue<List<LeaderboardEntry>> async;

  const _AsyncLeaderboardListView({required this.async});

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(),
      data: (entries) => _LeaderboardListView(entries: entries),
    );
  }
}

class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: IconText(t.rankingV3_noData, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
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
        child: IconText(t.rankingV3_noData, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
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
                    IconText(
                      entry.userName,
                      style: TextStyle(fontSize: Kingdom.textBody, fontWeight: FontWeight.bold, color: Kingdom.parchment),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    IconText(
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
