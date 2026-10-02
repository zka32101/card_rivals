import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 月替わりシーズンの自動作成
// seasonsコレクションにはこれまでシーズンを作る処理が無く、常に空だった
// （シーズン画面は「シーズンなし」、pvpBattleのシーズン進捗更新も常にスキップ）。
// 毎日JST 00:10に「今月」と「来月」のシーズン文書(season-YYYY-MM)が無ければ作成する。
// 来月分も先に作るのは、月替わりの瞬間にシーズンが空白になる時間を無くすため。
// 既存の文書は上書きしない（運営が手で調整したものを尊重する）。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;
const FIRST_SEASON = {year: 2026, month: 10}; // シーズン1 = 2026年10月
const MAX_RANK_TIER = 10;
const ATTRIBUTE_ROTATION = ["喜", "怒", "哀"];

// ランク到達報酬のテンプレート（rankTierに到達したらclaimSeasonRewardで受取可能）
const REWARD_TEMPLATE: {rankTier: number; coins: number; gems: number}[] = [
  {rankTier: 2, coins: 100, gems: 0},
  {rankTier: 4, coins: 200, gems: 1},
  {rankTier: 6, coins: 300, gems: 2},
  {rankTier: 8, coins: 500, gems: 3},
  {rankTier: 10, coins: 800, gems: 5},
];

function seasonTypeForMonth(month: number): string {
  if (month >= 3 && month <= 5) return "spring";
  if (month >= 6 && month <= 8) return "summer";
  if (month >= 9 && month <= 11) return "autumn";
  return "winter";
}

// JSTの(year, month)の月初0:00をUTCのDateで返す
function jstMonthStart(year: number, month: number): Date {
  return new Date(Date.UTC(year, month - 1, 1) - JST_OFFSET_MS);
}

function seasonNumber(year: number, month: number): number {
  return (year - FIRST_SEASON.year) * 12 + (month - FIRST_SEASON.month) + 1;
}

export async function ensureSeasonFor(year: number, month: number): Promise<boolean> {
  const number = seasonNumber(year, month);
  if (number < 1) return false;

  const db = getFirestore();
  const id = `season-${year}-${String(month).padStart(2, "0")}`;
  const ref = db.collection("seasons").doc(id);
  if ((await ref.get()).exists) return false;

  const nextYear = month === 12 ? year + 1 : year;
  const nextMonth = month === 12 ? 1 : month + 1;
  const now = Timestamp.now();

  const batch = db.batch();
  batch.set(ref, {
    number,
    type: seasonTypeForMonth(month),
    title: `${year}年${month}月シーズン`,
    description: "毎月開催のランクバトル。勝利してランクを上げ、ランク報酬を獲得しよう！",
    themeUrl: null,
    startDate: Timestamp.fromDate(jstMonthStart(year, month)),
    endDate: Timestamp.fromDate(jstMonthStart(nextYear, nextMonth)),
    // 現状、バトル計算には季節ボーナスを適用していないため倍率は等倍(1.0)にしている
    seasonBonus: {
      attribute: ATTRIBUTE_ROTATION[(number - 1) % ATTRIBUTE_ROTATION.length],
      damageMultiplier: 1.0,
      coinBonusMultiplier: 1.0,
      expBonusMultiplier: 1.0,
    },
    maxRankTier: MAX_RANK_TIER,
    createdAt: now,
    updatedAt: now,
  });
  for (const r of REWARD_TEMPLATE) {
    batch.set(ref.collection("rewards").doc(`rank-${r.rankTier}`), {
      seasonId: id,
      rankTier: r.rankTier,
      title: `ランク${r.rankTier}到達報酬`,
      description: `ランク${r.rankTier}に到達すると受け取れます`,
      coinsReward: r.coins,
      gemsReward: r.gems,
      badgeUrl: null,
      cardMaterialUrl: null,
      createdAt: now,
    });
  }
  await batch.commit();
  console.log(`Created season ${id}`);
  return true;
}

export const ensureSeasons = onSchedule(
  {
    schedule: "every day 00:10",
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
  },
  async () => {
    const jstNow = new Date(Date.now() + JST_OFFSET_MS);
    const year = jstNow.getUTCFullYear();
    const month = jstNow.getUTCMonth() + 1;
    await ensureSeasonFor(year, month);
    const nextYear = month === 12 ? year + 1 : year;
    const nextMonth = month === 12 ? 1 : month + 1;
    await ensureSeasonFor(nextYear, nextMonth);
  }
);
