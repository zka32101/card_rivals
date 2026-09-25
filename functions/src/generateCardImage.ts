import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {generateImageWithFallback} from "./imageProviders";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// レート制限（画像生成APIの異常課金防止）
// コインさえあれば無制限に連打できてしまうため、ユーザー単位で
// 1日あたりの生成回数に上限を設ける。日本向けアプリのためJST基準で日付をリセットする。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const DAILY_CARD_GENERATION_LIMIT = 50;

function todayJST(): string {
  const jst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return jst.toISOString().slice(0, 10); // YYYY-MM-DD
}

// 上限チェック＆カウントアップをトランザクションで原子的に行う。
// 上限超過時はHttpsErrorを投げて画像生成APIを呼ばせない。
async function checkAndIncrementDailyGenerationCount(userId: string): Promise<void> {
  const today = todayJST();
  const ref = admin.firestore().collection("cardGenerationLimits").doc(userId);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const count = data?.date === today ? (data.count as number ?? 0) : 0;

    if (count >= DAILY_CARD_GENERATION_LIMIT) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        `1日のカード生成回数の上限（${DAILY_CARD_GENERATION_LIMIT}回）に達しました。日付が変わってから再度お試しください。`
      );
    }

    tx.set(ref, {date: today, count: count + 1}, {merge: true});
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 属性別 ベースキャラクター
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 属性ごとに複数のキャラクター案を用意し、カード名のハッシュで決定的に選ぶ。
// 単一の固定文言だと全カードの顔立ちがほぼ同じになってしまうため、
// アーキタイプ・髪型・髪色・表情・鎧の意匠を変えたバリエーションを持たせる。
// 前半5個=人型、後半5個=精霊・幻獣・エレメンタル等の非人型（属性の世界観は共通のまま多様化する）。
const ATTR_CHARACTER_VARIANTS: Record<string, string[]> = {
  joy: [
    "radiant fantasy hero, golden glowing aura, warm smile, luminous flowing golden hair, brilliant sun-motif armor",
    "cheerful young paladin, golden glowing aura, bright confident grin, short auburn hair, ornate sun-crest breastplate",
    "noble sunlit priestess, golden glowing aura, serene gentle smile, long braided silver-blonde hair, flowing golden vestments",
    "spirited boy warrior, golden glowing aura, energetic beaming grin, spiky bronze hair, sun-emblazoned leather armor",
    "elegant solar knight, golden glowing aura, calm composed expression, wavy chestnut hair, gilded ceremonial plate armor",
    "majestic golden phoenix spirit, golden glowing aura, blazing radiant plumage, fiery sun-crest crown of feathers, no human features",
    "guardian sun lion beast, golden glowing aura, regal golden mane, glowing amber eyes, ornate gold-plated harness, no human features",
    "small radiant sun sprite, golden glowing aura, glowing childlike wisp form, trailing sparks of light, no human features",
    "celestial golden serpent deity, golden glowing aura, gleaming scaled coils, crowned with a solar halo, no human features",
    "living sunflower golem, golden glowing aura, petal-crowned wooden body, radiant core glowing within its chest, no human features",
  ],
  anger: [
    "fierce berserker warrior, blazing crimson energy, burning intense eyes, battle-scarred dark armor with flame runes",
    "towering flame gladiator, blazing crimson energy, snarling fierce expression, shaved head with ember tattoos, spiked obsidian armor",
    "ruthless war chieftain, blazing crimson energy, cold furious glare, long braided black hair, crimson battle-worn plate mail",
    "young hotblooded duelist, blazing crimson energy, wild grinning snarl, messy red hair, scorched leather war vest",
    "stoic flame sentinel, blazing crimson energy, grim determined stare, close-cropped grey hair, ash-blackened iron armor",
    "monstrous crimson dragon warlord, blazing crimson energy, jagged obsidian horns, molten cracks glowing across its hide, no human features",
    "living magma golem, blazing crimson energy, cracked volcanic rock body, rivers of glowing lava within, no human features",
    "infernal fire salamander spirit, blazing crimson energy, serpentine flame-wreathed body, ember-trailing tail, no human features",
    "demonic obsidian oni beast, blazing crimson energy, twisted curved horns, smoldering ember-red eyes, no human features",
    "ferocious ember wolf spirit, blazing crimson energy, flame-licked fur, glowing molten claws, no human features",
  ],
  sadness: [
    "serene ethereal mage, soft blue-violet glow, gentle melancholic eyes, midnight robes adorned with silver stars",
    "solemn moonlit oracle, soft blue-violet glow, downcast tearful gaze, long silver hair, flowing indigo mourning veil",
    "quiet frost wanderer, soft blue-violet glow, distant wistful stare, short pale-blue hair, tattered midnight-blue cloak",
    "melancholic young witch, soft blue-violet glow, soft sorrowful smile, dark wavy hair with silver streaks, star-embroidered violet dress",
    "weary twilight sage, soft blue-violet glow, tired hollow eyes, long unkempt grey-blue hair, faded indigo scholar robes",
    "spectral moon wraith, soft blue-violet glow, translucent flowing ghostly form, hollow starlit eyes, no human features",
    "nine-tailed frost kitsune spirit, soft blue-violet glow, silvery-blue flowing fur, glowing crescent moon markings, no human features",
    "deep-sea leviathan spirit, soft blue-violet glow, bioluminescent trailing fins, ancient sorrowful eyes, no human features",
    "shadow raven familiar, soft blue-violet glow, midnight feathers dusted with starlight, glowing violet eyes, no human features",
    "weeping willow tree spirit, soft blue-violet glow, drooping star-lit branches, a faint sorrowful face in its bark, no human features",
  ],
};

