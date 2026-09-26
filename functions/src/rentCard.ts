import * as functions from "firebase-functions/v1";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// カードレンタル（サーバー権威）
// 借り手のコインを減らし、貸し手（カード作者）へ収益を渡す — 2ユーザー間の
// 通貨移動を伴うため、pvpBattle/購入処理と同様にクライアント側の直接
// Firestore書き込みを許可せず、必ずこのCloud Function経由で行う。
// 過去の実装は完全にローカルStateProviderのみで動いており、renterIdも
// 常に'user_placeholder'という固定文字列だった（誰の残高も実際には
// 変動せず、レンタル収益もクリエイターに一切届いていなかった）。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// レンタル日数プランと総額（コイン）。
// lib/screens/popular_cards_screen.dart の _rentalPlans と同じ値。
// 表示価格とサーバー請求額を一致させるため、変更する場合は両方直すこと。
const RENTAL_PLANS: Record<number, number> = {1: 50, 7: 300, 30: 1000};

// クリエイター取り分（レンタル料の40%）。デッキ育成の主なコイン源はバトル
// 勝利のままにし、レンタル収益は補助的な位置づけに留めるため70%から引き下げ。
// lib/providers/card_rental_provider.dart の kRentalCreatorSharePercent と同じ値。
const CREATOR_SHARE_PERCENT = 40;

// ウォレット未作成（初回アクセス前）の場合のデフォルト残高。
// lib/providers/game_state_provider.dart の WalletState() のデフォルトと同じ値。
const DEFAULT_COIN_BALANCE = 100;

// カード育成（特訓）のレベルボーナス。lib/models/user_card.dart の
// kCardLevelAttackBonus/kCardLevelDefenseBonus/kCardLevelSpeedBonus、
// および pvpBattle.ts の同名定数と同じ値。
const CARD_LEVEL_ATTACK_BONUS = 2;
const CARD_LEVEL_DEFENSE_BONUS = 2;
const CARD_LEVEL_SPEED_BONUS = 1;

// 1枚のカードにつき、同時に有効なレンタル契約数の上限。取り分を引き下げても
// なお「1枚の人気カードを無数の相手に貸し続けて際限なく稼ぐ」ことができて
// しまわないよう、貸し出し可能な人数そのものにも歯止めをかける。
const MAX_CONCURRENT_RENTERS_PER_CARD = 3;

interface RentCardRequest {
  cardId: string;
  creatorId: string;
  rentalDays: number;
}

export const rentCard = functions
  .region("asia-northeast1")
  .runWith({timeoutSeconds: 30})
  .https.onCall(async (data: RentCardRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }
    const renterId = context.auth.uid;
    const {cardId, creatorId, rentalDays} = data;

    if (!cardId || !creatorId || !rentalDays) {
      throw new functions.https.HttpsError("invalid-argument", "リクエストが不正です");
    }
    if (renterId === creatorId) {
      throw new functions.https.HttpsError("invalid-argument", "自分のカードはレンタルできません");
    }
    const totalCost = RENTAL_PLANS[rentalDays];
    if (!totalCost) {
      throw new functions.https.HttpsError("invalid-argument", "不正なレンタル期間です");
    }

    const db = getFirestore();
    const cardRef = db.collection("users").doc(creatorId).collection("cards").doc(cardId);
    const renterWalletRef = db.collection("users").doc(renterId).collection("wallet").doc("balance");
    const creatorWalletRef = db.collection("users").doc(creatorId).collection("wallet").doc("balance");
    const rentalRef = db.collection("rentals").doc();
    // cardIdは作成時刻ミリ秒ベース（'created_<millis>'）で、別ユーザーが同一
    // ミリ秒に作成した場合に理論上衝突しうるため、creatorUidも合わせて絞り込み、
    // 他人の同名IDカードのレンタルを誤って人数にカウントしないようにする。
    const activeRentersQuery = db.collection("rentals")
      .where("creatorUid", "==", creatorId)
      .where("cardId", "==", cardId)
      .where("rentalEnd", ">", Timestamp.now());

    const creatorEarnings = Math.floor((totalCost * CREATOR_SHARE_PERCENT) / 100);

    const newRenterBalance = await db.runTransaction(async (tx) => {
      // ── 読み取りは書き込みより先に行う（Firestoreトランザクションの制約） ──
      const cardDoc = await tx.get(cardRef);
      if (!cardDoc.exists) {
        throw new functions.https.HttpsError("not-found", "カードが見つかりません");
      }
      const cardData = cardDoc.data()!;
      if (cardData.isPublic !== true) {
        throw new functions.https.HttpsError("failed-precondition", "このカードは現在レンタル公開されていません");
      }

      // 同時貸し出し人数の上限チェック（1枚の人気カードだけで際限なく
      // 稼ぎ続けられないよう、有効なレンタル契約数に歯止めをかける）。
      const activeRentersSnap = await tx.get(activeRentersQuery.count());
      if (activeRentersSnap.data().count >= MAX_CONCURRENT_RENTERS_PER_CARD) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "このカードは現在貸し出し人数の上限に達しています。空きが出るまでお待ちください"
        );
      }

      const renterWalletDoc = await tx.get(renterWalletRef);
      const renterBalance: number = renterWalletDoc.data()?.coinBalance ?? DEFAULT_COIN_BALANCE;
      if (renterBalance < totalCost) {
        throw new functions.https.HttpsError("failed-precondition", "コインが不足しています");
      }

      const creatorWalletDoc = await tx.get(creatorWalletRef);
      const creatorBalance: number = creatorWalletDoc.data()?.coinBalance ?? DEFAULT_COIN_BALANCE;

      // ── ここから書き込み ──
      const now = Timestamp.now();
      const rentalEnd = Timestamp.fromMillis(
        now.toMillis() + rentalDays * 24 * 60 * 60 * 1000
      );

      tx.set(renterWalletRef, {
        coinBalance: renterBalance - totalCost,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      tx.set(creatorWalletRef, {
        coinBalance: creatorBalance + creatorEarnings,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      tx.update(cardRef, {
        totalRentalCount: FieldValue.increment(1),
        totalRentalEarnings: FieldValue.increment(creatorEarnings),
      });

      // カードのステータスをレンタル成立時点でスナップショットしておく。
      // 借り手はこの内容だけを見てバトルに使う（貸し手が後で非公開にしたり
      // カードを編集・削除しても、契約時点の内容でレンタルが継続する）。
      // pvpBattle.ts の resolveRentedCard も同じスナップショットを参照する。
      tx.set(rentalRef, {
        id: rentalRef.id,
        cardId,
        cardName: cardData.cardName?.jp || cardData.cardName?.en || "",
        attribute: cardData.attribute,
        cost: cardData.cost ?? 1,
        attackPower: (cardData.attackPower ?? 0) + (cardData.level ?? 0) * CARD_LEVEL_ATTACK_BONUS,
        defensePower: (cardData.defensePower ?? 0) + (cardData.level ?? 0) * CARD_LEVEL_DEFENSE_BONUS,
        speed: (cardData.speed ?? 0) + (cardData.level ?? 0) * CARD_LEVEL_SPEED_BONUS,
        renterUid: renterId,
        creatorUid: creatorId,
        totalCost,
        rentalDays,
        creatorEarnings,
        rentalStart: now,
        rentalEnd,
        createdAt: FieldValue.serverTimestamp(),
      });

      return renterBalance - totalCost;
    });

    return {success: true, newCoinBalance: newRenterBalance, totalCost, creatorEarnings};
  });
