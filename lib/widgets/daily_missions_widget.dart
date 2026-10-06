import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/daily_mission.dart';
import '../providers/auth_provider.dart';
import '../providers/daily_mission_provider.dart';
import '../providers/game_state_provider.dart';
import '../l10n/app_localizations.dart';
import 'ui_icon.dart';
import 'ui_icon.dart';

// ミッションの説明文は生成時(Providerの初期化時など、BuildContextを持たない場面)
// ではなく表示時に組み立てる。type/target/requiredAttributeから毎回導出することで、
// 保存済みのdescription文字列（日本語固定）に依存せず現在のロケールで表示できる。
String _missionDescription(AppLocalizations t, DailyMission m) {
  switch (m.type) {
    case MissionType.battle:
      return t.dailyMissions_descBattle(m.target);
    case MissionType.win:
      return t.dailyMissions_descWin(m.target);
    case MissionType.attributeWin:
      final attrLabel = switch (m.requiredAttribute) {
        'joy' => t.attribute_joy,
        'anger' => t.attribute_anger,
        'sadness' => t.attribute_sadness,
        _ => m.requiredAttribute ?? '',
      };
      return t.dailyMissions_descAttributeWin(attrLabel, m.target);
    case MissionType.winStreak:
    case MissionType.damage:
      return m.description;
  }
}

class DailyMissionsWidget extends ConsumerWidget {
  const DailyMissionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final missions = ref.watch(dailyMissionsProvider);
    final availableGems = ref.watch(availableGemRewardProvider);
    final availableCoins = ref.watch(availableCoinRewardProvider);

    final activeMissions = missions.where((m) => !m.isExpired).toList();
    final completedCount = activeMissions.where((m) => m.completed).length;
    final canReroll = activeMissions.isNotEmpty && !activeMissions.any((m) => m.claimed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconText(
                t.dailyMissions_title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD700),
                ),
              ),
              Row(
                children: [
                  if (canReroll)
                    TextButton.icon(
                      onPressed: () => _reroll(context, ref),
                      icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF44AAFF)),
                      label: IconText(
                        t.dailyMissions_rerollButton(kMissionRerollGemCost),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF44AAFF)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFFD700), width: 1.0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$completedCount / ${activeMissions.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // リワード表示
        if (availableGems > 0 || availableCoins > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0a0a),
                border: Border.all(
                  color: const Color(0xFF44AAFF),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF44AAFF).withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (availableGems > 0)
                    Column(
                      children: [
                        const IconText(
                          '💎',
                          style: TextStyle(fontSize: 20),
                        ),
                        Text(
                          '+$availableGems',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        IconText(
                          t.dailyMissions_gemsLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF44AAFF),
                          ),
                        ),
                      ],
                    ),
                  if (availableCoins > 0)
                    Column(
                      children: [
                        const Text(
                          '💰',
                          style: TextStyle(fontSize: 20),
                        ),
                        Text(
                          '+$availableCoins',
                          style: const TextStyle(
                            color: Color(0xFFFF3300),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        IconText(
                          t.dailyMissions_coinsLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFF3300),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: availableGems > 0 || availableCoins > 0
                          ? () => _claimRewards(ref)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF44AAFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      child: IconText(
                        t.dailyMissions_claimButton,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0a0a0a),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ミッションリスト
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: activeMissions.map((mission) {
              return _MissionCard(mission: mission);
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _reroll(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final wallet = ref.read(walletProvider);
    if (wallet.gemBalance < kMissionRerollGemCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: IconText(t.shop_insufficientGems), backgroundColor: const Color(0xFFFF3300)),
      );
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    ref.read(dailyMissionsProvider.notifier).state = generateDailyMissions(userId ?? 'user_placeholder');
    final updated = wallet.copyWith(gemBalance: wallet.gemBalance - kMissionRerollGemCost);
    ref.read(walletProvider.notifier).state = updated;
    if (userId != null) updateWallet(userId, updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: IconText(t.dailyMissions_rerollDone)),
    );
  }

  void _claimRewards(WidgetRef ref) {
    final missions = ref.read(dailyMissionsProvider);
    final wallet = ref.read(walletProvider);

    int totalGems = 0;
    int totalCoins = 0;

    for (final m in missions) {
      if (m.canClaim) {
        totalGems += m.gemReward;
        totalCoins += m.coinReward;
      }
    }

    // ウォレット更新（コイン・ジェム両方を反映）
    final updatedWallet = wallet.copyWith(
      coinBalance: wallet.coinBalance + totalCoins,
      gemBalance: wallet.gemBalance + totalGems,
    );
    ref.read(walletProvider.notifier).state = updatedWallet;
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) updateWallet(userId, updatedWallet);

    // クレーム済みとして確定（進捗・完了状態は据え置き、再クレーム・再進行を防止）
    final claimedMissions = missions.map((m) {
      if (m.canClaim) {
        return m.copyWith(claimed: true);
      }
      return m;
    }).toList();
    ref.read(dailyMissionsProvider.notifier).state = claimedMissions;
  }
}

class _MissionCard extends StatelessWidget {
  final DailyMission mission;

  const _MissionCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final progress = mission.progressPercent;
    final bgColor = mission.completed
        ? const Color(0xFF1a3a1a)
        : mission.isExpired
            ? const Color(0xFF3a1a1a)
            : const Color(0xFF0a1a2a);
    final borderColor = mission.completed
        ? const Color(0xFF44FF44)
        : mission.isExpired
            ? const Color(0xFFFF6666)
            : const Color(0xFF44AAFF);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconText(mission.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconText(
                      _missionDescription(t, mission),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${mission.progress} / ${mission.target}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // リワード表示
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (mission.gemReward > 0)
                    IconText(
                      '💎 +${mission.gemReward}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (mission.coinReward > 0)
                    Text(
                      '💰 +${mission.coinReward}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF3300),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // プログレスバー
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(borderColor),
            ),
          ),

          if (mission.isExpired) ...[
            const SizedBox(height: 6),
            IconText(
              t.dailyMissions_expiredLabel,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFFF6666),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
