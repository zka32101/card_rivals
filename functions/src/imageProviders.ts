import * as functions from "firebase-functions/v1";
import fetch from "node-fetch";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 画像生成プロバイダ共通モジュール
// 2段構成: Replicate(Flux Schnell)を優先、失敗時にLeonardo(Phoenix 1.0)へフォールバックする。
// generateCardImage.ts / dailyEmotionCard.ts など複数の関数から共有利用する。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const REPLICATE_API_TOKEN = process.env.REPLICATE_API_TOKEN;
const REPLICATE_FLUX_VERSION = "5f24084160c9089501c1b3545d9be3c27883ae2239b6f412990e82d4a6210f8f";

const LEONARDO_API_KEY = process.env.LEONARDO_API_KEY;
// Leonardo Phoenix 1.0（docs.leonardo.ai/docs/phoenix で確認済みの公式モデルID）
const LEONARDO_MODEL_ID = process.env.LEONARDO_MODEL_ID ?? "de7d3faf-762f-48e0-b3b7-9d0ac3a3fcf3";
const LEONARDO_API_BASE = "https://cloud.leonardo.ai/api/rest/v1";

// このモジュールを使う関数の runWith({secrets: [...]}) に渡す共通シークレット一覧
export const IMAGE_PROVIDER_SECRETS = ["REPLICATE_API_TOKEN", "LEONARDO_API_KEY"];

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1段目: Replicate（コスト最小・Apache 2.0ライセンスのFlux Schnell）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
async function generateImageViaReplicate(prompt: string, negativePrompt: string): Promise<Buffer> {
  if (!REPLICATE_API_TOKEN) {
    throw new Error("REPLICATE_API_TOKEN が未設定です");
  }

  const createRes = await fetch("https://api.replicate.com/v1/predictions", {
    method: "POST",
    headers: {
      Authorization: `Token ${REPLICATE_API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      version: REPLICATE_FLUX_VERSION,
      input: {
        prompt,
        negative_prompt: negativePrompt,
        width: 512,
        height: 512,
        num_outputs: 1,
        num_inference_steps: 4,
      },
    }),
  });

  if (!createRes.ok) {
    throw new Error(`Replicate API error (create): ${createRes.status} ${await createRes.text()}`);
  }

  let result = (await createRes.json()) as {id: string; status: string; output?: string[]};
  let attempts = 0;
  while (result.status !== "succeeded" && result.status !== "failed" && attempts < 15) {
    await new Promise((r) => setTimeout(r, 2000));
    const poll = await fetch(`https://api.replicate.com/v1/predictions/${result.id}`, {
      headers: {Authorization: `Token ${REPLICATE_API_TOKEN}`},
    });
    result = (await poll.json()) as typeof result;
    attempts++;
  }

  if (result.status !== "succeeded" || !result.output?.[0]) {
    throw new Error(`Replicate生成失敗: ${JSON.stringify(result)}`);
  }

  const imageResponse = await fetch(result.output[0]);
  return imageResponse.buffer();
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2段目: Leonardo（Replicate失敗時のフォールバック）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
async function generateImageViaLeonardo(prompt: string, negativePrompt: string): Promise<Buffer> {
  if (!LEONARDO_API_KEY) {
    throw new Error("LEONARDO_API_KEY が未設定です");
  }

  const createRes = await fetch(`${LEONARDO_API_BASE}/generations`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${LEONARDO_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      prompt,
      negative_prompt: negativePrompt,
      modelId: LEONARDO_MODEL_ID,
      width: 512,
      height: 512,
      num_images: 1,
      alchemy: false, // 高品質モード（コスト数倍）はオフ
      photoReal: false, // Phoenixは非対応のため常にfalse
    }),
  });

  if (!createRes.ok) {
    throw new Error(`Leonardo API error (create): ${createRes.status} ${await createRes.text()}`);
  }

  const created = (await createRes.json()) as {sdGenerationJob?: {generationId?: string}};
  const genId = created.sdGenerationJob?.generationId;
  if (!genId) {
    throw new Error(`generationId が取得できませんでした: ${JSON.stringify(created)}`);
  }

  let imageUrl: string | undefined;
  let attempts = 0;
  while (attempts < 15) {
    await new Promise((r) => setTimeout(r, 2000));
    const poll = await fetch(`${LEONARDO_API_BASE}/generations/${genId}`, {
      headers: {Authorization: `Bearer ${LEONARDO_API_KEY}`},
    });
    if (!poll.ok) {
      throw new Error(`Leonardo API error (poll): ${poll.status} ${await poll.text()}`);
    }
    const data = (await poll.json()) as {
      generations_by_pk?: {status?: string; generated_images?: {url: string}[]};
    };
    const gen = data.generations_by_pk;
    if (gen?.status === "COMPLETE") {
      imageUrl = gen.generated_images?.[0]?.url;
      break;
    }
    if (gen?.status === "FAILED") {
      throw new Error(`Leonardo generation failed: ${JSON.stringify(gen)}`);
    }
    attempts++;
  }

  if (!imageUrl) {
    throw new Error("Leonardo画像生成がタイムアウトしました");
  }

  const imageResponse = await fetch(imageUrl);
  return imageResponse.buffer();
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2段構成の呼び出し口。Replicateを優先し、失敗時はLeonardoへ自動フォールバックする。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
export async function generateImageWithFallback(
  prompt: string,
  negativePrompt: string
): Promise<{buffer: Buffer; provider: "replicate" | "leonardo"}> {
  try {
    const buffer = await generateImageViaReplicate(prompt, negativePrompt);
    return {buffer, provider: "replicate"};
  } catch (replicateError) {
    functions.logger.warn("Replicate生成に失敗、Leonardoにフォールバックします", replicateError);
    try {
      const buffer = await generateImageViaLeonardo(prompt, negativePrompt);
      return {buffer, provider: "leonardo"};
    } catch (leonardoError) {
      functions.logger.error("Leonardoフォールバックも失敗", leonardoError);
      throw new Error("画像生成に失敗しました（Replicate/Leonardo両方失敗）");
    }
  }
}
