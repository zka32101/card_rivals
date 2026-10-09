import {onCall, HttpsError} from "firebase-functions/v2/https";
import fetch from "node-fetch";
import {parseNameCandidates} from "./parseNames";

const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;

interface GenerateCardNameRequest {
  attribute: string;
  cost: number;
  attack: number;
  defense: number;
  speed: number;
  tone: string;
  language?: string; // "ja"(既定) | "en"
}

const ATTR_LABEL: Record<string, string> = {joy: "喜", anger: "怒", sadness: "哀"};
const ATTR_LABEL_EN: Record<string, string> = {joy: "Joy", anger: "Anger", sadness: "Sadness"};
const TONE_LABEL_EN: Record<string, string> = {
  cute: "cute",
  cool: "cool",
  dark: "dark and ominous",
  elegant: "elegant",
  normal: "well-balanced",
};
const TONE_LABEL: Record<string, string> = {
  cute: "かわいい",
  cool: "かっこいい",
  dark: "ダーク・不穏な",
  elegant: "優雅な",
  normal: "バランスの良い",
};

export const generateCardName = onCall(
  {region: "asia-northeast1", secrets: ["ANTHROPIC_API_KEY"]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }

    const data = request.data as GenerateCardNameRequest;
    const attribute = data.attribute ?? "joy";
    const cost = data.cost ?? 1;
    const attack = data.attack ?? 0;
    const defense = data.defense ?? 0;
    const speed = data.speed ?? 0;
    const tone = data.tone ?? "normal";

    const attrLabel = ATTR_LABEL[attribute] ?? "喜";
    const toneLabel = TONE_LABEL[tone] ?? TONE_LABEL.normal;

    const isEn = data.language === "en";
    const promptEn = `Come up with card names for "Card Rivals", a card game set in a land of emotions.
Attribute: ${ATTR_LABEL_EN[attribute] ?? "Joy"} (${attribute})
Cost: ${cost} / Attack: ${attack} / Defense: ${defense} / Speed: ${speed}
Tone: ${TONE_LABEL_EN[tone] ?? TONE_LABEL_EN.normal}

Suggest 3 card names that fit these stats and the tone. Each name must be in English, 2 to 4 words.
Do not use Japanese characters.

Format:
1. Name 1
2. Name 2
3. Name 3`;

    const promptJa = `感情の国のカードゲーム「Card Rivals」用のカード名を考えてください。
属性: ${attrLabel}（${attribute}）
コスト: ${cost} / 攻撃力: ${attack} / 防御力: ${defense} / 素早さ: ${speed}
トーン: ${toneLabel}

上記のステータスと雰囲気に合うカード名を3つ提案してください。各名前は2〜10字程度の日本語で。

形式:
1. 名前1
2. 名前2
3. 名前3`;
    const prompt = isEn ? promptEn : promptJa;

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY ?? "",
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-haiku-4-5-20251001",
          max_tokens: 200,
          messages: [{role: "user", content: prompt}],
        }),
      });

      if (!response.ok) {
        throw new Error(`Anthropic API error: ${response.statusText}`);
      }

      const result = (await response.json()) as {content: {text: string}[]};
      const content = result.content[0].text;
      const names = parseNameCandidates(content);

      return {names};
    } catch (error) {
      console.error("Error generating card name:", error);
      throw new HttpsError("internal", "カード名の生成に失敗しました");
    }
  }
);
