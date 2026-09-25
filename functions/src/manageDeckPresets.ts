import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// デッキプリセット管理（サーバー権威）
// ユーザーのデッキ構成を保存・更新・削除する。
// 複数のプリセットを管理でき、デッキビルダーで素早く切り替え可能。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const MAX_PRESETS_PER_USER = 10;
const MAX_CARDS_PER_DECK = 30;

interface DeckPresetData {
  name: string;
  description?: string;
  cardIds: string[]; // レンタルカード含む
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}

interface SaveDeckPresetRequest {
  presetName: string;
  description?: string;
  cardIds: string[];
}

interface DeleteDeckPresetRequest {
  presetId: string;
}

// デッキプリセットを保存
export const saveDeckPreset = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }

    const userId = request.auth.uid;
    const {presetName, description, cardIds} = request.data as SaveDeckPresetRequest;

    // バリデーション
    if (!presetName || !Array.isArray(cardIds)) {
      throw new HttpsError("invalid-argument", "リクエストが不正です");
    }

    if (presetName.length > 50) {
      throw new HttpsError("invalid-argument", "プリセット名は50文字以内です");
    }

    if (cardIds.length === 0 || cardIds.length > MAX_CARDS_PER_DECK) {
      throw new HttpsError(
        "invalid-argument",
        `デッキには1〜${MAX_CARDS_PER_DECK}枚のカードが必要です`
      );
    }

    const db = getFirestore();
    const presetsRef = db.collection("users").doc(userId).collection("deckPresets");
    const now = Timestamp.now();

    try {
      // 既存プリセット数をチェック
      const existingSnap = await presetsRef.count().get();
      if (existingSnap.data().count >= MAX_PRESETS_PER_USER) {
        throw new HttpsError(
          "resource-exhausted",
          `デッキプリセットは最大${MAX_PRESETS_PER_USER}個までです`
        );
      }

      // 新しいプリセットを作成
      const presetId = presetsRef.doc().id;
      const presetData: DeckPresetData = {
        name: presetName,
        description: description || "",
        cardIds,
        createdAt: now,
        updatedAt: now,
      };

      await presetsRef.doc(presetId).set(presetData);

      return {
        success: true,
        presetId,
        preset: presetData,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error(`Failed to save deck preset for ${userId}:`, error);
      throw new HttpsError("internal", "デッキプリセットの保存に失敗しました");
    }
  });

// デッキプリセットを削除
export const deleteDeckPreset = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }

    const userId = request.auth.uid;
    const {presetId} = request.data as DeleteDeckPresetRequest;

    if (!presetId) {
      throw new HttpsError("invalid-argument", "プリセットIDが必要です");
    }

    const db = getFirestore();
    const presetRef = db.collection("users").doc(userId).collection("deckPresets").doc(presetId);

    try {
      // 存在確認
      const snap = await presetRef.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "プリセットが見つかりません");
      }

      // 削除
      await presetRef.delete();

      return {success: true};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error(`Failed to delete deck preset for ${userId}:`, error);
      throw new HttpsError("internal", "プリセットの削除に失敗しました");
    }
  });

// デッキプリセットをコピー
export const copyDeckPreset = onCall(
  {region: "asia-northeast1", timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }

    const userId = request.auth.uid;
    const {sourcePresetId, newName} = request.data as {sourcePresetId: string; newName: string};

    if (!sourcePresetId || !newName) {
      throw new HttpsError("invalid-argument", "リクエストが不正です");
    }

    const db = getFirestore();
    const sourceRef = db.collection("users").doc(userId).collection("deckPresets").doc(sourcePresetId);
    const presetsRef = db.collection("users").doc(userId).collection("deckPresets");

    try {
      const sourceSnap = await sourceRef.get();
      if (!sourceSnap.exists) {
        throw new HttpsError("not-found", "ソースプリセットが見つかりません");
      }

      const sourceData = sourceSnap.data() as DeckPresetData;
      const now = Timestamp.now();

      const newPresetId = presetsRef.doc().id;
      const newPreset: DeckPresetData = {
        ...sourceData,
        name: newName,
        createdAt: now,
        updatedAt: now,
      };

      await presetsRef.doc(newPresetId).set(newPreset);

      return {
        success: true,
        presetId: newPresetId,
        preset: newPreset,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error(`Failed to copy deck preset for ${userId}:`, error);
      throw new HttpsError("internal", "プリセットのコピーに失敗しました");
    }
  });
