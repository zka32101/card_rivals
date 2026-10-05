import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/deck_preset.dart';
import 'auth_provider.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 定数
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const int maxPresetsPerUser = 10;
const int maxCardsPerDeck = 30;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Providers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 現在のユーザーのすべてのデッキプリセットを取得
final userDeckPresetsProvider = FutureProvider<List<DeckPreset>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return [];
  }

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('deckPresets')
        .orderBy('updatedAt', descending: true)
        .get();

    final presets = querySnapshot.docs
        .map((doc) => DeckPreset.fromMap(
          doc.data(),
          id: doc.id,
          userId: userId,
        ))
        .toList();
    // お気に入りを先頭に（それぞれ更新が新しい順は維持。Dartのsortは安定ではないので位置も添える）
    final indexed = presets.asMap().entries.toList()
      ..sort((a, b) {
        if (a.value.isFavorite != b.value.isFavorite) return a.value.isFavorite ? -1 : 1;
        return a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  } catch (e) {
    debugPrint('Error loading deck presets: $e');
    return [];
  }
});

/// 特定のデッキプリセットを取得（IDで指定）
final deckPresetProvider = FutureProvider.family<DeckPreset?, String>((ref, presetId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || presetId.isEmpty) {
    return null;
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('deckPresets')
        .doc(presetId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return DeckPreset.fromMap(
      doc.data() ?? {},
      id: doc.id,
      userId: userId,
    );
  } catch (e) {
    debugPrint('Error loading deck preset: $e');
    return null;
  }
});

/// デッキプリセットの数
final deckPresetsCountProvider = Provider<int>((ref) {
  final presets = ref.watch(userDeckPresetsProvider);
  return presets.maybeWhen(
    data: (list) => list.length,
    orElse: () => 0,
  );
});

/// デッキプリセットを保存（新規または既存を上書き）
Future<String?> saveDeckPreset(
  WidgetRef ref, {
  required String name,
  required List<String> cardIds,
  String description = '',
  String? existingPresetId,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  // バリデーション
  if (name.isEmpty) {
    throw Exception('プリセット名は空にできません');
  }

  if (name.length > 50) {
    throw Exception('プリセット名は50文字以内です');
  }

  if (cardIds.isEmpty || cardIds.length > maxCardsPerDeck) {
    throw Exception('デッキには1〜$maxCardsPerDeck枚のカードが必要です');
  }

  try {
    final db = FirebaseFirestore.instance;
    final presetsRef = db.collection('users').doc(userId).collection('deckPresets');
    final now = DateTime.now();

    if (existingPresetId != null) {
      // 既存のプリセットを更新
      await presetsRef.doc(existingPresetId).update({
        'name': name,
        'description': description,
        'cardIds': cardIds,
        'updatedAt': Timestamp.fromDate(now),
      });

      // プロバイダをリフレッシュ
      ref.invalidate(userDeckPresetsProvider);
      ref.invalidate(deckPresetProvider(existingPresetId));

      return existingPresetId;
    } else {
      // 新しいプリセットを作成
      // 既存プリセット数をチェック
      final countSnapshot = await presetsRef.count().get();
      final count = countSnapshot.count ?? 0;
      if (count >= maxPresetsPerUser) {
        throw Exception('デッキプリセットは最大$maxPresetsPerUser個までです');
      }

      final presetId = presetsRef.doc().id;
      final presetData = DeckPreset(
        id: presetId,
        userId: userId,
        name: name,
        description: description,
        cardIds: cardIds,
        createdAt: now,
        updatedAt: now,
      );

      await presetsRef.doc(presetId).set(presetData.toMap());

      // プロバイダをリフレッシュ
      ref.invalidate(userDeckPresetsProvider);

      return presetId;
    }
  } catch (e) {
    debugPrint('Error saving deck preset: $e');
    rethrow;
  }
}

/// デッキの名前を変更
Future<void> renameDeckPreset(WidgetRef ref, String presetId, String newName) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) throw Exception('User not authenticated');
  final name = newName.trim();
  if (presetId.isEmpty || name.isEmpty) throw Exception('プリセット名は空にできません');
  if (name.length > 50) throw Exception('プリセット名は50文字以内です');

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('deckPresets')
      .doc(presetId)
      .update({'name': name, 'updatedAt': Timestamp.fromDate(DateTime.now())});
  ref.invalidate(userDeckPresetsProvider);
  ref.invalidate(deckPresetProvider(presetId));
}

/// デッキのお気に入りを切り替え
Future<void> setDeckPresetFavorite(WidgetRef ref, String presetId, bool favorite) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) throw Exception('User not authenticated');
  if (presetId.isEmpty) throw Exception('プリセットIDが必要です');

  // 並び順（更新日時）を変えないよう updatedAt は触らない
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('deckPresets')
      .doc(presetId)
      .update({'isFavorite': favorite});
  ref.invalidate(userDeckPresetsProvider);
  ref.invalidate(deckPresetProvider(presetId));
}

/// デッキプリセットを削除
Future<void> deleteDeckPreset(
  WidgetRef ref,
  String presetId,
) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  if (presetId.isEmpty) {
    throw Exception('プリセットIDが必要です');
  }

  try {
    final presetRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('deckPresets')
        .doc(presetId);

    // 存在確認
    final snap = await presetRef.get();
    if (!snap.exists) {
      throw Exception('プリセットが見つかりません');
    }

    // 削除
    await presetRef.delete();

    // プロバイダをリフレッシュ
    ref.invalidate(userDeckPresetsProvider);
    ref.invalidate(deckPresetProvider(presetId));
  } catch (e) {
    debugPrint('Error deleting deck preset: $e');
    rethrow;
  }
}

/// デッキプリセットをコピー
Future<String?> copyDeckPreset(
  WidgetRef ref, {
  required String sourcePresetId,
  required String newName,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  if (sourcePresetId.isEmpty || newName.isEmpty) {
    throw Exception('ソースプリセットIDと新しい名前が必要です');
  }

  if (newName.length > 50) {
    throw Exception('プリセット名は50文字以内です');
  }

  try {
    final db = FirebaseFirestore.instance;
    final sourceRef = db
        .collection('users')
        .doc(userId)
        .collection('deckPresets')
        .doc(sourcePresetId);
    final presetsRef = db.collection('users').doc(userId).collection('deckPresets');

    // ソースプリセットを取得
    final sourceSnap = await sourceRef.get();
    if (!sourceSnap.exists) {
      throw Exception('ソースプリセットが見つかりません');
    }

    // 既存プリセット数をチェック
    final countSnapshot = await presetsRef.count().get();
    final count = countSnapshot.count ?? 0;
    if (count >= maxPresetsPerUser) {
      throw Exception('デッキプリセットは最大$maxPresetsPerUser個までです');
    }

    final sourceData = sourceSnap.data() as Map<String, dynamic>? ?? {};
    final now = DateTime.now();
    final newPresetId = presetsRef.doc().id;

    final newPreset = DeckPreset(
      id: newPresetId,
      userId: userId,
      name: newName,
      description: sourceData['description'] ?? '',
      cardIds: List<String>.from(sourceData['cardIds'] ?? []),
      createdAt: now,
      updatedAt: now,
    );

    await presetsRef.doc(newPresetId).set(newPreset.toMap());

    // プロバイダをリフレッシュ
    ref.invalidate(userDeckPresetsProvider);

    return newPresetId;
  } catch (e) {
    debugPrint('Error copying deck preset: $e');
    rethrow;
  }
}
