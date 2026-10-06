import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import '../providers/auth_provider.dart';
import '../providers/game_state_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import 'ui_icon.dart';
import 'ui_icon.dart';

enum QuestType { battle, create, win }

class DailyQuest {
  final QuestType type;
  final String title;
  final String icon;
  final int target;
  final int reward;
  final int progress;
  final bool claimed;

  const DailyQuest({
    required this.type,
    required this.title,
    required this.icon,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  bool get completed => progress >= target;

  DailyQuest copyWith({int? progress, bool? claimed}) => DailyQuest(
        type: type,
        title: title,
        icon: icon,
        target: target,
        reward: reward,
        progress: progress ?? this.progress,
        claimed: claimed ?? this.claimed,
      );
}

final dailyQuestsProvider = StateProvider<List<DailyQuest>>((ref) => [
      const DailyQuest(type: QuestType.battle, title: 'バトルに参加', icon: '⚔️', target: 1, reward: 5),
      const DailyQuest(type: QuestType.create, title: 'カードを作成', icon: '🎴', target: 1, reward: 10),
      const DailyQuest(type: QuestType.win, title: '勝利する', icon: '🏆', target: 1, reward: 15),
    ]);

class DailyQuestsWidget extends ConsumerWidget {
  const DailyQuestsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final quests = ref.watch(dailyQuestsProvider);
    final allDone = quests.every((q) => q.claimed);

    return OrnateFrame(
      accent: Kingdom.sadnessIndigo,
      gradient: const LinearGradient(
        colors: [Kingdom.sadnessIndigoDeep, Kingdom.nightDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconText(t.dailyQuests_title, style: Kingdom.label(size: 14, color: const Color(0xFF7C9CDB))),
              const Spacer(),
              if (allDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Kingdom.joyGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Kingdom.joyGold)),
                  child: IconText(t.dailyQuests_allDone, style: const TextStyle(color: Kingdom.joyGold, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Text(t.dailyQuests_progressCount(quests.where((q) => q.completed).length, quests.length),
                    style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: Kingdom.spaceMd),
          ...quests.asMap().entries.map((e) => _QuestRow(
                quest: e.value,
                index: e.key,
              )),
        ],
      ),
    );
  }
}

class _QuestRow extends ConsumerWidget {
  final DailyQuest quest;
  final int index;
  const _QuestRow({required this.quest, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final isDone = quest.completed;
    final isClaimed = quest.claimed;
    final questTitle = switch (quest.type) {
      QuestType.battle => t.dailyQuests_battleTitle,
      QuestType.create => t.dailyQuests_createTitle,
      QuestType.win => t.dailyQuests_winTitle,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Kingdom.spaceSm),
      child: Row(
        children: [
          // アイコン
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isClaimed
                  ? Kingdom.joyGold.withValues(alpha: 0.2)
                  : isDone
                      ? Kingdom.gilt.withValues(alpha: 0.2)
                      : Kingdom.parchment.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isClaimed ? Kingdom.joyGold : isDone ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.2)),
            ),
            child: Center(child: Text(isClaimed ? '✅' : quest.icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          // タイトル + プログレス
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconText(questTitle,
                    style: TextStyle(
                        color: isClaimed ? Kingdom.parchment.withValues(alpha: 0.35) : Kingdom.parchment,
                        fontSize: Kingdom.textBody,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (quest.progress / quest.target).clamp(0.0, 1.0),
                    backgroundColor: Kingdom.parchment.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isClaimed ? Kingdom.joyGold : isDone ? Kingdom.gilt : const Color(0xFF7C9CDB)),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 報酬 / クレームボタン
          if (isClaimed)
            IconText(t.dailyQuests_claimed, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.25), fontSize: 10))
          else if (isDone)
            GestureDetector(
              onTap: () {
                final quests = ref.read(dailyQuestsProvider);
                final updated = List<DailyQuest>.from(quests);
                updated[index] = quest.copyWith(claimed: true);
                ref.read(dailyQuestsProvider.notifier).state = updated;
                // コイン付与
                final w = ref.read(walletProvider);
                final updatedWallet = w.copyWith(coinBalance: w.coinBalance + quest.reward);
                ref.read(walletProvider.notifier).state = updatedWallet;
                final userId = ref.read(currentUserIdProvider);
                if (userId != null) updateWallet(userId, updatedWallet);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: IconText(t.dailyQuests_rewardEarned(quest.reward)), duration: const Duration(seconds: 2)),
                );
              },
              child: SizedBox(
                height: Kingdom.minTapTarget,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Kingdom.gilt, Kingdom.joyGold]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Kingdom.gilt.withValues(alpha: 0.4), blurRadius: 8)],
                    ),
                    child: IconText('🪙${quest.reward}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Kingdom.night)),
                  ),
                ),
              ),
            )
          else
            Text('${quest.progress}/${quest.target}', style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.35), fontSize: 11)),
        ],
      ),
    );
  }
}
