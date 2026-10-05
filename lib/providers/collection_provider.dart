import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import '../models/user_card.dart';
import '../services/functions_service.dart';
import 'auth_provider.dart';
import 'card_rental_provider.dart';
import 'game_state_provider.dart';

// ローカル状態管理用（既存のwalletProvider/migrationStateProviderと同じパターン）。
// カード作成直後にここへ楽観的に追加することで、Firestore書き込み完了を待たずに
// コレクション・デッキ編成画面へ即座に反映される。
final myCardsProvider = StateProvider<List<UserCard>>((ref) => []);

// walletHydratedForUidProviderと同じ役割のガード（ユーザーごとに1回だけ復元する）
final myCardsHydratedForUidProvider = StateProvider<String?>((ref) => null);

// Firestore統合版：ユーザーが作成した全カード
final userCardsFirestoreProvider = FutureProvider<List<UserCard>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cards')
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map((d) => UserCard.fromMap(d.data())).toList();
  } catch (e) {
    debugPrint('Error loading user cards: $e');
    return [];
  }
});

// シードカード + 自分が作成したカードを統合した、プレイヤーが実際に選べるカード一覧。
// デッキ編成・コレクション画面はこちらを使う（AI対戦相手の生成にはallPlayCardsProvider
// 〔シードカードのみ〕を引き続き使うこと — 相手デッキに自分のカードが混ざるのはおかしいため）。
final myCollectionProvider = Provider<List<PlayCard>>((ref) {
  final seedCards = ref.watch(allPlayCardsProvider);
  final myCards = ref.watch(myCardsProvider);
  return [...seedCards, ...myCards.map((c) => c.toPlayCard())];
});

// myCollectionProvider（マイカード画面の「所有カード」表示用）に、現在有効な
// レンタル中カードを加えた、実際にデッキへ編成できるカード全体。
// デッキ編成画面はこちらを使うこと — myCollectionProviderのままだと、
// お金を払ってレンタルしたカードが実際のバトルでは一切使えないことになる。
// 「マイカード」ギャラリー（collection_screen.dart）は所有カードのみを見せたいので
// あえてmyCollectionProviderのままにしている（レンタル品を「所有」扱いしない）。
final battleEligibleCardsProvider = Provider<List<PlayCard>>((ref) {
  final owned = ref.watch(myCollectionProvider);
  final rented = ref.watch(myActiveRentalsProvider).value ?? [];
  return [...owned, ...rented];
});

Future<void> saveUserCard(String userId, UserCard card) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cards')
        .doc(card.cardId)
        .set(card.toMap(), SetOptions(merge: true));
  } catch (e) {
    debugPrint('Error saving user card: $e');
  }
}

// カードを1レベル特訓する（コイン消費・サーバー権威）。levelUpCard Cloud Function
// 経由でサーバー側がレベル上限・残高・レベルアップ幅（+1固定）を検証してから
// アトミックに更新する。以前はクライアントが直接Firestoreへlevelを書き込んでおり、
// 改造クライアント/直接呼び出しでlevelを任意の値に詐称できてしまっていた
// （pvpBattle.tsのresolveCustomCardがそのlevelを検証なしで信用してPvP戦闘の実ダメージを
//  計算するため、rating/seasonProgressと同じ深刻さで対戦の公正性を壊せていた）。
// 成功時はnullを返し、ローカルのmyCardsProvider/walletProviderにも反映する。
// 失敗時（上限到達・残高不足など）はサーバー側のエラーメッセージを返す。
Future<String?> levelUpCard(WidgetRef ref, String cardId) async {
  try {
    final result = await FunctionsService.levelUpCard(cardId: cardId);
    final newLevel = result['newLevel'] as int;
    final newCoinBalance = result['newCoinBalance'] as int;

    final cards = ref.read(myCardsProvider);
    final index = cards.indexWhere((c) => c.cardId == cardId);
    if (index != -1) {
      final updatedCards = List<UserCard>.from(cards)..[index] = cards[index].copyWith(level: newLevel);
      ref.read(myCardsProvider.notifier).state = updatedCards;
    }
    final wallet = ref.read(walletProvider);
    ref.read(walletProvider.notifier).state = wallet.copyWith(coinBalance: newCoinBalance);
    return null;
  } on FirebaseFunctionsException catch (e) {
    return e.message ?? 'unknown error';
  } catch (_) {
    return 'unknown error';
  }
}
