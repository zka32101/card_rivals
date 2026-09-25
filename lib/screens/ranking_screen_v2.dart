import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/game_state_provider.dart';

final _dummyRankings = [
  {'name': 'KamiCard_99', 'tier': 'diamond', 'rating': 2450, 'wins': 342},
  {'name': 'EmotionMaster', 'tier': 'platinum', 'rating': 1920, 'wins': 211},
  {'name': 'SadnessKing', 'tier': 'gold', 'rating': 1750, 'wins': 168},
  {'name': 'JoyHunter', 'tier': 'gold', 'rating': 1620, 'wins': 134},
  {'name': 'AngerBurst', 'tier': 'silver', 'rating': 1400, 'wins': 89},
  {'name': 'You', 'tier': 'bronze', 'rating': 1000, 'wins': 0},
];

class RankingScreenV2 extends ConsumerWidget {
  const RankingScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(myPlayerRankProvider).valueOrNull ?? const PlayerRank();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 ランキング'),
        elevation: 0,
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 自分のTierカード
            _buildMyRankCard(rank),
            const SizedBox(height: 24),

            // ランキング説明
            _SectionHeader(title: '🏅 ランキング'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                'PvP対戦の勝敗によって ELO レートが変動します。\n上位プレイヤーを目指してバトルに挑戦しましょう！',
                style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            // ランキングリスト
            _SectionHeader(title: '上位プレイヤー'),
            const SizedBox(height: 8),
            ..._buildRankingList(),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMyRankCard(PlayerRank rank) {
    final nextTierThreshold = _getTierThreshold(rank.tier) + 250;
    final progress = (rank.rating - _getTierThreshold(rank.tier)) / 250;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getTierGradient(rank.tier),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getTierColor(rank.tier).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ヘッダー
          Row(
            children: [
              Text(rank.tierEmoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.tierLabel,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${rank.rating}pt',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 勝敗統計
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${rank.wins}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        '勝利',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${rank.losses}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        '敗北',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${(rank.wins / (rank.wins + rank.losses) * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        '勝率',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 次のランクまでの進捗
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '次のランク: ${nextTierThreshold}pt',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRankingList() {
    return _dummyRankings.map((entry) {
      final index = _dummyRankings.indexOf(entry);
      final isMe = entry['name'] == 'You';
      final tier = entry['tier'] as String;
      final tierColor = _getTierColor(tier);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? tierColor.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe ? tierColor : Colors.grey[200]!,
              width: isMe ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ランキング順位
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: index == 0 ? Colors.amber[700] : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: index == 0 ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tier絵文字
              Text(_tierEmoji(tier), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),

              // プレイヤー名・勝数
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '👤 あなた' : entry['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isMe ? tierColor : Colors.black87,
                      ),
                    ),
                    Text(
                      '${entry['wins']}勝',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // レート
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry['rating']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'pt',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _tierEmoji(String tier) {
    switch (tier) {
      case 'diamond':
        return '👑';
      case 'platinum':
        return '💎';
      case 'gold':
        return '🥇';
      case 'silver':
        return '🥈';
      default:
        return '🥉';
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'diamond':
        return const Color(0xFF4DD0E1);
      case 'platinum':
        return const Color(0xFFE1BEE7);
      case 'gold':
        return Colors.amber[600]!;
      case 'silver':
        return Colors.grey[400]!;
      default:
        return Colors.brown[400]!;
    }
  }

  List<Color> _getTierGradient(String tier) {
    switch (tier) {
      case 'diamond':
        return [const Color(0xFF00BCD4), const Color(0xFF00ACC1)];
      case 'platinum':
        return [Colors.purple[300]!, Colors.purple[400]!];
      case 'gold':
        return [Colors.amber[600]!, Colors.amber[500]!];
      case 'silver':
        return [Colors.grey[400]!, Colors.grey[500]!];
      default:
        return [Colors.brown[500]!, Colors.brown[600]!];
    }
  }

  int _getTierThreshold(String tier) {
    switch (tier) {
      case 'diamond':
        return 2000;
      case 'platinum':
        return 1500;
      case 'gold':
        return 1000;
      case 'silver':
        return 500;
      default:
        return 0;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
