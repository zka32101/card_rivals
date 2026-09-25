import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PvPマッチング
// 現時点では実プレイヤーの防衛デッキプールが未整備のため、レーティングに応じた
// 対戦相手（名前・ティア・デッキ）をサーバー側で生成して返す。
// クライアント側で完結していたマッチング処理をサーバーに移すことで、
// 将来Firestore上の実プレイヤー防衛デッキとマッチングする設計に拡張しやすくする。
// TODO: users/{uid}/defenseDeck のようなコレクションを新設し、実プレイヤー同士の
//       マッチングに置き換える（rating近傍のプレイヤーをクエリして対戦相手にする）。
//
// 生成した対戦相手デッキは pvpMatches/{matchId} にサーバー側の記録として保存し、
// pvpBattle実行時はこのmatchIdを使って記録を再取得する。
// クライアントが送ってくる defenderDeckSnapshot は一切信用しない
// （改造クライアントが弱い偽の相手デッキを自己申告してくる不正を防ぐため）。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface OpponentCard {
  cardId: string;
  attribute: string;
  cost: number;
  attackPower: number;
  defensePower: number;
  speed: number;
  nameJp: string;
}

// シードカードの一部を流用した対戦相手プール（属性バランス良く採用）
const OPPONENT_POOL: OpponentCard[] = [
  {cardId: "anger_c2_001", attribute: "anger", cost: 2, attackPower: 14, defensePower: 6, speed: 5, nameJp: "怒りの王"},
  {cardId: "anger_c2_003", attribute: "anger", cost: 2, attackPower: 8, defensePower: 8, speed: 9, nameJp: "怒りの炎"},
  {cardId: "sadness_c2_001", attribute: "sadness", cost: 2, attackPower: 12, defensePower: 8, speed: 5, nameJp: "悲しみの王"},
  {cardId: "sadness_c2_004", attribute: "sadness", cost: 2, attackPower: 5, defensePower: 7, speed: 13, nameJp: "泪の精"},
  {cardId: "joy_c2_001", attribute: "joy", cost: 2, attackPower: 14, defensePower: 6, speed: 5, nameJp: "光の騎士"},
  {cardId: "joy_c2_003", attribute: "joy", cost: 2, attackPower: 8, defensePower: 8, speed: 9, nameJp: "幸せの輪"},
  {cardId: "anger_c3_003", attribute: "anger", cost: 3, attackPower: 10, defensePower: 5, speed: 15, nameJp: "獄炎の戦士"},
  {cardId: "sadness_c3_003", attribute: "sadness", cost: 3, attackPower: 9, defensePower: 10, speed: 11, nameJp: "泪の魔女"},
];

const OPPONENT_NAME_BASES = [
  "Shadow_Player", "Mystic_Wanderer", "Ember_Knight", "Silent_Oracle", "Storm_Rider",
];

const TIER_TABLE = [
  {min: 2000, label: "💎プラチナ"},
  {min: 1500, label: "🥇ゴールド"},
  {min: 1000, label: "🥈シルバー"},
  {min: 0, label: "🥉ブロンズ"},
];

function tierFor(rating: number): string {
  for (const t of TIER_TABLE) {
    if (rating >= t.min) return t.label;
  }
  return TIER_TABLE[TIER_TABLE.length - 1].label;
}

export const pvpMatch = onCall(
  {region: "asia-northeast1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }

    const data = request.data as {attackerRating?: number};
    const rating = data.attackerRating ?? 1000;
    // マッチのたびに異なる相手になるよう現在時刻も混ぜたシード
    const seed = Math.abs(rating + Date.now());

    const nameBase = OPPONENT_NAME_BASES[seed % OPPONENT_NAME_BASES.length];
    const opponentName = `${nameBase}_${seed % 100}`;
    // ±100の範囲でレーティングに近い相手にする
    const opponentRating = Math.max(0, rating + ((seed % 201) - 100));
    const opponentTier = tierFor(opponentRating);

    const deck: OpponentCard[] = [];
    for (let i = 0; i < 5; i++) {
      deck.push(OPPONENT_POOL[(seed + i * 3) % OPPONENT_POOL.length]);
    }

    const matchRef = await getFirestore().collection("pvpMatches").add({
      attackerUid: request.auth.uid,
      opponentDeckCardIds: deck.map((c) => c.cardId),
      opponentName,
      opponentTier,
      opponentRating,
      consumed: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      matchId: matchRef.id,
      opponentName,
      opponentTier,
      opponentRating,
      opponentDeck: deck,
    };
  });
