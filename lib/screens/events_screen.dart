import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/event_challenge.dart';
import '../providers/events_challenges_provider.dart';
import '../theme/kingdom_theme.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(activeEventsProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: const Text('イベント'),
        backgroundColor: Kingdom.nightDeep,
        elevation: 0,
      ),
      body: SafeArea(child: eventsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Kingdom.gilt),
        ),
        error: (error, stack) => Center(
          child: Text(
            'エラーが発生しました: $error',
            style: const TextStyle(color: Kingdom.parchment),
          ),
        ),
        data: (events) => events.isEmpty
            ? Center(
                child: Text(
                  '現在のイベントはありません',
                  style: TextStyle(
                    color: Kingdom.parchment.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _EventCard(event: event);
                },
              ),
      )),
    );
  }
}

/// イベントカード
class _EventCard extends ConsumerWidget {
  final GameEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = event.secondsRemaining / event.endDate.difference(event.startDate).inSeconds;

    return Card(
      color: Kingdom.nightDeep,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/event/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル
              Text(
                event.title,
                style: Kingdom.title(size: 16, color: Kingdom.gilt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 説明
              Text(
                event.description,
                style: TextStyle(
                  color: Kingdom.parchment.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 時間情報
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimeRemaining(event.secondsRemaining),
                    style: TextStyle(
                      color: Kingdom.gilt,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getEventStatus(event),
                    style: TextStyle(
                      color: _getStatusColor(event),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // プログレスバー
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Kingdom.parchment.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Kingdom.gilt),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeRemaining(int seconds) {
    if (seconds <= 0) return '終了';

    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;

    if (days > 0) {
      return '残り $days日 $hours時間';
    } else {
      return '残り $hours時間';
    }
  }

  String _getEventStatus(GameEvent event) {
    if (event.isExpired) return '終了';
    if (event.isUpcoming) return '予定';
    return '進行中';
  }

  Color _getStatusColor(GameEvent event) {
    if (event.isExpired) return Kingdom.parchment.withValues(alpha: 0.5);
    if (event.isUpcoming) return Kingdom.bronze;
    return Kingdom.joyGold;
  }
}
