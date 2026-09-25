import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/event_challenge.dart';
import '../providers/events_challenges_provider.dart';
import '../theme/kingdom_theme.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final challengesAsync = ref.watch(eventChallengesProvider(eventId));
    final progressAsync = ref.watch(userEventProgressProvider(eventId));

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: const Text('イベント詳細'),
        backgroundColor: Kingdom.nightDeep,
        elevation: 0,
      ),
      body: SafeArea(child: eventAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Kingdom.gilt),
        ),
        error: (error, _) => Center(
          child: Text(
            'エラーが発生しました: $error',
            style: const TextStyle(color: Kingdom.parchment),
          ),
        ),
        data: (event) {
          if (event == null) {
            return const Center(
              child: Text('イベントが見つかりません'),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // イベント情報
                _EventHeader(event: event),
                const SizedBox(height: 16),
                // チャレンジリスト
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'チャレンジ',
                    style: Kingdom.title(size: 16, color: Kingdom.gilt),
                  ),
                ),
                const SizedBox(height: 8),
                challengesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Kingdom.gilt),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'チャレンジ読み込みエラー: $error',
                      style: const TextStyle(color: Kingdom.parchment),
                    ),
                  ),
                  data: (challenges) => progressAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) => const SizedBox.shrink(),
                    data: (progresses) {
                      if (challenges.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'チャレンジがありません',
                            style: TextStyle(
                              color: Kingdom.parchment.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: challenges.length,
                        itemBuilder: (context, index) {
                          final challenge = challenges[index];
                          final progress = progresses.firstWhere(
                            (p) => p.challengeId == challenge.id,
                            orElse: () => UserChallengeProgress(
                              eventId: eventId,
                              challengeId: challenge.id,
                              updatedAt: DateTime.now(),
                            ),
                          );

                          return _ChallengeCard(
                            challenge: challenge,
                            progress: progress,
                            ref: ref,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      )),
    );
  }
}

/// イベントヘッダー
class _EventHeader extends StatelessWidget {
  final GameEvent event;

  const _EventHeader({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Kingdom.nightDeep,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Text(
            event.title,
            style: Kingdom.title(size: 18, color: Kingdom.gilt),
          ),
          const SizedBox(height: 8),
          // 説明
          Text(
            event.description,
            style: TextStyle(
              color: Kingdom.parchment.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          // ステータス
          Row(
            children: [
              _StatusBadge(event: event),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getTimeInfo(event),
                  style: TextStyle(
                    color: Kingdom.parchment.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeInfo(GameEvent event) {
    if (event.isExpired) {
      return '終了';
    } else if (event.isUpcoming) {
      return '開始予定: ${_formatDate(event.startDate)}';
    } else {
      return '終了: ${_formatDate(event.endDate)}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// ステータスバッジ
class _StatusBadge extends StatelessWidget {
  final GameEvent event;

  const _StatusBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    final status = event.isExpired
        ? '終了'
        : event.isUpcoming
            ? '予定'
            : '進行中';
    final color = event.isExpired
        ? Kingdom.parchment.withValues(alpha: 0.5)
        : event.isUpcoming
            ? Kingdom.bronze
            : Kingdom.joyGold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// チャレンジカード
class _ChallengeCard extends ConsumerWidget {
  final Challenge challenge;
  final UserChallengeProgress progress;
  final WidgetRef ref;

  const _ChallengeCard({
    required this.challenge,
    required this.progress,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressPercent = progress.progressPercent(challenge.target);
    final isCompleted = progress.completed;
    final isRewardClaimed = progress.rewardClaimed;

    return Card(
      color: Kingdom.nightDeep,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    challenge.title,
                    style: Kingdom.title(size: 14, color: Kingdom.gilt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Kingdom.joyGold.withValues(alpha: 0.2),
                      border: Border.all(color: Kingdom.joyGold, width: 1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      '完了',
                      style: TextStyle(
                        color: Kingdom.joyGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // 説明
            Text(
              challenge.description,
              style: TextStyle(
                color: Kingdom.parchment.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 進捗
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.progress}/${challenge.target}',
                  style: TextStyle(
                    color: Kingdom.parchment.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '難易度: ${challenge.difficulty}/10',
                  style: TextStyle(
                    color: Kingdom.parchment.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // プログレスバー
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressPercent,
                backgroundColor: Kingdom.parchment.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Kingdom.joyGold : Kingdom.gilt,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            // リワード情報
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      '💎 ',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${challenge.gemReward}',
                      style: TextStyle(
                        color: Kingdom.parchment.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '🪙 ',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${challenge.coinReward}',
                      style: TextStyle(
                        color: Kingdom.parchment.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (isCompleted && !isRewardClaimed)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Kingdom.joyGold,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () async {
                      try {
                        await claimChallengeReward(
                          ref,
                          eventId: challenge.eventId,
                          challengeId: challenge.id,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('リワードを受け取りました！')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: $e')),
                          );
                        }
                      }
                    },
                    child: const Text(
                      '受け取る',
                      style: TextStyle(fontSize: 11, color: Kingdom.ink),
                    ),
                  )
                else if (isRewardClaimed)
                  Text(
                    '✓ 受取済',
                    style: TextStyle(
                      color: Kingdom.joyGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
