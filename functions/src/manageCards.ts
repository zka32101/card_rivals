import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

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

// lib/providers/game_state_provider.dart の kCardCreationBudget と同じ値。
// レア度に関わらずカード1枚あたりのパラメータ総予算は一律固定
// （以前はレア度が高いほど予算も大きく、実質「常に最高レア度一択」になる
// 設計だったため、価格・予算とも完全固定にした上でレア度自体はガチャ抽選にした）。
const CARD_CREATION_BUDGET = 34;
// 同ファイルの kParamBigHitBonusPercent / _rollParameters のロール幅（±2）と同じ値。
// ガチャ演出が生成しうる合計値の範囲を超えるステータスは詐称とみなして拒否する。
const BIG_HIT_BONUS_PERCENT = 0.15;
const ROLL_VARIANCE = 2;

const VALID_ATTRIBUTES = ["joy", "anger", "sadness"];

// lib/providers/game_state_provider.dart の kCardCreationCoinCost /
// kVipCardCreationDiscount と同じ値
const CARD_CREATION_COIN_COST = 100;
const VIP_DISCOUNT = 0.2;

// ウォレット未作成（初回アクセス前）の場合のデフォルト残高。
// lib/providers/game_state_provider.dart の WalletState() のデフォルトと同じ値。
const DEFAULT_COIN_BALANCE = 100;

function cardCreationCoinCost(isVip: boolean): number {
  return isVip ? Math.round(CARD_CREATION_COIN_COST * (1 - VIP_DISCOUNT)) : CARD_CREATION_COIN_COST;
}

// カードのレア度（cost 1=N, 2=R, 4=SR, 5=UR。lib/models/user_card.dart の
// PlayCard.rarity と同じ対応表）を確率で決めるガチャ抽選。
// クライアントには選択させず、必ずサーバー側のこの抽選のみを信用する
// （そうしないと改造クライアントが常に最高レア度を自己申告できてしまう）。
const RARITY_ROLL_TABLE: Array<{cost: number; weight: number}> = [
  {cost: 1, weight: 0.50}, // N
  {cost: 2, weight: 0.35}, // R
  {cost: 4, weight: 0.12}, // SR
  {cost: 5, weight: 0.03}, // UR
];

function rollCardCostTier(): number {
  const r = Math.random();
  let acc = 0;
  for (const entry of RARITY_ROLL_TABLE) {
    acc += entry.weight;
    if (r < acc) return entry.cost;
  }
  return RARITY_ROLL_TABLE[0].cost;
}

interface CreateCardRequest {
  attribute: string;
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

export const createCard = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    const data = request.data as CreateCardRequest;
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }
    const userId = request.auth.uid;

    // レア度（cost）はクライアントには選ばせず必ずここで抽選する。
    const cost = rollCardCostTier();
    const budget = CARD_CREATION_BUDGET;
    if (!VALID_ATTRIBUTES.includes(data.attribute)) {
      throw new HttpsError("invalid-argument", "不正な属性です");
    }

    const {attackPower, defensePower, speed} = data;
    if (
      !Number.isInteger(attackPower) || !Number.isInteger(defensePower) || !Number.isInteger(speed) ||
      attackPower < 1 || defensePower < 1 || speed < 1
    ) {
      throw new HttpsError("invalid-argument", "不正なステータス値です");
    }
    const total = attackPower + defensePower + speed;
    const minTotal = Math.max(3, budget - ROLL_VARIANCE);
    const maxTotal = Math.round(budget * (1 + BIG_HIT_BONUS_PERCENT));
    if (total < minTotal || total > maxTotal) {
      throw new HttpsError(
        "invalid-argument",
        "ステータス値が予算範囲外です"
      );
    }

    const coinCost = cardCreationCoinCost(data.isVip === true);
    const cardId = `created_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
    const cardNameJp = (data.cardNameJp ?? "").trim() || "無名のカード";
    const cardNameEn = (data.cardNameEn ?? "").trim() || cardNameJp;

    const walletRef = getFirestore().collection("users").doc(userId).collection("wallet").doc("balance");
    const cardRef = getFirestore().collection("users").doc(userId).collection("cards").doc(cardId);

    const newCoinBalance = await getFirestore().runTransaction(async (tx: FirebaseFirestore.Transaction) => {
      const walletDoc = await tx.get(walletRef);
      const coinBalance: number = walletDoc.data()?.coinBalance ?? DEFAULT_COIN_BALANCE;
      if (coinBalance < coinCost) {
        throw new HttpsError("failed-precondition", "コインが不足しています");
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

    return {success: true, cardId, newCoinBalance, cost};
  });

// lib/models/user_card.dart の kMaxCardLevel / cardLevelUpCost と同じ値
const MAX_CARD_LEVEL = 5;
function cardLevelUpCost(currentLevel: number): number {
  return 50 * (currentLevel + 1);
}

export const levelUpCard = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    const data = request.data as {cardId: string};
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }
    const userId = request.auth.uid;
    const {cardId} = data;
    if (!cardId) {
      throw new HttpsError("invalid-argument", "cardIdが必要です");
    }

    const cardRef = getFirestore().collection("users").doc(userId).collection("cards").doc(cardId);
    const walletRef = getFirestore().collection("users").doc(userId).collection("wallet").doc("balance");

    try {
      return await getFirestore().runTransaction(async (tx: FirebaseFirestore.Transaction) => {
        const cardDoc = await tx.get(cardRef);
        if (!cardDoc.exists) {
          throw new HttpsError("not-found", "カードが見つかりません");
        }
        const level: number = cardDoc.data()?.level ?? 0;
        if (level >= MAX_CARD_LEVEL) {
          throw new HttpsError("failed-precondition", "既に最大レベルです");
        }
        const cost = cardLevelUpCost(level);

        const walletDoc = await tx.get(walletRef);
        const coinBalance: number = walletDoc.data()?.coinBalance ?? DEFAULT_COIN_BALANCE;
        if (coinBalance < cost) {
          throw new HttpsError("failed-precondition", "コインが不足しています");
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
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error(`Failed to level up card ${cardId} for ${userId}:`, error);
      throw new HttpsError("internal", "特訓に失敗しました");
    }
  });
