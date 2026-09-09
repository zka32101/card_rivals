import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'auth_provider.dart';
import 'game_state_provider.dart';

// 移住コスト（コイン）
const int kMigrationCost = 50;
// 移住ボーナス倍率の上乗せ（属性有利/不利倍率に加算）
const double kMigrationBonusMultiplier = 0.10;

int _isoWeekNumber(DateTime date) {
  final dayOfYear = int.parse(
      (date.difference(DateTime(date.year, 1, 1)).inDays + 1).toString());
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}

// 今週、優勢な属性（喜/怒/哀を週替わりでローテーション）
final weeklyFavoredAttributeProvider = Provider<String>((ref) {
  const attrs = ['joy', 'anger', 'sadness'];
  final week = _isoWeekNumber(DateTime.now());
  return attrs[week % 3];
});

class MigrationState {
  final String? attribute; // 現在移住済みの属性（null = 未移住）
  final int forWeek; // 何週目の移住か（週が変わったら無効）

  const MigrationState({this.attribute, this.forWeek = -1});

  Map<String, dynamic> toMap() => {
        'attribute': attribute,
        'forWeek': forWeek,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory MigrationState.fromMap(Map<String, dynamic> map) => MigrationState(
        attribute: map['attribute'] as String?,
        forWeek: (map['forWeek'] as int?) ?? -1,
      );
}

final migrationStateProvider = StateProvider<MigrationState>((ref) => const MigrationState());

// walletHydratedForUidProviderと同様、Firestoreからの読み込みで
// ローカルの移住状態を上書きするのを「ユーザーごとに1回だけ」に制限するガード。
final migrationHydratedForUidProvider = StateProvider<String?>((ref) => null);

// Firestore統合版：ユーザーの属性移住状態
final userMigrationProvider = FutureProvider<MigrationState>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const MigrationState();

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('migration')
        .doc('state')
        .get();
    if (!doc.exists) return const MigrationState();
    return MigrationState.fromMap(doc.data() ?? {});
  } catch (e) {
    debugPrint('Error loading migration state: $e');
    return const MigrationState();
  }
});

Future<void> _persistMigrationState(String userId, MigrationState state) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('migration')
        .doc('state')
        .set(state.toMap(), SetOptions(merge: true));
  } catch (e) {
    debugPrint('Error saving migration state: $e');
  }
}

// 有効な移住先（週が変わっていたら null 扱い）
final activeMigrationAttributeProvider = Provider<String?>((ref) {
  final state = ref.watch(migrationStateProvider);
  final currentWeek = _isoWeekNumber(DateTime.now());
  if (state.forWeek != currentWeek) return null;
  return state.attribute;
});

// 今週の優勢属性へ移住する（コイン消費）。残高不足なら false を返す。
bool migrateToFavoredAttribute(WidgetRef ref) {
  final wallet = ref.read(walletProvider);
  if (wallet.coinBalance < kMigrationCost) return false;

  final favored = ref.read(weeklyFavoredAttributeProvider);
  final currentWeek = _isoWeekNumber(DateTime.now());

  final updatedWallet = wallet.copyWith(
    coinBalance: wallet.coinBalance - kMigrationCost,
  );
  final newMigrationState = MigrationState(attribute: favored, forWeek: currentWeek);

  ref.read(walletProvider.notifier).state = updatedWallet;
  ref.read(migrationStateProvider.notifier).state = newMigrationState;

  final userId = ref.read(currentUserIdProvider);
  if (userId != null) {
    updateWallet(userId, updatedWallet);
    _persistMigrationState(userId, newMigrationState);
  }
  return true;
}

String migrationAttributeEmoji(String attr) => switch (attr) {
      'joy' => '☀️',
      'anger' => '🔥',
      'sadness' => '🌙',
      _ => '⭐',
    };

String migrationAttributeLabel(String attr) => switch (attr) {
      'joy' => '喜の大陸',
      'anger' => '怒の大陸',
      'sadness' => '哀の大陸',
      _ => '?',
    };
