import {getFirestore, Timestamp, FieldValue} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {SEED_CARDS} from "./seedCards";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PvPバトル判定（サーバー権威）
// lib/services/battle_engine.dart のロジックをそのまま移植。
// クライアント側の計算結果を信用せず、サーバー側で同じアルゴリズムを再計算することで
// ダメージ・勝敗の改ざんを防ぐ。レーティング更新もここで行う。
//
// 過去の実装は「クライアントが送ってきたattackPower/defensePower/speedをそのまま
// 使って再計算する」ようになっており、これは改ざん防止になっていなかった
// （改造クライアントが999/0のような数値を送れば確実に勝てた）。
// 現在は cardId のみを受け取り、実数値は必ずSEED_CARDS（サーバー側の正本データ）
// から引く。相手デッキも同様にクライアント申告を信用せず、pvpMatch が
// Firestoreに保存した記録（pvpMatches/{matchId}）から復元する。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface CardInput {
  cardId: string;
  attribute: string;
  attackPower: number;
  defensePower: number;
  speed: number;
}

// カード育成（特訓）のレベルボーナス。lib/models/user_card.dart の
// kCardLevelAttackBonus/kCardLevelDefenseBonus/kCardLevelSpeedBonus と同じ値。
const CARD_LEVEL_ATTACK_BONUS = 2;
const CARD_LEVEL_DEFENSE_BONUS = 2;
const CARD_LEVEL_SPEED_BONUS = 1;

// シードカード以外（cardIdがSEED_CARDSに無い場合）は、ownerUidが所有する
// マイカードとしてFirestoreから正本データを引く。他人のカードIDを騙って
// 使うことはできない（常に呼び出し元本人のコレクションだけを見る）。
// 見つからない場合はnullを返す（呼び出し側でレンタル中カードとしての解決を試みる）。
async function resolveCustomCard(ownerUid: string, cardId: string): Promise<CardInput | null> {
  const doc = await getFirestore()
    .collection("users").doc(ownerUid)
    .collection("cards").doc(cardId)
    .get();
  const data = doc.data();
  if (!doc.exists || !data) {
    return null;
  }
  const level: number = data.level ?? 0;
  return {
    cardId,
    attribute: data.attribute,
    attackPower: (data.attackPower ?? 0) + level * CARD_LEVEL_ATTACK_BONUS,
    defensePower: (data.defensePower ?? 0) + level * CARD_LEVEL_DEFENSE_BONUS,
    speed: (data.speed ?? 0) + level * CARD_LEVEL_SPEED_BONUS,
  };
}

// ownerUidが現在有効な（期限切れでない）レンタル契約を持つcardIdを、rentals/{id}に
// rentCard Cloud Functionが書き込んだステータススナップショットから解決する。
// 貸し手の元カードは直接読まない（貸し手が後で非公開化・削除しても、契約時点の
// 内容でレンタルが継続する — lib/providers/card_rental_provider.dart の
// myActiveRentalsProviderと同じ考え方）。見つからなければnullを返す。
async function resolveRentedCard(renterUid: string, cardId: string): Promise<CardInput | null> {
  const snapshot = await getFirestore()
    .collection("rentals")
    .where("renterUid", "==", renterUid)
    .where("cardId", "==", cardId)
    .where("rentalEnd", ">", Timestamp.now())
    .limit(1)
    .get();
  if (snapshot.empty) return null;
  const data = snapshot.docs[0].data();
  return {
    cardId,
    attribute: data.attribute,
    attackPower: data.attackPower ?? 0,
    defensePower: data.defensePower ?? 0,
    speed: data.speed ?? 0,
  };
}

// クライアントからのcardId列を、実数値に解決する。まずSEED_CARDS（サーバー側の
// 静的な正本データ）を見て、無ければ ownerUid が所有するカスタムカード、
// それにも無ければ ownerUid が現在有効なレンタル契約を持つカードとしてFirestoreを引く。
// いずれにも無いcardIdが1枚でもあれば拒否する。
// ownerUid未指定（相手デッキ側）はSEED_CARDSのみを信頼する
// —— pvpMatchが生成する相手デッキは常にシードカードのみで構成されるため。
async function resolveDeck(cardIds: string[], ownerUid?: string): Promise<CardInput[]> {
  return Promise.all(cardIds.map(async (cardId) => {
    const stats = SEED_CARDS[cardId];
    if (stats) return {cardId, ...stats};
    if (ownerUid) {
      const owned = await resolveCustomCard(ownerUid, cardId);
      if (owned) return owned;
      const rented = await resolveRentedCard(ownerUid, cardId);
      if (rented) return rented;
    }
    throw new HttpsError("invalid-argument", `未知のカードIDです: ${cardId}`);
  }));
}