// カード名+属性から決定的にバリエーションを選ぶ（同じ入力なら常に同じ見た目になる）
function pickCharacterVariant(attribute: string, seedKey: string): string {
  const variants = ATTR_CHARACTER_VARIANTS[attribute] ?? ATTR_CHARACTER_VARIANTS["joy"];
  let hash = 0;
  for (let i = 0; i < seedKey.length; i++) {
    hash = (hash * 31 + seedKey.charCodeAt(i)) >>> 0;
  }
  return variants[hash % variants.length];
}

const ATTR_PALETTE: Record<string, string> = {
  joy: "warm golden amber sunlit color palette, bright vivid contrast",
  anger: "deep crimson dark orange volcanic color palette, high contrast dramatic",
  sadness: "midnight blue indigo moonlit silver color palette, cool ethereal tones",
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// レアリティ × 属性 背景
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const RARITY_BG: Record<string, Record<string, string>> = {
  joy: {
    n: "solid warm golden gradient background",
    r: "sunlit golden meadow with blooming wildflowers background",
    sr: "majestic golden palace, divine light rays through parting clouds, holy atmosphere",
    ur: "celestial golden sky city, divine floating islands, heavenly aurora, towering radiant spires",
  },
  anger: {
    n: "solid deep crimson gradient background",
    r: "volcanic landscape, glowing lava rivers, molten rocks background",
    sr: "massive volcanic eruption, fire pillars, crimson storm sky, burning mountain peak",
    ur: "apocalyptic volcanic world, titanic inferno, ancient obsidian fortress, legendary fire ocean",
  },
  sadness: {
    n: "solid midnight blue gradient background",
    r: "moonlit mystical lake, silver mist, ancient gnarled trees background",
    sr: "ethereal moonlit realm, aurora borealis, mirror-calm ocean, crumbling ancient ruins",
    ur: "cosmic ocean, enormous full moon, sea of stars, legendary submerged palace glowing in depths",
  },
};

const RARITY_QUALITY: Record<string, string> = {
  n: "",
  r: "detailed illustration, atmospheric lighting,",
  sr: "highly detailed, cinematic dramatic lighting, rich textures,",
  ur: "legendary epic masterpiece, extraordinary intricate detail, breathtaking composition,",
};

const TONE_STYLE: Record<string, string> = {
  cute: "soft rounded features, gentle warm expression, pastel accents, charming kawaii-inspired",
  cool: "sharp defined features, determined confident expression, high contrast dramatic lighting",
  dark: "brooding mysterious atmosphere, deep shadows, smoldering gothic intensity",
  elegant: "graceful refined posture, flowing ornate garments, noble aristocratic bearing",
  normal: "balanced natural proportions, clean composition",
};

const TYPE_POSE: Record<string, string> = {
  attack: "aggressive forward combat pose, weapon raised, explosive offensive energy burst",
  defense: "firm protective stance, shield raised, radiant barrier aura surrounding body",
  speed: "dynamic swift dashing pose, speed trail lines, wind blur motion",
  balance: "composed centered stance, balanced power flowing steadily from core",
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// デザインワード マッピング（100語）
// カテゴリ: weapon | companion | power | nature | place | abstract
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
interface WordDef { en: string; cat: "weapon" | "companion" | "power" | "nature" | "place" | "abstract" }
const WORD_MAP: Record<string, WordDef> = {
  // 自然・季節
  "桜": {en: "swirling cherry blossom petals", cat: "nature"},
  "月": {en: "under a glowing crescent moon", cat: "nature"},
  "星": {en: "with starlight sparkling around", cat: "nature"},
  "雪": {en: "with softly drifting snowflakes", cat: "nature"},
  "炎": {en: "with dancing flames around", cat: "power"},
  "風": {en: "with swirling wind currents", cat: "power"},
  "雨": {en: "in falling silver rain", cat: "nature"},
  "海": {en: "ocean waves background", cat: "place"},
  "山": {en: "towering mountain peaks background", cat: "place"},
  "森": {en: "mystical ancient forest background", cat: "place"},
  "花": {en: "amid blooming colorful flowers", cat: "nature"},
  "太陽": {en: "with radiant sun rays above", cat: "nature"},
  "雲": {en: "among dramatic storm clouds", cat: "nature"},
  "雷": {en: "crackling with lightning bolts", cat: "power"},
  "虹": {en: "with a rainbow arc above", cat: "nature"},
  "波": {en: "with crashing ocean waves", cat: "nature"},
  "砂漠": {en: "golden desert dune landscape", cat: "place"},
  "滝": {en: "beside a magnificent waterfall", cat: "place"},
  "峰": {en: "atop a mountain peak", cat: "place"},
  "谷": {en: "in a deep misty valley", cat: "place"},
  // 感情・心
  "喜び": {en: "radiating joyful light", cat: "abstract"},
  "勇気": {en: "exuding fierce courage", cat: "abstract"},
  "希望": {en: "emanating hope and warm light", cat: "abstract"},
  "愛": {en: "with a warm protective aura", cat: "abstract"},
  "誇り": {en: "standing with noble pride", cat: "abstract"},
  "幸福": {en: "with blissful serene expression", cat: "abstract"},
  "輝き": {en: "shimmering with brilliant inner light", cat: "power"},
  "温暖": {en: "glowing with warm golden radiance", cat: "power"},
  "優雅": {en: "moving with graceful elegance", cat: "abstract"},
  "神秘": {en: "shrouded in mystical energy", cat: "abstract"},
  "静寂": {en: "in peaceful serene stillness", cat: "abstract"},
  "深淵": {en: "above a dark glowing abyss", cat: "place"},
  "炎心": {en: "with a burning heart of fire at chest", cat: "power"},
  "鋼鉄": {en: "clad in intricate steel armor", cat: "abstract"},
  "柔和": {en: "with a gentle calm demeanor", cat: "abstract"},
  "清廉": {en: "radiating pure clear light", cat: "abstract"},
  "純潔": {en: "with pure immaculate white aura", cat: "abstract"},
  "雄大": {en: "of majestic towering stature", cat: "abstract"},
  "優美": {en: "of beautiful graceful form", cat: "abstract"},
  "荘厳": {en: "of solemn magnificent presence", cat: "abstract"},
  // 力・戦い
  "剣": {en: "wielding a gleaming radiant sword", cat: "weapon"},
  "盾": {en: "holding an ornate glowing shield", cat: "weapon"},
  "槍": {en: "bearing a shining long spear", cat: "weapon"},
  "弓": {en: "drawing an elegant enchanted bow", cat: "weapon"},
  "戦士": {en: "as a seasoned battle warrior", cat: "abstract"},
  "騎士": {en: "as a noble armored knight", cat: "abstract"},
  "将軍": {en: "as a commanding legendary general", cat: "abstract"},
  "王冠": {en: "wearing a radiant jeweled crown", cat: "weapon"},
  "玉座": {en: "before an ornate glowing throne", cat: "place"},
  "城": {en: "grand fortress castle background", cat: "place"},
  "力": {en: "surging with raw elemental power", cat: "power"},
  "闘志": {en: "burning with fierce fighting spirit", cat: "abstract"},
  "勝利": {en: "in a triumphant victory pose", cat: "abstract"},
  "征服": {en: "in a powerful conquering stance", cat: "abstract"},
  "無敵": {en: "with an invincible energy shield", cat: "power"},
  "覇者": {en: "as a supreme champion overlord", cat: "abstract"},
  "英雄": {en: "as a legendary heroic figure", cat: "abstract"},
  "伝説": {en: "with legendary mythical presence", cat: "abstract"},
  "神話": {en: "of ancient mythological divine origin", cat: "abstract"},
  "栄光": {en: "bathed in glorious radiant light", cat: "power"},
  // 動物・生物
  "龍": {en: "with a majestic dragon companion", cat: "companion"},
  "鷲": {en: "with a great eagle soaring above", cat: "companion"},
  "獅子": {en: "with a regal lion beside", cat: "companion"},
  "虎": {en: "with a fierce tiger nearby", cat: "companion"},
  "熊": {en: "with a powerful bear spirit", cat: "companion"},
  "狼": {en: "with loyal wolves flanking", cat: "companion"},
  "鹿": {en: "with a majestic glowing stag", cat: "companion"},
  "馬": {en: "astride a powerful armored horse", cat: "companion"},
  "象": {en: "beside an ancient great elephant", cat: "companion"},
  "鮫": {en: "with shark energy and speed", cat: "power"},
  "鷹": {en: "with a swift hawk in flight", cat: "companion"},
  "鶴": {en: "with elegant cranes dancing", cat: "companion"},
  "蛇": {en: "with serpents coiling gracefully", cat: "companion"},
  "猫": {en: "with a mystical cat familiar", cat: "companion"},
  "犬": {en: "with a faithful guardian dog", cat: "companion"},
  "鳳凰": {en: "with a magnificent phoenix rising behind", cat: "companion"},
  "ユニコーン": {en: "beside a radiant unicorn", cat: "companion"},
  "グリフォン": {en: "with a powerful griffon companion", cat: "companion"},
  "鬼": {en: "with fearsome oni demon energy", cat: "power"},
  "天使": {en: "with angelic wings of pure light", cat: "abstract"},
  // 色・光
  "金": {en: "gleaming with pure gold accents", cat: "power"},
  "銀": {en: "shimmering with silver metallic light", cat: "power"},
  "青": {en: "with deep sapphire blue tones", cat: "abstract"},
  "紅": {en: "with vivid crimson red accents", cat: "abstract"},
  "紫": {en: "with royal violet purple hues", cat: "abstract"},
  "緑": {en: "with lush emerald green energy", cat: "abstract"},
  "黒": {en: "with deep onyx black shadows", cat: "abstract"},
  "白": {en: "with pure luminous white glow", cat: "abstract"},
  "虹色": {en: "with rainbow iridescent shimmer", cat: "power"},
  "オーロラ": {en: "under dazzling aurora borealis", cat: "nature"},
  "光": {en: "emanating brilliant radiant light", cat: "power"},
  "影": {en: "casting dramatic dark shadows", cat: "abstract"},
  "煌めき": {en: "sparkling with brilliant particles", cat: "power"},
  "煌き": {en: "glittering with dazzling brilliance", cat: "power"},
  "暗黒": {en: "surrounded by dark void energy", cat: "power"},
  "真紅": {en: "with deep scarlet glowing red", cat: "power"},
  "藍": {en: "with deep indigo blue hues", cat: "abstract"},
  "翠": {en: "with jade green emerald tones", cat: "abstract"},
  "黄金": {en: "encased in golden gleaming radiance", cat: "power"},
  "白銀": {en: "radiant with pure silver shine", cat: "power"},
  // 時間・運命
  "時間": {en: "with ancient clock and time motifs", cat: "abstract"},
  "永遠": {en: "with eternal timeless presence", cat: "abstract"},
  "運命": {en: "bearing the mark of destiny", cat: "abstract"},
  "未来": {en: "with futuristic energy circuits", cat: "abstract"},
  "過去": {en: "with ancient historical runes", cat: "abstract"},
  "今": {en: "with present-moment burning intensity", cat: "abstract"},
  "刹那": {en: "in a crystallized fleeting moment", cat: "abstract"},
  "輪廻": {en: "with reincarnation spiral energy", cat: "abstract"},
  "因果": {en: "with karma and fate energy threads", cat: "abstract"},
  "宿命": {en: "bound by inevitable cosmic fate", cat: "abstract"},
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// スロットベース プロンプト合成
// カテゴリごとに最大使用数を制限し構造を保つ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function buildDesignSlots(words: string[]): {
  weaponSlot: string;
  companionSlot: string;
  auraSlot: string;
  envSlot: string;
  traitSlot: string;
} {
  const buckets: Record<string, string[]> = {
    weapon: [], companion: [], power: [], nature: [], place: [], abstract: [],
  };

  for (const word of words) {
    const def = WORD_MAP[word];
    if (def) buckets[def.cat].push(def.en);
  }

  // 各スロットに最大1〜2個ずつ割り当て（優先順は buckets の先頭）
  const weaponSlot = buckets["weapon"].slice(0, 1).join(", ");
  const companionSlot = buckets["companion"].slice(0, 1).join(", ");
  const auraSlot = buckets["power"].slice(0, 1).join(", ");
  // 背景はplace優先、なければnature
  const envSlot = [...buckets["place"], ...buckets["nature"]].slice(0, 1).join(", ");
  // 性格/特質は最大2つ
  const traitSlot = buckets["abstract"].slice(0, 2).join(", ");

  return {weaponSlot, companionSlot, auraSlot, envSlot, traitSlot};
}

interface GenerateImageRequest {
  attribute: string;
  cardName: string;
  cardType: string;
  rarity: string;
  designWords: string[];
  tone: string;
}

export const generateCardImage = functions
  .region("asia-northeast1")
  .runWith({
    timeoutSeconds: 120,
    memory: "256MB",
    // REPLICATE_API_TOKEN は未登録（スキップ中）。generateImageWithFallbackは
    // トークン無し時にエラーを投げ、自動的にLeonardoへフォールバックする。
    // Replicateを登録したら IMAGE_PROVIDER_SECRETS （imageProviders.ts）に差し替える。
    secrets: ["LEONARDO_API_KEY"],
  })
  .https.onCall(async (data: GenerateImageRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }

    await checkAndIncrementDailyGenerationCount(context.auth.uid);

    const attr = data.attribute ?? "joy";
    const rarity = (data.rarity ?? "n").toLowerCase();
    const tone = data.tone ?? "normal";
    const cardType = data.cardType ?? "balance";
    const designWords: string[] = (data.designWords ?? []).slice(0, 3);
    const cardName = (data.cardName ?? "").trim();

    // ── ベース要素（属性・レアリティで固定） ──
    // カード名+属性をシードに人型/非人型を含む10案から決定的に選ぶ（同名同属性なら再生成しても同じ見た目）
    const character = pickCharacterVariant(attr, `${cardName}:${attr}`);
    const palette = ATTR_PALETTE[attr] ?? ATTR_PALETTE["joy"];
    const bg = RARITY_BG[attr]?.[rarity] ?? RARITY_BG["joy"]["n"];
    const pose = TYPE_POSE[cardType] ?? TYPE_POSE["balance"];
    const toneStyle = TONE_STYLE[tone] ?? TONE_STYLE["normal"];
    const rarityQuality = RARITY_QUALITY[rarity] ?? "";

    // ── デザインワード → スロット割り当て ──
    const slots = buildDesignSlots(designWords);

    // ── キャラクター部分（weapon + companion + trait を自然に組み込む） ──
    const charParts = [
      character,
      slots.weaponSlot ? slots.weaponSlot : "",
      slots.companionSlot ? slots.companionSlot : "",
      slots.traitSlot ? slots.traitSlot : "",
      cardName ? `embodying "${cardName}"` : "",
      pose,
      toneStyle,
    ].filter(Boolean).join(", ");

    // ── 背景部分（base bg + env word + aura） ──
    // デザインワードの環境は bg に追加する（bg を上書きしない）
    const bgParts = [
      bg,
      slots.envSlot ? `with ${slots.envSlot} in the scene` : "",
      slots.auraSlot ? `${slots.auraSlot} energy aura` : "",
    ].filter(Boolean).join(", ");

    // ── 最終プロンプト（構造固定・スタイル統一） ──
    const prompt = [
      charParts,
      bgParts,
      palette,
      rarityQuality,
      "digital fantasy TCG card illustration, centered character portrait, vibrant vivid colors, professional clean artwork, dramatic lighting",
      "no text no watermark no border",
    ].filter(Boolean).join(", ");

    const negativePrompt = [
      "text, words, letters, numbers, watermark, signature",
      "card frame, border, UI, HUD",
      "ugly, blurry, low quality, deformed, mutated, malformed",
      "extra limbs, bad anatomy, extra fingers",
      "duplicate, oversaturated, washed out",
    ].join(", ");

    // ── 画像生成: Replicate(Flux Schnell)を優先、失敗時はLeonardo(Phoenix 1.0)へフォールバック ──
    let imageBuffer: Buffer;
    let providerUsed: "replicate" | "leonardo";
    try {
      const generated = await generateImageWithFallback(prompt, negativePrompt);
      imageBuffer = generated.buffer;
      providerUsed = generated.provider;
    } catch {
      throw new functions.https.HttpsError("internal", "画像生成に失敗しました（Replicate/Leonardo両方失敗）");
    }

    const bucket = admin.storage().bucket();
    const userId = context.auth.uid;
    const filename = `user_cards/${userId}/${Date.now()}.png`;
    const file = bucket.file(filename);

    await file.save(imageBuffer, {contentType: "image/png"});
    await file.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;
    return {imageUrl: publicUrl, promptUsed: prompt, provider: providerUsed};
  });
