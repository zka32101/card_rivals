import 'package:flutter/material.dart';
import '../models/battle_special_effects.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_icon.dart';

// サンプルイベントチャレンジ（多言語対応）。実データ連携までの仮チャレンジ一覧。
List<EventChallenge> buildSampleEventChallenges(AppLocalizations t) => [
      EventChallenge(
        id: 'challenge_1',
        title: t.eventChallenges_streakTitle,
        description: t.eventChallenges_streakDesc,
        reward: t.eventChallenges_streakReward,
        goalValue: 5,
        goalType: 'consecutive_wins',
        deadline: DateTime.now().add(const Duration(days: 7)),
      ),
      EventChallenge(
        id: 'challenge_2',
        title: t.eventChallenges_attributeMasterTitle,
        description: t.eventChallenges_attributeMasterDesc,
        reward: t.eventChallenges_attributeMasterReward,
        goalValue: 9,
        goalType: 'attribute_wins',
        deadline: DateTime.now().add(const Duration(days: 14)),
      ),
      EventChallenge(
        id: 'challenge_3',
        title: t.eventChallenges_damageTitle,
        description: t.eventChallenges_damageDesc,
        reward: t.eventChallenges_damageReward,
        goalValue: 300,
        goalType: 'damage_dealt',
        deadline: DateTime.now().add(const Duration(days: 30)),
      ),
    ];

class EventChallengesWidget extends StatelessWidget {
  const EventChallengesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final challenges = buildSampleEventChallenges(t);
    final activeChallenges = challenges.where((c) => c.isActive).toList();

    if (activeChallenges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IconText(
            '⚡ ${t.eventChallenges_activeChallenges}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: activeChallenges.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ChallengeCard(challenge: activeChallenges[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final EventChallenge challenge;

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final daysRemaining = challenge.deadline.difference(DateTime.now()).inDays;
    const currentProgress = 0; // Mock データ

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[600]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconText(
            challenge.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          IconText(
            t.eventChallenges_goalTarget(challenge.goalValue),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentProgress / challenge.goalValue).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currentProgress/${challenge.goalValue}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconText(
                t.eventChallenges_daysRemaining(daysRemaining),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