// 週番号の算出（lib/providers/migration_provider.dart の _isoWeekNumber と同じ式）
function isoWeekNumber(date: Date): number {
  const start = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const dayOfYear = Math.floor((date.getTime() - start.getTime()) / 86400000) + 1;
  // JS Dateのgetday()は日曜=0だが、Dartのweekdayは月曜=1〜日曜=7。ここで揃える。
  const jsWeekday = date.getUTCDay();
  const dartWeekday = jsWeekday === 0 ? 7 : jsWeekday;
  return Math.floor((dayOfYear - dartWeekday + 10) / 7);
}

// 呼び出し元ユーザーが実際に購入済みの属性移住ボーナスを、Firestoreの記録から取得する。
// クライアントがmigratedAttributeを自己申告する形は廃止し、必ずサーバー側の記録を正とする。
async function resolveMigratedAttribute(userId: string): Promise<string | undefined> {
  const doc = await getFirestore()
    .collection("users").doc(userId)
    .collection("migration").doc("state")
    .get();
  const data = doc.data();
  if (!data || !data.attribute) return undefined;
  if (data.forWeek !== isoWeekNumber(new Date())) return undefined;
  return data.attribute as string;
}

interface BattleLogEntry {
  turn: number;
  attackerCardId: string;
  defenderCardId: string;
  damage: number;
  // このターンの後の、対戦全体を通した「攻め手側デッキ／受け手側デッキ」のHP
  // （現在の打ち手がどちらかに関わらず、常に元のattackerDeck/defenderDeckを指す。
  //  lib/services/battle_engine.dart の BattleLog.attackerHp/defenderHp と同じ意味）
  attackerHp: number;
  defenderHp: number;
  multiplier: number;
  isCritical: boolean;
  isDodged: boolean;
  isShielded: boolean;
}

// lib/models/user_card.dart の PlayCard.getCardType() と同じ判定式。
// カードの最も高いステータスでタイプを決める（同点で最大の場合はbalance）。
function getCardType(card: CardInput): string {
  const {attackPower, defensePower, speed} = card;
  const max = Math.max(attackPower, defensePower, speed);
  if (attackPower === max && attackPower > defensePower && attackPower > speed) return "attack";
  if (defensePower === max && defensePower > attackPower && defensePower > speed) return "defense";
  if (speed === max && speed > attackPower && speed > defensePower) return "speed";
  return "balance";
}

function getAttributeMultiplier(attackerAttribute: string, defenderAttribute: string): number {
  // 喜 → 怒 / 怒 → 哀 / 哀 → 喜 の三すくみ
  if (attackerAttribute === defenderAttribute) return 1.0;
  if (attackerAttribute === "joy" && defenderAttribute === "anger") return 1.5;
  if (attackerAttribute === "anger" && defenderAttribute === "sadness") return 1.5;
  if (attackerAttribute === "sadness" && defenderAttribute === "joy") return 1.5;
  return 0.67;
}

// 「属性の国」移住ボーナス：移住先属性のカードで攻撃した際に加算される倍率
// lib/services/battle_engine.dart の migrationBonus と同じ値
const MIGRATION_BONUS = 0.15;

function effectiveMultiplier(
  attackerAttribute: string,
  defenderAttribute: string,
  boosted: boolean
): number {
  const base = getAttributeMultiplier(attackerAttribute, defenderAttribute);
  return boosted ? base + MIGRATION_BONUS : base;
}

// クリティカルヒット：確率で追加ダメージ倍率が乗る（属性相性とは独立）。
// lib/services/battle_engine.dart の criticalChance/criticalMultiplier と同じ値。
// 乱数はサーバー側（Math.random）でのみ振り、クライアントには結果のみ返す。
const CRITICAL_CHANCE = 0.15;
const CRITICAL_MULTIPLIER = 1.5;

// カードタイプ特性。lib/services/battle_engine.dart の同名定数と同じ値。
const TYPE_CRITICAL_BONUS = 0.10; // attackタイプで攻撃時、クリティカル率に加算
const SHIELD_CHANCE = 0.20; // defenseタイプで防御時、シールド発動確率
const SHIELD_DAMAGE_REDUCTION = 0.5;
const DODGE_CHANCE = 0.15; // speedタイプで防御時、完全回避確率

