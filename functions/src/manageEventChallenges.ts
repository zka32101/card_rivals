import * as functions from "firebase-functions/v1";
import {getFirestore, Timestamp, Transaction, QueryDocumentSnapshot} from "firebase-admin/firestore";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// イベント・チャレンジ管理（サーバー権威）
// ユーザーのチャレンジ進捗を追跡し、リワードを配布する。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface ProgressChallengeRequest {
  eventId: string;
  challengeId: string;
  progressAmount: number; // 進捗量（例：勝利数、ダメージ量）
}

interface ClaimRewardRequest {
  eventId: string;
  challengeId: string;
}

interface UserChallengeProgress {
  eventId: string;
  challengeId: string;
  progress: number;
  completed: boolean;
  completedAt?: Timestamp;
  rewardClaimed: boolean;
  claimedAt?: Timestamp;
  updatedAt: Timestamp;
}

// チャレンジの進捗を更新
export const progressChallenge = functions
  .region("asia-northeast1")
  .runWith({timeoutSeconds: 30})
  .https.onCall(async (data: ProgressChallengeRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }

    const userId = context.auth.uid;
    const {eventId, challengeId, progressAmount} = data;

    // バリデーション
    if (!eventId || !challengeId) {
      throw new functions.https.HttpsError("invalid-argument", "イベントIDとチャレンジIDが必要です");
    }

    if (progressAmount < 0) {
      throw new functions.https.HttpsError("invalid-argument", "進捗量は0以上である必要があります");
    }

    const db = getFirestore();
    const progressRef = db
      .collection("users")
      .doc(userId)
      .collection("eventProgress")
      .doc(`${eventId}_${challengeId}`);

    try {
      // チャレンジの定義を取得
      const challengeSnapshot = await db
        .collection("events")
        .doc(eventId)
        .collection("challenges")
        .doc(challengeId)
        .get();

      if (!challengeSnapshot.exists) {
        throw new functions.https.HttpsError("not-found", "チャレンジが見つかりません");
      }

      const challengeData = challengeSnapshot.data() as any;
      const target = challengeData.target || 1;

      // トランザクション内で進捗を更新
      await db.runTransaction(async (transaction: Transaction) => {
        const currentProgress = await transaction.get(progressRef);
        const now = Timestamp.now();

        if (!currentProgress.exists) {
          // 新規進捗を作成
          const newProgress: UserChallengeProgress = {
            eventId,
            challengeId,
            progress: Math.min(progressAmount, target),
            completed: progressAmount >= target,
            completedAt: progressAmount >= target ? now : undefined,
            rewardClaimed: false,
            updatedAt: now,
          };

          transaction.set(progressRef, newProgress);
        } else {
          // 既存の進捗を更新
          const existing = currentProgress.data() as UserChallengeProgress;
          const newProgress = existing.progress + progressAmount;
          const isCompleted = newProgress >= target && !existing.completed;

          transaction.update(progressRef, {
            progress: Math.min(newProgress, target),
            ...(isCompleted && {completed: true, completedAt: now}),
            updatedAt: now,
          });
        }
      });

      return {success: true};
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      console.error(`Failed to progress challenge for ${userId}:`, error);
      throw new functions.https.HttpsError("internal", "チャレンジの進捗更新に失敗しました");
    }
  });

// チャレンジのリワードを受け取る
export const claimChallengeReward = functions
  .region("asia-northeast1")
  .runWith({timeoutSeconds: 30})
  .https.onCall(async (data: ClaimRewardRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }

    const userId = context.auth.uid;
    const {eventId, challengeId} = data;

    if (!eventId || !challengeId) {
      throw new functions.https.HttpsError("invalid-argument", "イベントIDとチャレンジIDが必要です");
    }

    const db = getFirestore();

    try {
      return await db.runTransaction(async (transaction: Transaction) => {
        // ユーザーの進捗を確認
        const progressRef = db
          .collection("users")
          .doc(userId)
          .collection("eventProgress")
          .doc(`${eventId}_${challengeId}`);
        const progressSnapshot = await transaction.get(progressRef);

        if (!progressSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "チャレンジの進捗が見つかりません");
        }

        const progress = progressSnapshot.data() as UserChallengeProgress;

        // チャレンジが完了していることを確認
        if (!progress.completed) {
          throw new functions.https.HttpsError("failed-precondition", "チャレンジはまだ完了していません");
        }

        // リワードがすでに受け取られていることを確認
        if (progress.rewardClaimed) {
          throw new functions.https.HttpsError("failed-precondition", "リワードはすでに受け取られています");
        }

        // チャレンジの定義を取得してリワードを得る
        const challengeSnapshot = await transaction.get(
          db
            .collection("events")
            .doc(eventId)
            .collection("challenges")
            .doc(challengeId)
        );

        if (!challengeSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "チャレンジが見つかりません");
        }

        const challengeData = challengeSnapshot.data() as any;
        const gemReward = challengeData.gemReward || 0;
        const coinReward = challengeData.coinReward || 0;

        // ユーザーのウォレットを更新
        const walletRef = db.collection("users").doc(userId).collection("wallet").doc("overall");
        const now = Timestamp.now();

        const walletSnapshot = await transaction.get(walletRef);
        if (walletSnapshot.exists) {
          const wallet = walletSnapshot.data() as any;
          transaction.update(walletRef, {
            gems: (wallet.gems || 0) + gemReward,
            coins: (wallet.coins || 0) + coinReward,
            updatedAt: now,
          });
        } else {
          transaction.set(walletRef, {
            gems: gemReward,
            coins: coinReward,
            updatedAt: now,
          });
        }

        // 進捗をリワード受取状態に更新
        transaction.update(progressRef, {
          rewardClaimed: true,
          claimedAt: now,
        });

        return {
          success: true,
          gemReward,
          coinReward,
        };
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      console.error(`Failed to claim challenge reward for ${userId}:`, error);
      throw new functions.https.HttpsError("internal", "リワード受取に失敗しました");
    }
  });

// ユーザーのイベント進捗をまとめて取得
export const getUserEventProgress = functions
  .region("asia-northeast1")
  .runWith({timeoutSeconds: 30})
  .https.onCall(async (data: {eventId: string}, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }

    const userId = context.auth.uid;
    const {eventId} = data;

    if (!eventId) {
      throw new functions.https.HttpsError("invalid-argument", "イベントIDが必要です");
    }

    const db = getFirestore();

    try {
      const progressSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("eventProgress")
        .where("eventId", "==", eventId)
        .get();

      const progresses = progressSnapshot.docs.map((doc: QueryDocumentSnapshot) => doc.data() as UserChallengeProgress);

      return {
        success: true,
        progresses,
      };
    } catch (error) {
      console.error(`Failed to fetch event progress for ${userId}:`, error);
      throw new functions.https.HttpsError("internal", "進捗取得に失敗しました");
    }
  });
