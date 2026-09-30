import {getFirestore} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 全期間/日次/週次/月次ランキング取得
// lib/providers/leaderboard_provider.dartは以前ダミーデータを返すだけだった。
// getSeasonLeaderboard(manageSeasons.ts)と同じ方針で、collectionGroupクエリを
// Cloud Function側（Admin SDK、セキュリティルールの対象外）で行う。
// 期間別(daily/weekly/monthly)はpvpBattle.tsのupdatePeriodLeaderboardStatsが
// バトル結果確定のたびにusers/{uid}/leaderboardStats/{periodKey}へ書き込む
// インクリメンタル集計を読み取るだけ。全期間はusers/{uid}/rating/currentを使う。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const LEADERBOARD_LIMIT = 100;

type PeriodType = "allTime" | "daily" | "weekly" | "monthly";

function currentPeriodKey(periodType: "daily" | "weekly" | "monthly"): string {
  const now = new Date();
  const jst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  if (periodType === "daily") {
    return `d:${jst.toISOString().slice(0, 10)}`;
  }
  if (periodType === "monthly") {
    return `m:${jst.getUTCFullYear()}-${String(jst.getUTCMonth() + 1).padStart(2, "0")}`;
  }
  // weekly（pvpBattle.tsのisoWeekNumberと同じ式）
  const start = new Date(Date.UTC(jst.getUTCFullYear(), 0, 1));
  const dayOfYear = Math.floor((jst.getTime() - start.getTime()) / 86400000) + 1;
  const jsWeekday = jst.getUTCDay();
  const dartWeekday = jsWeekday === 0 ? 7 : jsWeekday;
  const week = Math.floor((dayOfYear - dartWeekday + 10) / 7);
  return `w:${jst.getUTCFullYear()}-${week}`;
}

export const getPeriodLeaderboard = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }
    const {periodType} = request.data as {periodType: PeriodType};
    if (!periodType || !["allTime", "daily", "weekly", "monthly"].includes(periodType)) {
      throw new HttpsError("invalid-argument", "periodTypeが不正です");
    }

    try {
      if (periodType === "allTime") {
        const snapshot = await getFirestore()
          .collectionGroup("rating")
          .orderBy("rating", "desc")
          .limit(LEADERBOARD_LIMIT)
          .get();

        const leaderboard = snapshot.docs.map((doc: FirebaseFirestore.QueryDocumentSnapshot, i: number) => {
          const d = doc.data();
          // users/{uid}/rating/current のuidをドキュメントパスから取得
          const userId = doc.ref.parent.parent?.id ?? "";
          return {
            rank: i + 1,
            userId,
            userName: d.displayName ?? "Unknown",
            rating: d.rating ?? 1000,
            wins: d.wins ?? 0,
            losses: d.losses ?? 0,
          };
        });

        return {leaderboard};
      }

      const periodKey = currentPeriodKey(periodType);
      const snapshot = await getFirestore()
        .collectionGroup("leaderboardStats")
        .where("periodType", "==", periodType)
        .where("periodKey", "==", periodKey)
        .orderBy("points", "desc")
        .limit(LEADERBOARD_LIMIT)
        .get();

      const leaderboard = snapshot.docs.map((doc: FirebaseFirestore.QueryDocumentSnapshot, i: number) => {
        const d = doc.data();
        return {
          rank: i + 1,
          userId: d.userId ?? "",
          userName: d.displayName ?? "Unknown",
          rating: d.points ?? 0,
          wins: d.wins ?? 0,
          losses: d.losses ?? 0,
        };
      });

      return {leaderboard, periodKey};
    } catch (error) {
      console.error(`Failed to fetch ${periodType} leaderboard:`, error);
      throw new HttpsError("internal", "ランキングの取得に失敗しました");
    }
  }
);