interface AttackResolution {
  damage: number;
  isCritical: boolean;
  isDodged: boolean;
  isShielded: boolean;
}

// 1回の攻撃を解決する：防御側の回避→シールド判定 → 攻撃側のクリティカル判定 →
// 最終ダメージ算出、の順で処理する（lib/services/battle_engine.dart の
// _resolveAttack と同じ手順・同じ確率）。
function resolveAttack(attacker: CardInput, defender: CardInput, multiplier: number): AttackResolution {
  if (getCardType(defender) === "speed" && Math.random() < DODGE_CHANCE) {
    return {damage: 0, isCritical: false, isDodged: true, isShielded: false};
  }
  const isShielded = getCardType(defender) === "defense" && Math.random() < SHIELD_CHANCE;
  const critChance = getCardType(attacker) === "attack" ? CRITICAL_CHANCE + TYPE_CRITICAL_BONUS : CRITICAL_CHANCE;
  const isCritical = Math.random() < critChance;

  const raw = attacker.attackPower - defender.defensePower;
  let effectiveMultiplier = multiplier;
  if (isCritical) effectiveMultiplier *= CRITICAL_MULTIPLIER;
  if (isShielded) effectiveMultiplier *= SHIELD_DAMAGE_REDUCTION;
  const dmg = Math.floor(raw * effectiveMultiplier);
  return {damage: dmg < 1 ? 1 : dmg, isCritical, isDodged: false, isShielded};
}

function simulateBattle(
  attackerDeck: CardInput[],
  defenderDeck: CardInput[],
  migratedAttribute?: string
) {
  const initialHp = 30;
  let attackerHp = initialHp;
  let defenderHp = initialHp;
  const logs: BattleLogEntry[] = [];
  const len = Math.min(attackerDeck.length, defenderDeck.length);
  let turn = 1;

  for (let i = 0; i < len; i++) {
    const attCard = attackerDeck[i];
    const defCard = defenderDeck[i];
    const attackerGoesFirst = attCard.speed >= defCard.speed;
    // attackerDeck側（元の攻撃側プレイヤー）のカードが打つ攻撃だけが移住ボーナス対象
    const attCardBoosted = attCard.attribute === migratedAttribute;

    if (attackerGoesFirst) {
      const m1 = effectiveMultiplier(attCard.attribute, defCard.attribute, attCardBoosted);
      const r1 = resolveAttack(attCard, defCard, m1);
      defenderHp -= r1.damage;
      logs.push({
        turn: turn++, attackerCardId: attCard.cardId, defenderCardId: defCard.cardId,
        damage: r1.damage, attackerHp, defenderHp, multiplier: m1,
        isCritical: r1.isCritical, isDodged: r1.isDodged, isShielded: r1.isShielded,
      });
      if (defenderHp <= 0) break;

      const m2 = effectiveMultiplier(defCard.attribute, attCard.attribute, false);
      const r2 = resolveAttack(defCard, attCard, m2);
      attackerHp -= r2.damage;
      logs.push({
        turn: turn++, attackerCardId: defCard.cardId, defenderCardId: attCard.cardId,
        damage: r2.damage, attackerHp, defenderHp, multiplier: m2,
        isCritical: r2.isCritical, isDodged: r2.isDodged, isShielded: r2.isShielded,
      });
      if (attackerHp <= 0) break;
    } else {
      const m1 = effectiveMultiplier(defCard.attribute, attCard.attribute, false);
      const r1 = resolveAttack(defCard, attCard, m1);
      attackerHp -= r1.damage;
      logs.push({
        turn: turn++, attackerCardId: defCard.cardId, defenderCardId: attCard.cardId,
        damage: r1.damage, attackerHp, defenderHp, multiplier: m1,
        isCritical: r1.isCritical, isDodged: r1.isDodged, isShielded: r1.isShielded,
      });
      if (attackerHp <= 0) break;

      const m2 = effectiveMultiplier(attCard.attribute, defCard.attribute, attCardBoosted);
      const r2 = resolveAttack(attCard, defCard, m2);
      defenderHp -= r2.damage;
      logs.push({
        turn: turn++, attackerCardId: attCard.cardId, defenderCardId: defCard.cardId,
        damage: r2.damage, attackerHp, defenderHp, multiplier: m2,
        isCritical: r2.isCritical, isDodged: r2.isDodged, isShielded: r2.isShielded,
      });
      if (defenderHp <= 0) break;
    }
  }

  const attackerWon = attackerHp >= defenderHp;
  return {
    attackerWon,
    finalAttackerHp: Math.max(0, Math.min(initialHp, attackerHp)),
    finalDefenderHp: Math.max(0, Math.min(initialHp, defenderHp)),
    logs,
  };
}

