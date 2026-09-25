import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import fetch from "node-fetch";
import {generateImageWithFallback} from "./imageProviders";

const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 感情別スタイル定義
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const EMOTION_PROMPTS: Record<string, string> = {
  joy: "A radiant, joyful character surrounded by warm golden light, sunlight, and glowing happiness. Fantasy art style, beautiful luminous colors, hopeful and uplifting atmosphere.",
  anger: "A powerful, intense character with fiery energy and red/crimson flames surrounding them. Dynamic aggressive pose, volcanic landscape, dramatic intense lighting.",
  sadness: "A gentle, melancholic character in soft blue tones, under moonlight or gentle rain. Ethereal atmosphere, peaceful but contemplative. Night sky, flowing water, calm serene mood.",
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Haiku を使ってカード名を生成
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
export const generateDailyEmotionCardName = onCall(
  {region: "asia-northeast1", secrets: ["ANTHROPIC_API_KEY"]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { emotion, userMessage } = request.data;
    if (!emotion || !userMessage) {
      throw new HttpsError("invalid-argument", "Missing emotion or message");
    }

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY ?? "",
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-3-5-haiku-20241022",
          max_tokens: 200,
          messages: [
            {
              role: "user",
              content: `感情の国の${emotion}属性カードです。ユーザーが「${userMessage}」という気持ちで今日を過ごしました。この気持ちを表すカード名を3つ提案してください。各名前は5-10字で、かわいい/かっこいい/優雅な雰囲気で。

形式:
1. [名前1]
2. [名前2]
3. [名前3]`,
            },
          ],
        }),
      });

      if (!response.ok) {
        throw new Error(`Anthropic API error: ${response.statusText}`);
      }

      const result = await response.json() as any;
      const content = result.content[0].text;
      const names = content
        .split("\n")
        .filter((line: string) => line.trim())
        .map((line: string) => line.replace(/^\d+\.\s*/, "").trim());

      return {
        names: names.slice(0, 3),
        selectedName: names[0] || "感情のカード",
      };
    } catch (error) {
      console.error("Error generating emotion card name:", error);
      throw new HttpsError("internal", "Failed to generate card name");
    }
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 今日のきもちカード画像生成
// Replicate(Flux Schnell)を優先、失敗時はLeonardo(Phoenix 1.0)へ自動フォールバック
// （generateCardImage.tsと同じimageProviders.tsを共有）。
// 生成した画像はサーバー側でFirebase Storageにアップロードし、公開URLを返す
// （旧実装はReplicateのprediction IDを返すだけでクライアント側ポーリングが未実装だった）。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
export const generateDailyEmotionCardImage = onCall(
  {region: "asia-northeast1", timeoutSeconds: 120, memory: "256MiB", secrets: ["LEONARDO_API_KEY"]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { emotion, userMessage, cardName } = request.data;
    if (!emotion) {
      throw new HttpsError("invalid-argument", "Missing emotion");
    }

    const basePrompt = EMOTION_PROMPTS[emotion] || EMOTION_PROMPTS.joy;
    const fullPrompt = `${basePrompt} Card name: "${cardName || emotion}". User feeling: "${userMessage}". High quality card art, elegant design, no text no watermark no border.`;
    const negativePrompt = "text, words, letters, watermark, signature, card frame, border, ugly, blurry, low quality, deformed";

    let imageBuffer: Buffer;
    let providerUsed: "replicate" | "leonardo";
    try {
      const generated = await generateImageWithFallback(fullPrompt, negativePrompt);
      imageBuffer = generated.buffer;
      providerUsed = generated.provider;
    } catch (error) {
      console.error("Error generating emotion card image:", error);
      throw new HttpsError("internal", "Failed to generate card image");
    }

    const bucket = getStorage().bucket();
    const userId = request.auth.uid;
    const filename = `daily_emotion_cards/${userId}/${Date.now()}.png`;
    const file = bucket.file(filename);

    await file.save(imageBuffer, {contentType: "image/png"});
    await file.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;
    return {imageUrl: publicUrl, provider: providerUsed};
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 感情カード作成（Cloud Firestore トリガー）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
export const onDailyEmotionCardCreated = onDocumentCreated(
  {document: "users/{userId}/daily_emotions/{cardId}", region: "asia-northeast1"},
  async (event) => {
    const { userId } = event.params;
    const cardData = event.data!.data();

    try {
      // 統計情報を更新
      const statsRef = getFirestore().collection("users").doc(userId).collection("daily_emotion_stats").doc("stats");
      const statsDoc = await statsRef.get();

      const currentStats = statsDoc.data() ?? {
        totalDays: 0,
        currentStreak: 1,
        joyDays: 0,
        angerDays: 0,
        sadnessDays: 0,
        lastEmotionDate: Timestamp.now(),
      };

      // 感情タイプでカウント
      const emotionKey = `${cardData.emotion}Days`;
      const updateData = {
        totalDays: (currentStats.totalDays || 0) + 1,
        [emotionKey]: (currentStats[emotionKey as keyof typeof currentStats] || 0) + 1,
        lastEmotionDate: Timestamp.now(),
      };

      // ストリーク更新（昨日カードがあるかチェック）
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const startOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate());
      const endOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 23, 59, 59);

      const yesterdayCards = await getFirestore()
        .collection("users")
        .doc(userId)
        .collection("daily_emotions")
        .where("createdAt", ">=", Timestamp.fromDate(startOfYesterday))
        .where("createdAt", "<=", Timestamp.fromDate(endOfYesterday))
        .limit(1)
        .get();

      if (yesterdayCards.docs.length > 0) {
        updateData.currentStreak = (currentStats.currentStreak || 0) + 1;
      } else {
        updateData.currentStreak = 1;
      }

      await statsRef.set(updateData, { merge: true });

      console.log(`Updated emotion stats for user ${userId}`);
    } catch (error) {
      console.error("Error updating emotion stats:", error);
    }
  });
