import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// シーズンリワード請求（サーバー権威）
// users/{uid}/seasonProgress/{seasonId} はpvpBattle Cloud Functionのみが更新でき、
// firestore.rulesでクライアントからの直接書き込みを禁止している。そのため
// unlockedRewardsへの追加や、リワードのジェム/コイン付与も必ずこのCloud Function
// 経由で行う（rentCard.ts/pvpBattle.tsと同じ「通貨が絡む更新はサーバーのみ」方針）。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface ClaimSeasonRewardRequest {
  seasonId: string;
  rewardId: string;
}

// ウォレット未作成（初回アクセス前）の場合のデフォルト残高。
// lib/providers/game_state_provider.dart の WalletState() のデフォルトと同じ値。
const DEFAULT_COIN_BALANCE = 100;
const DEFAULT_GEM_BALANCE = 0;

export const claimSeasonReward = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }
    const userId = request.auth.uid;
    const {seasonId, rewardId} = request.data as ClaimSeasonRewardRequest;

    if (!seasonId || !rewardId) {
      throw new HttpsError("invalid-argument", "リクエストが不正です");
    }

    const db = getFirestore();
    const rewardRef = db.collection("seasons").doc(seasonId).collection("rewards").doc(rewardId);
    const progressRef = db.collection("users").doc(userId).collection("seasonProgress").doc(seasonId);
    const walletRef = db.collection("users").doc(userId).collection("wallet").doc("balance");

    try {
      return await db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
        // ── 読み取りは書き込みより先に行う（Firestoreトランザクションの制約） ──
        const rewardDoc = await tx.get(rewardRef);
        if (!rewardDoc.exists) {
          throw new HttpsError("not-found", "リワードが見つかりません");
        }
        const reward = rewardDoc.data()!;
        const rankTier: number = reward.rankTier ?? 1;
        const gemsReward: number = reward.gemsReward ?? 0;
        const coinsReward: number = reward.coinsReward ?? 0;

        const progressDoc = await tx.get(progressRef);
        if (!progressDoc.exists) {
          throw new HttpsError("failed-precondition", "シーズン進捗が見つかりません");
        }
        const progress = progressDoc.data()!;
        const currentRank: number = progress.currentRank ?? 1;
        const unlockedRewards: string[] = progress.unlockedRewards ?? [];

        // season_screen.dart の isUnlocked 判定（currentRank基準）と揃える
        if (currentRank < rankTier) {
          throw new HttpsError(
            "failed-precondition",
            "このリワードを受け取るにはランクが足りません"
          );
        }
        if (unlockedRewards.includes(rewardId)) {
          throw new HttpsError("failed-precondition", "このリワードは既に受け取り済みです");
        }

        const walletDoc = await tx.get(walletRef);
        const walletData = walletDoc.data() ?? {};
        const coinBalance: number = walletData.coinBalance ?? DEFAULT_COIN_BALANCE;
        const gemBalance: number = walletData.gemBalance ?? DEFAULT_GEM_BALANCE;

        // ── ここから書き込み ──
        tx.set(progressRef, {
          unlockedRewards: [...unlockedRewards, rewardId],
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        tx.set(walletRef, {
          coinBalance: coinBalance + coinsReward,
          gemBalance: gemBalance + gemsReward,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        return {success: true, gemsGranted: gemsReward, coinsGranted: coinsReward};
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error(`Failed to claim season reward for ${userId}:`, error);
      throw new HttpsError("internal", "リワード受取に失敗しました");
    }
  }
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// シーズンランキング取得
// 旧lib/providers/season_provider.dartのseasonLeaderboardProviderは、
// FirebaseFirestore.instance.collection('users').get()で全ユーザードキュメントを
// クライアントから直接横断取得しようとしていたが、firestore.rulesのusers/{userId}は
// 本人uidのみ読み取り可であり、この呼び出しは常にpermission-deniedで失敗していた
// （try/catchで握りつぶされ「ランキングデータがありません」と表示されるだけだった）。
// Admin SDKはセキュリティルールの対象外なので、この集計はCloud Function側で行う。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const LEADERBOARD_LIMIT = 100;

export const getSeasonLeaderboard = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }
    const {seasonId} = request.data as {seasonId: string};
    if (!seasonId) {
      throw new HttpsError("invalid-argument", "seasonIdが必要です");
    }

    try {
      // users/{uid}/seasonProgress/{seasonId} を横断するcollectionGroupクエリ。
      // 旧実装（全users取得→各ユーザーのサブコレクションを1件ずつ取得）と異なり、
      // 1回のクエリで完結する。ソート順は旧実装のローカルソートと同じ
      // （ランク→ランク内ポイント→シーズン総ポイントの降順）。
      const snapshot = await getFirestore()
        .collectionGroup("seasonProgress")
        .where("seasonId", "==", seasonId)
        .orderBy("currentRank", "desc")
        .orderBy("currentRankPoints", "desc")
        .orderBy("totalSeasonPoints", "desc")
        .limit(LEADERBOARD_LIMIT)
        .get();

      const leaderboard = snapshot.docs.map((doc: FirebaseFirestore.QueryDocumentSnapshot) => {
        const d = doc.data();
        return {
          userId: d.userId ?? "",
          currentRank: d.currentRank ?? 1,
          currentRankPoints: d.currentRankPoints ?? 0,
          totalSeasonPoints: d.totalSeasonPoints ?? 0,
          battlesWon: d.battlesWon ?? 0,
          battlesPlayed: d.battlesPlayed ?? 0,
          highestRank: d.highestRank ?? 1,
        };
      });

      return {leaderboard};
    } catch (error) {
      console.error(`Failed to fetch season leaderboard for season ${seasonId}:`, error);
      throw new HttpsError("internal", "ランキングの取得に失敗しました");
    }
  }
);