interface PvpBattleRequest {
  matchId: string;
  attackerDeckCardIds: string[];
}

// pvpMatch記録の有効期限（この時間を過ぎたmatchIdは失効させ、古いマッチの使い回しを防ぐ）
const MATCH_TTL_MS = 10 * 60 * 1000;

// デッキ枚数。lib/screens/deck_selection_screen_v2.dartのmaxCards(デフォルト5)と同じ値。
const REQUIRED_DECK_SIZE = 5;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// シーズン進捗更新（レーティングと同じくサーバー権威で行う）
// lib/providers/game_state_provider.dart の myPlayerRankProvider と同じ方針で、
// クライアント側に「勝利/敗北をローカルで反映する」ような更新手段は意図的に置かない
// —— そちらもかつて更新経路が存在せずランク表示が永久固定されるバグだった。
// シーズン進捗（users/{uid}/seasonProgress/{seasonId}）もfirestore.rulesでクライアントからの
// 直接書き込みを禁止し、このCloud Functionのみが更新できるようにしている。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const SEASON_POINTS_PER_WIN = 20; // 100ポイントで1ランクなので5連勝で1ランクアップ
const SEASON_POINTS_PER_TIER = 100;

interface SeasonProgressResult {
  seasonId: string;
  pointsGained: number;
  rankedUp: boolean;
  newRank: number;
}

