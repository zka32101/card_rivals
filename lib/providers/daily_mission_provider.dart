import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import '../models/daily_mission.dart';
import 'auth_provider.dart';

// 本日のミッションリスト（ローカル状態）
final dailyMissionsProvider = StateProvider<List<DailyMission>>((ref) {
  return generateDailyMissions('user_placeholder');
});

// Firestore統合版：本日のミッションリスト
final userDailyMissionsProvider = FutureProvider<List<DailyMission>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return [];
  }

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('missions')
        .where('expiresAt', isGreaterThan: DateTime.now())
        .orderBy('expiresAt')
        .get();

    return querySnapshot.docs
        .map((doc) => DailyMission.fromMap(doc.data()))
        .toList();
  } catch (e) {
    debugPrint('Error loading daily missions: $e');
    return [];
  }
});

// 完了ミッション数
final completedMissionsCountProvider = Provider<int>((ref) {
  final missions = ref.watch(dailyMissionsProvider);
  return missions.where((m) => m.completed).length;
});

// 合計ジェム報酬（クレーム可能なもののみ）
final availableGemRewardProvider = Provider<int>((ref) {
  final missions = ref.watch(dailyMissionsProvider);
  return missions
    .where((m) => m.canClaim)
    .fold<int>(0, (sum, m) => sum + m.gemReward);
});

// 合計コイン報酬（クレーム可能なもののみ）
final availableCoinRewardProvider = Provider<int>((ref) {
  final missions = ref.watch(dailyMissionsProvider);
  return missions
    .where((m) => m.canClaim)
    .fold<int>(0, (sum, m) => sum + m.coinReward);
});

// ローカル状態用（既存）
void updateMissionProgress(
  WidgetRef ref, {
  bool isWin = false,
  Set<String>? attributesUsed,
  int damageDealt = 0,
}) {
  final missions = ref.read(dailyMissionsProvider);

  final updated = missions.map((m) {
    if (m.isExpired || m.completed || m.claimed) return m;

    switch (m.type) {
      case MissionType.battle:
        return m.copyWith(
          progress: m.progress + 1,
          completed: m.progress + 1 >= m.target,
        );

      case MissionType.win:
        if (isWin) {
          return m.copyWith(
            progress: m.progress + 1,
            completed: m.progress + 1 >= m.target,
          );
        }
        return m;

      case MissionType.winStreak:
        return m;

      case MissionType.attributeWin:
        if (isWin && m.requiredAttribute != null && (attributesUsed?.contains(m.requiredAttribute) ?? false)) {
          return m.copyWith(
            progress: m.progress + 1,
            completed: m.progress + 1 >= m.target,
          );
        }
        return m;

      case MissionType.damage:
        if (damageDealt > 0) {
          return m.copyWith(
            progress: (m.progress + damageDealt).clamp(0, m.target),
            completed: m.progress + damageDealt >= m.target,
          );
        }
        return m;
    }
  }).toList();

  ref.read(dailyMissionsProvider.notifier).state = updated;
}

// Firestore統合版：ミッション進捗を更新
Future<void> updateMissionProgressFirestore(
  String userId,
  DailyMission mission, {
  bool isWin = false,
  Set<String>? attributesUsed,
  int damageDealt = 0,
}) async {
  if (mission.isExpired || mission.completed || mission.claimed) return;

  late DailyMission updated;

  switch (mission.type) {
    case MissionType.battle:
      updated = mission.copyWith(
        progress: mission.progress + 1,
        completed: mission.progress + 1 >= mission.target,
      );
      break;

    case MissionType.win:
      if (isWin) {
        updated = mission.copyWith(
          progress: mission.progress + 1,
          completed: mission.progress + 1 >= mission.target,
        );
      } else {
        return;
      }
      break;

    case MissionType.attributeWin:
      if (isWin && mission.requiredAttribute != null && (attributesUsed?.contains(mission.requiredAttribute) ?? false)) {
        updated = mission.copyWith(
          progress: mission.progress + 1,
          completed: mission.progress + 1 >= mission.target,
        );
      } else {
        return;
      }
      break;

    case MissionType.damage:
      if (damageDealt > 0) {
        updated = mission.copyWith(
          progress: (mission.progress + damageDealt).clamp(0, mission.target),
          completed: mission.progress + damageDealt >= mission.target,
        );
      } else {
        return;
      }
      break;

    default:
      return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('missions')
        .doc(mission.id)
        .update(updated.toMap());
  } catch (e) {
    debugPrint('Error updating mission progress: $e');
  }
}
