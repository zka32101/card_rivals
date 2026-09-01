import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/card_rental.dart';
import '../models/user_card.dart';
import '../services/functions_service.dart';
import 'auth_provider.dart';
import 'collection_provider.dart';
import 'game_state_provider.dart';

// クリエイター取り分（レンタル料の40%）。functions/src/rentCard.ts の
// CREATOR_SHARE_PERCENT と同じ値（実際の配分計算はサーバー側で行う。ここでは表示用）。
const int kRentalCreatorSharePercent = 40;

// レンタル日数プランと総額（コイン）。functions/src/rentCard.ts の RENTAL_PLANS と
// 必ず同じ値にすること — 表示価格とサーバー請求額を一致させるため。
const Map<int, int> kRentalPlans = {1: 50, 7: 300, 30: 1000};

// 自分のレンタル収益累計（自分が作成した公開カード全体の合計）。
// myCardsProvider（Firestoreからハイドレーション済み）の実データから導出する。
final userRentalEarningsProvider = Provider<int>((ref) {
  final myCards = ref.watch(myCardsProvider);
  return myCards.fold<int>(0, (total, c) => total + c.totalRentalEarnings);
});

// カードの公開/非公開を切り替える。レンタル料自体はkRentalPlansの固定テーブルで
// 決まるため、ここでは公開フラグのみをFirestoreへ永続化する
// （単一ユーザーの所有カード編集であり、pvpBattle/rentCardのような他ユーザーとの
//  通貨移動を伴わないため、既存のsaveUserCardと同じくクライアント直接書き込みで良い）。
Future<void> toggleCardPublic(WidgetRef ref, String cardId, bool isPublic) async {
  final cards = ref.read(myCardsProvider);
  final index = cards.indexWhere((c) => c.cardId == cardId);
  if (index == -1) return;

  final updated = cards[index].copyWith(isPublic: isPublic);
  final updatedCards = List<UserCard>.from(cards)..[index] = updated;
  ref.read(myCardsProvider.notifier).state = updatedCards;

  final userId = ref.read(currentUserIdProvider);
  if (userId != null) await saveUserCard(userId, updated);
}

// 人気度ランキング（公開設定されている全ユーザーのカードを横断取得）。
// isPublic=trueのカードを、現状トラッキングできている唯一の人気度シグナルである
// レンタル回数順に並べる。使用回数・勝率を反映したスコアリングは、PvPバトル側に
// カード使用実績のトラッキングを追加してから拡張する（今回のスコープ外）。
final popularCardsProvider = FutureProvider<List<CardPopularityScore>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collectionGroup('cards')
      .where('isPublic', isEqualTo: true)
      .orderBy('totalRentalCount', descending: true)
      .limit(100)
      .get();

  return List.generate(snapshot.docs.length, (i) {
    final data = snapshot.docs[i].data();
    final cardName = Map<String, String>.from(data['cardName'] ?? {});
    final creatorId = data['userId'] as String? ?? '';
    final rentalCount = (data['totalRentalCount'] as int?) ?? 0;
    final earnings = (data['totalRentalEarnings'] as int?) ?? 0;

    return CardPopularityScore(
      cardId: data['cardId'] as String? ?? snapshot.docs[i].id,
      cardName: cardName['jp'] ?? cardName['en'] ?? '',
      creatorId: creatorId,
      // このアプリにはまだ表示名（ハンドルネーム）機能が無く、認証も匿名のみのため、
      // UIDの先頭6文字を使った擬似ハンドルで代用する（今後、表示名機能を追加したら差し替える）。
      creatorName: creatorId.length >= 6 ? 'Player-${creatorId.substring(0, 6)}' : 'Player',
      attribute: data['attribute'] as String? ?? 'joy',
      cost: (data['cost'] as int?) ?? 1,
      totalUsageCount: 0, // 未トラッキング（対象外）
      totalRentalCount: rentalCount,
      totalBattlesWithCard: 0, // 未トラッキング（対象外）
      totalWinsWithCard: 0,
      winRate: 0,
      totalEarnings: earnings,
      popularityScore: rentalCount.toDouble() + earnings * 0.05,
      rank: i + 1,
      lastUpdated: DateTime.now(),
    );
  });
});

// 現在有効な（期限切れでない）自分のレンタル中カード一覧。
// rentCard Cloud Functionがレンタル成立時にrentals/{id}へ書き込んだステータス
// スナップショットをそのまま使う — 貸し手側の元カードを都度読みに行かない
// （貸し手が後で非公開にしたり削除したりしても、契約時点の内容でレンタルが
//  継続する。pvpBattle.tsのresolveRentedCardも同じスナップショットを参照する）。
final myActiveRentalsProvider = FutureProvider<List<PlayCard>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('rentals')
        .where('renterUid', isEqualTo: userId)
        .where('rentalEnd', isGreaterThan: Timestamp.now())
        .get();

    return snapshot.docs.map((d) {
      final data = d.data();
      final cardName = Map<String, String>.from(data['cardName'] ?? {});
      return PlayCard(
        cardId: data['cardId'] as String? ?? '',
        attribute: data['attribute'] as String? ?? 'joy',
        cost: (data['cost'] as int?) ?? 1,
        attackPower: (data['attackPower'] as int?) ?? 0,
        defensePower: (data['defensePower'] as int?) ?? 0,
        speed: (data['speed'] as int?) ?? 0,
        nameJp: cardName['jp'] ?? '',
        nameEn: cardName['en'] ?? '',
        isSeedCard: false,
        isRented: true,
      );
    }).toList();
  } catch (e) {
    debugPrint('Error loading active rentals: $e');
    return [];
  }
});

// カードをレンタルする（rentCard Cloud Function経由・サーバー権威）。
// 成功時は借り手の残高をローカルウォレットにも反映してnullを返す。
// 失敗時（残高不足・公開停止済みなど）はサーバー側のエラーメッセージを返す。
Future<String?> rentCard(WidgetRef ref, CardPopularityScore card, int rentalDays) async {
  try {
    final result = await FunctionsService.rentCard(
      cardId: card.cardId,
      creatorId: card.creatorId,
      rentalDays: rentalDays,
    );
    final newBalance = result['newCoinBalance'] as int?;
    if (newBalance != null) {
      final wallet = ref.read(walletProvider);
      ref.read(walletProvider.notifier).state = wallet.copyWith(coinBalance: newBalance);
    }
    return null;
  } on FirebaseFunctionsException catch (e) {
    return e.message ?? 'unknown error';
  } catch (_) {
    return 'unknown error';
  }
}