// アクティブシーズンが存在しない/取得に失敗した場合はnullを返し、呼び出し側で
// バトル結果自体には影響させずシーズン進捗更新だけを静かにスキップする。
async function updateSeasonProgress(
  userId: string,
  attackerWon: boolean
): Promise<SeasonProgressResult | null> {
  try {
    const now = Timestamp.now();
    const seasonSnap = await getFirestore()
      .collection("seasons")
      .where("startDate", "<=", now)
      .where("endDate", ">", now)
      .orderBy("startDate", "desc")
      .limit(1)
      .get();
    if (seasonSnap.empty) return null;

    const seasonDoc = seasonSnap.docs[0];
    const seasonId = seasonDoc.id;
    const maxRankTier: number = seasonDoc.data().maxRankTier ?? 10;
    const pointsGained = attackerWon ? SEASON_POINTS_PER_WIN : 0;

    const progressRef = getFirestore()
      .collection("users").doc(userId)
      .collection("seasonProgress").doc(seasonId);

    return await getFirestore().runTransaction(async (tx) => {
      const doc = await tx.get(progressRef);
      const before = doc.data() ?? {};
      const currentRank: number = before.currentRank ?? 1;
      const currentRankPoints: number = before.currentRankPoints ?? 0;
      const highestRank: number = before.highestRank ?? 1;
      const totalSeasonPoints: number = before.totalSeasonPoints ?? 0;
      const battlesWon: number = before.battlesWon ?? 0;
      const battlesPlayed: number = before.battlesPlayed ?? 0;

      let newRank = currentRank;
      let newRankPoints = currentRankPoints + pointsGained;
      while (newRankPoints >= SEASON_POINTS_PER_TIER && newRank < maxRankTier) {
        newRankPoints -= SEASON_POINTS_PER_TIER;
        newRank += 1;
      }
      // 最大ランクに達したら、それ以上はランクポイントを溜め込まない
      if (newRank >= maxRankTier) {
        newRank = maxRankTier;
        newRankPoints = Math.min(newRankPoints, SEASON_POINTS_PER_TIER - 1);
      }
      const newHighestRank = Math.max(highestRank, newRank);

      tx.set(progressRef, {
        seasonId,
        userId,
        currentRank: newRank,
        currentRankPoints: newRankPoints,
        totalSeasonPoints: totalSeasonPoints + pointsGained,
        battlesWon: battlesWon + (attackerWon ? 1 : 0),
        battlesPlayed: battlesPlayed + 1,
        highestRank: newHighestRank,
        unlockedRewards: before.unlockedRewards ?? [],
        joinedAt: before.joinedAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      return {
        seasonId,
        pointsGained,
        rankedUp: newRank > currentRank,
        newRank,
      };
    });
  } catch (e) {
    console.error(`Failed to update season progress for ${userId}:`, e);
    return null;
  }
}

export const pvpBattle = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }
    const userId = request.auth.uid;

    const data = request.data as PvpBattleRequest;
    const attackerDeckCardIds = data.attackerDeckCardIds ?? [];
    if (!data.matchId) {
      throw new HttpsError("invalid-argument", "デッキが不正です");
    }
    // デッキ枚数（lib/screens/deck_selection_screen_v2.dartのmaxCardsと同じ5枚固定）と
    // 重複カードを検証する。以前は「空でない」ことしか確認しておらず、UIを経由しない
    // 直接呼び出しで1枚だけの（相手の先頭カードに一方的に有利な）デッキを送る、
    // または同じ最強カードを5枚重ねるといった詐称が可能だった —
    // simulateBattleはMath.min(attackerDeck.length, defenderDeck.length)で短い方に
    // 合わせて対戦するため、1枚デッキは事実上その1回の有利な当たりだけで勝敗が決まってしまう。
    if (attackerDeckCardIds.length !== REQUIRED_DECK_SIZE) {
      throw new HttpsError("invalid-argument", "デッキは5枚である必要があります");
    }
    if (new Set(attackerDeckCardIds).size !== attackerDeckCardIds.length) {
      throw new HttpsError("invalid-argument", "デッキに同じカードを重複させることはできません");
    }

    // 対戦相手デッキはpvpMatchがサーバー側に保存した記録から復元する。
    // クライアントからの自己申告は一切受け付けない（不正な弱デッキ偽装を防ぐ）。
    // 同じmatchIdの二重使用（レーティング詐取のリプレイ）も防ぐため、
    // トランザクションで consumed フラグを検証・更新する。
    const matchRef = getFirestore().collection("pvpMatches").doc(data.matchId);
    const opponentDeckCardIds = await getFirestore().runTransaction(async (tx) => {
      const doc = await tx.get(matchRef);
      if (!doc.exists) {
        throw new HttpsError("not-found", "対戦相手の情報が見つかりません");
      }
      const match = doc.data()!;
      if (match.attackerUid !== userId) {
        throw new HttpsError("permission-denied", "このマッチは利用できません");
      }
      if (match.consumed) {
        throw new HttpsError("failed-precondition", "このマッチは既に使用済みです");
      }
      const createdAtMs: number = match.createdAt?.toMillis?.() ?? 0;
      if (createdAtMs === 0 || Date.now() - createdAtMs > MATCH_TTL_MS) {
        throw new HttpsError("failed-precondition", "マッチの有効期限が切れています");
      }
      tx.update(matchRef, {consumed: true, consumedAt: FieldValue.serverTimestamp()});
      return match.opponentDeckCardIds as string[];
    });

    const attackerDeck = await resolveDeck(attackerDeckCardIds, userId);
    const defenderDeckSnapshot = await resolveDeck(opponentDeckCardIds);
    const migratedAttribute = await resolveMigratedAttribute(userId);

    const result = simulateBattle(attackerDeck, defenderDeckSnapshot, migratedAttribute);

    // レーティング更新（簡易固定幅）。
    // 以前は勝利+15/敗北-10という非対称な幅だったため、五分の勝率でも
    // 対戦を重ねるほど平均レーティングが際限なく上昇し続けてしまっていた
    // （プレイヤーのランク表示がこれまでローカル固定でこの歪みが表面化して
    // いなかったが、実データを表示するようになった今は無視できない）。
    // 対称な幅にして、五分の勝率なら長期的にレーティングが均衡するようにする。
    // TODO: 相手レーティング差を考慮したELO式に拡張できる
    const ratingDelta = result.attackerWon ? 15 : -15;
    const ratingRef = getFirestore()
      .collection("users").doc(userId)
      .collection("rating").doc("current");

    const newRating = await getFirestore().runTransaction(async (tx) => {
      const doc = await tx.get(ratingRef);
      const before = doc.data() ?? {};
      const currentRating: number = before.rating ?? 1000;
      const wins: number = before.wins ?? 0;
      const losses: number = before.losses ?? 0;
      const updatedRating = Math.max(0, currentRating + ratingDelta);
      tx.set(ratingRef, {
        rating: updatedRating,
        wins: wins + (result.attackerWon ? 1 : 0),
        losses: losses + (result.attackerWon ? 0 : 1),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return updatedRating;
    });

    const season = await updateSeasonProgress(userId, result.attackerWon);

    return {...result, newRating, ratingDelta, season};
  });
