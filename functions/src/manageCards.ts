import * as functions from "firebase-functions/v1";
import {getFirestore, FieldValue, Transaction} from "firebase-admin/firestore";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// カード作成・特訓（サーバー権威）
// これまでcard_creation_screen_v2.dart/collection_provider.dartがコイン残高と
// カードのattackPower/defensePower/speed/levelを直接Firestoreへ書き込んでおり、
// 事実上クライアントが「自分のカードの戦闘力」を無制限に自己申告できる状態だった
// （firestore.rulesのcards/{cardId}は本人のuidチェックのみでフィールド内容は無検証）。
// pvpBattle.tsのresolveCustomCardはこの値を検証なしで信用してPvP戦闘の実ダメージを
// 計算するため、レーティング/シーズン進捗と同じ深刻さで対戦の公正性を壊せてしまっていた。
// rentCard.ts/pvpBattle.ts/manageSeasons.tsと同じ方針で、実数値の決定とコイン移動を
// このCloud Function側のトランザクションに一本化する。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// lib/screens/card_creation_screen_v2.dart の _budget と同じ値
const BUDGET_BY_COST: Record<number, number> = {1: 20, 2: 25, 3: 30, 4: 35, 5: 40};
// 同ファイルの kParamBigHitBonusPercent / _rollParameters のロール幅（±2）と同じ値。
// ガチャ演出が生成しうる合計値の範囲を超えるステータスは詐称とみなして拒否する。
const BIG_HIT_BONUS_PERCENT = 0.15;
const ROLL_VARIANCE = 2;

const VALID_ATTRIBUTES = ["joy", "anger", "sadness"];

// lib/providers/game_state_provider.dart の kCardCreationCoinCostByTier /
// kVipCardCreationDiscount と同じ値
const CARD_CREATION_COIN_COST_BY_TIER: Record<number, number> = {1: 80, 2: 120, 3: 160, 4: 220, 5: 300};
const VIP_DISCOUNT = 0.2;

// ウォレット未作成（初回アクセス前）の場合のデフォルト残高。
// lib/providers/game_state_provider.dart の WalletState() のデフォルトと同じ値。
const DEFAULT_COIN_BALANCE = 100;

function cardCreationCoinCost(isVip: boolean, cost: number): number {
  const base = CARD_CREATION_COIN_COST_BY_TIER[cost] ?? CARD_CREATION_COIN_COST_BY_TIER[1];
  return isVip ? Math.round(base * (1 - VIP_DISCOUNT)) : base;
}

interface CreateCardRequest {
  attribute: string;
  cost: number;
  attackPower: number;
  defensePower: number;
  speed: number;
  cardNameJp?: string;
  cardNameEn?: string;
  imageUrl?: string;
  coCreatorName?: string;
  // VIP割引の適用要否。RevenueCatエンタイトルメントをこの関数からサーバー側で
  // 検証する仕組みは未整備のため、現状はクライアント申告を信用している
  // （最大でも20%引きの範囲に収まる程度の実害であり、ステータス詐称ほど
  //  深刻ではないため、この修正のスコープでは対象外としている）。
  isVip?: boolean;
}

export const createCard = functions
  .region("asia-northeast1")
  .runWith({timeoutSeconds: 30})
  .https.onCall(async (data: CreateCardRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }
    const userId = context.auth.uid;

    const cost = data.cost;
    const budget = BUDGET_BY_COST[cost];
    if (!budget) {
      throw new functions.https.HttpsError("invalid-argument", "不正なコスト帯です");
    }
    if (!VALID_ATTRIBUTES.includes(data.attribute)) {
      throw new functions.https.HttpsError("invalid-argument", "不正な属性です");
    }

    const {attackPower, defensePower, speed} = data;
    if (
      !Number.isInteger(attackPower) || !Number.isInteger(defensePower) || !Number.isInteger(speed) ||
      attackPower < 1 || defensePower < 1 || speed < 1
    ) {
      throw new functions.https.HttpsError("invalid-argument", "不正なステータス値です");
    }
    const total = attackPower + defensePower + speed;
    const minTotal = Math.max(3, budget - ROLL_VARIANCE);
    const maxTotal = Math.round(budget * (1 + BIG_HIT_BONUS_PERCENT));
    if (total < minTotal || total > maxTotal) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "ステータス値がコスト帯の予算範囲外です"
      );
    }

    const coinCost = cardCreationCoinCost(data.isVip === true, cost);
    const cardId = `created_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
    const cardNameJp = (data.cardNameJp ?? "").trim() || "無名のカード";
    const cardNameEn = (data.cardNameEn ?? "").trim() || cardNameJp;

    const walletRef = getFirestore().collection("users").doc(userId).collection("wallet").doc("balance");
    const cardRef = getFirestore().collection("users").doc(userId).collection("cards").doc(cardId);

    const newCoinBalance = await getFirestore().runTransaction(async (tx: Transaction) => {
      const walletDoc = await tx.get(walletRef);
      const coinBalance: number = walletDoc.data()?.coinBalance ?? DEFAULT_COIN_BALANCE;
      if (coinBalance < coinCost) {
        throw new functions.https.HttpsError("failed-precondition", "コインが不足しています");
      }
      const updatedBalance = coinBalance - coinCost;

      tx.set(walletRef, {
        coinBalance: updatedBalance,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      tx.set(cardRef, {
        cardId,
        userId,
        attribute: data.attribute,
        cost,
        attackPower,
        defensePower,
        speed,
        cardName: {jp: cardNameJp, en: cardNameEn},
        cardDescription: {jp: "", en: ""},
        imageUrl: data.imageUrl ?? "",
        imagePromptUsed: "",
        bonusPointsEarned: 0,
        totalVictoriesWithCard: 0,
        todayVictoriesCount: 0,
        wins: 0,
        losses: 0,
        createdAt: FieldValue.serverTimestamp(),
        coCreatorId: null,
        coCreatorName: data.coCreatorName ?? null,
        level: 0,
        isPublic: false,
        rentalCostPerDay: 50,
        totalRentalCount: 0,
        totalRentalEarnings: 0,
      });

      return updatedBalance;
    });

    return {success: true, cardId, newCoinBalance};
  });

// lib/models/user_card.dart の kMaxCardLevel / cardLevelUpCost と同じ値
const MAX_CARD_LEVEL = 5;
function cardLevelUpCost(currentLevel: number): number {
  return 50 * (currentLevel + 1);
}

export const levelUpCard = functions
  .region("asia-northeast1")
  .runWith({timeoutSeconds: 30})
  .https.onCall(async (data: {cardId: string}, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }
    const userId = context.auth.uid;
    const {cardId} = data;
    if (!cardId) {
      throw new functions.https.HttpsError("invalid-argument", "cardIdが必要です");
    }

    const cardRef = getFirestore().collection("users").doc(userId).collection("cards").doc(cardId);
    const walletRef = getFirestore().collection("users").doc(userId).collection("wallet").doc("balance");

    try {
      return await getFirestore().runTransaction(async (tx: Transaction) => {
        const cardDoc = await tx.get(cardRef);
        if (!cardDoc.exists) {
          throw new functions.https.HttpsError("not-found", "カードが見つかりません");
        }
        const level: number = cardDoc.data()?.level ?? 0;
        if (level >= MAX_CARD_LEVEL) {
          throw new functions.https.HttpsError("failed-precondition", "既に最大レベルです");
        }
        const cost = cardLevelUpCost(level);

        const walletDoc = await tx.get(walletRef);
        const coinBalance: number = walletDoc.data()?.coinBalance ?? DEFAULT_COIN_BALANCE;
        if (coinBalance < cost) {
          throw new functions.https.HttpsError("failed-precondition", "コインが不足しています");
        }
        const updatedBalance = coinBalance - cost;

        tx.set(walletRef, {
          coinBalance: updatedBalance,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        tx.update(cardRef, {level: level + 1});

        return {success: true, newLevel: level + 1, newCoinBalance: updatedBalance};
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      console.error(`Failed to level up card ${cardId} for ${userId}:`, error);
      throw new functions.https.HttpsError("internal", "特訓に失敗しました");
    }
  });
