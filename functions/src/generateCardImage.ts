import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {onCall, HttpsError} from "firebase-functions/v2/https";
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
  const ref = getFirestore().collection("cardGenerationLimits").doc(userId);

  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const count = data?.date === today ? (data.count as number ?? 0) : 0;

    if (count >= DAILY_CARD_GENERATION_LIMIT) {
      throw new HttpsError(
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
// 人型と、精霊・幻獣・エレメンタル等の非人型を混在させている（属性の世界観は共通のまま多様化する）。
// さらに生成のたびに下の VARIATION_* からランダムに演出（構図・光・差し色・装飾）を足して、
// 同じ属性・同じ言葉でも毎回違う見た目になるようにしている。
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
    "gentle sunlit bard, golden glowing aura, warm laughing smile, curly honey-blonde hair, embroidered golden tunic",
    "proud dawn archer, golden glowing aura, keen focused gaze, long tied-back amber hair, light radiant leather armor",
    "wise golden-robed scholar, golden glowing aura, kind knowing smile, white beard and tidy gold circlet, sun-patterned robes",
    "radiant winged sun angel, golden glowing aura, serene gentle face, feathered golden wings, shining white-gold armor",
    "playful golden fox spirit, golden glowing aura, bright mischievous eyes, fluffy amber tails tipped with light, no human features",
    "ancient sun-blessed stag beast, golden glowing aura, antlers wreathed in golden flame, gleaming coat, no human features",
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
    "grim crimson assassin, blazing crimson energy, narrowed cold eyes, hooded dark cloak with ember trim, twin burning blades",
    "roaring flame knight, blazing crimson energy, fierce battle cry expression, horned crimson helmet, heavy spiked greaves",
    "scarred veteran general, blazing crimson energy, stern iron stare, grey-streaked red beard, war-torn banner cape",
    "wild fire-dancer warrior, blazing crimson energy, fierce wild grin, long flowing red hair, ember-lit tribal garb",
    "colossal obsidian minotaur, blazing crimson energy, glowing cracked horns, smoking nostrils, chained iron armor, no human features",
    "blazing phoenix-eagle of war, blazing crimson energy, sharp burning talons, wings trailing sparks, no human features",
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
    "lonely rain-cloaked traveler, soft blue-violet glow, quiet distant eyes, drenched dark hair, hooded silver-blue cloak",
    "elegant moon priestess, soft blue-violet glow, tearful serene gaze, long pale hair with crescent crown, flowing pearl-white robes",
    "gentle sleeping dream knight, soft blue-violet glow, calm closed-eye expression, short dark curls, star-dusted indigo armor",
    "ghostly lantern-bearer child, soft blue-violet glow, wistful pale face, tattered violet cloak, a glowing blue lantern",
    "ancient silver owl sage, soft blue-violet glow, deep wise eyes, moonlit feathers like silver leaves, no human features",
    "drifting jellyfish star spirit, soft blue-violet glow, translucent bell body, trailing glittering tendrils, no human features",
  ],
};

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

// キャラクター案は生成のたびにランダムに選ぶ（以前はカード名のハッシュで固定していたため、
// 同じ名前・言葉なら何度作っても同じ見た目になっていた。作り直しで別の絵になるのが狙い）。
function pickCharacterVariant(attribute: string): string {
  return pick(ATTR_CHARACTER_VARIANTS[attribute] ?? ATTR_CHARACTER_VARIANTS["joy"]);
}

// 生成のたびにランダムに混ぜる演出。属性パレットは崩さずに、構図・光・差し色・装飾を変える。
const VARIATION_CAMERA = [
  "close-up bust portrait", "dynamic low-angle heroic shot", "three-quarter view portrait",
  "full-body standing pose", "dramatic over-the-shoulder glance", "wide shot with the character small against a grand scene",
  "dynamic diagonal composition mid-action", "symmetrical heraldic frontal composition",
];
const VARIATION_LIGHT = [
  "rim lighting from behind", "soft diffused glow", "dramatic side lighting",
  "strong backlit halo", "volumetric light rays", "moody chiaroscuro lighting", "sparkling floating light particles",
];
const VARIATION_DETAIL = [
  "intricate engraved ornamental details", "flowing ribbons and billowing cloth", "swirling magical runes in the air",
  "drifting petals and sparks", "layered translucent veils of light", "delicate filigree patterns",
];
const VARIATION_ACCENT: Record<string, string[]> = {
  joy: ["with soft pink accents", "with fresh emerald green accents", "with sky blue accents", "with warm white and ivory accents", "with deep orange accents"],
  anger: ["with bright gold accents", "with cold steel grey accents", "with violet accents", "with black and white contrast accents", "with burning orange accents"],
  sadness: ["with soft pink accents", "with pale emerald accents", "with silver white accents", "with warm amber lantern accents", "with deep purple accents"],
};

function pickVariation(attribute: string): string {
  return [
    pick(VARIATION_CAMERA),
    pick(VARIATION_LIGHT),
    pick(VARIATION_DETAIL),
    pick(VARIATION_ACCENT[attribute] ?? VARIATION_ACCENT["joy"]),
  ].join(", ");
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
  // ── UIに出るが辞書に無かった言葉（選んでも画像に反映されなかった） ──
  // 自然・季節
  "氷河": {en: "a vast glowing blue glacier with towering ice walls", cat: "place"},
  "朝霧": {en: "drifting morning mist with soft golden light", cat: "nature"},
  "大地": {en: "a vast rugged earth landscape with cracked ground", cat: "place"},
  "嵐": {en: "a raging storm with whipping wind and dark swirling clouds", cat: "nature"},
  "流星": {en: "streaking shooting stars across the sky", cat: "nature"},
  "極光": {en: "shimmering polar aurora ribbons in the sky", cat: "nature"},
  "潮騒": {en: "rolling sea waves with sparkling sea spray", cat: "nature"},
  "新緑": {en: "fresh bright green spring leaves all around", cat: "nature"},
  "紅葉": {en: "falling red and orange autumn maple leaves", cat: "nature"},
  "氷晶": {en: "glittering ice crystals floating in the air", cat: "nature"},
  // 感情・心
  "哀愁": {en: "a bittersweet wistful melancholy mood", cat: "abstract"},
  "慈愛": {en: "tender compassionate love with a warm embracing gesture", cat: "abstract"},
  "執念": {en: "an obsessive relentless burning gaze", cat: "abstract"},
  "情熱": {en: "passionate burning intensity with glowing red energy", cat: "power"},
  "安らぎ": {en: "peaceful calm comfort with a soft soothing glow", cat: "abstract"},
  "孤高": {en: "a lone proud figure standing alone on a high place", cat: "abstract"},
  "覚悟": {en: "an unwavering resolute determined stance", cat: "abstract"},
  "憧憬": {en: "a longing yearning gaze toward a distant light", cat: "abstract"},
  "慟哭": {en: "grief-stricken sorrow with glowing tears", cat: "abstract"},
  "祈り": {en: "a solemn prayer pose with hands clasped and rising light", cat: "abstract"},
  // 力・戦い
  "軍旗": {en: "holding a great waving war banner", cat: "weapon"},
  "要塞": {en: "a massive stone fortress bastion background", cat: "place"},
  "刃": {en: "wielding a razor-sharp gleaming blade", cat: "weapon"},
  "鎧": {en: "clad in heavy ornate plate armor", cat: "weapon"},
  "戦場": {en: "a smoky battlefield with clashing armies in the distance", cat: "place"},
  "守護": {en: "a guardian protector with a glowing barrier of light", cat: "abstract"},
  "反逆": {en: "a rebellious defiant pose breaking free of chains", cat: "abstract"},
  "進撃": {en: "charging forward in a relentless advance", cat: "abstract"},
  "雄叫び": {en: "roaring a mighty battle cry with an open mouth", cat: "abstract"},
  "不屈": {en: "an indomitable unbroken spirit standing despite battle damage", cat: "abstract"},
  // 動物・生物
  "悪魔": {en: "with a sinister demon presence, curved horns and dark wings", cat: "companion"},
  "麒麟": {en: "with a divine kirin qilin beast with flowing mane and scales", cat: "companion"},
  "梟": {en: "with a wise great owl with piercing eyes", cat: "companion"},
  "蝶": {en: "surrounded by glowing fluttering butterflies", cat: "companion"},
  "蜘蛛": {en: "with a giant spider weaving glowing silk threads", cat: "companion"},
  "亀": {en: "with an ancient giant turtle with a mossy shell", cat: "companion"},
  "狐": {en: "with a mystical fox spirit with multiple tails", cat: "companion"},
  "兎": {en: "with a moon rabbit companion", cat: "companion"},
  "海竜": {en: "with a mighty sea serpent dragon rising from the waves", cat: "companion"},
  "精霊": {en: "with small glowing elemental spirits floating around", cat: "companion"},
  // 色・光
  "漆黒": {en: "enveloped in glossy jet-black darkness", cat: "power"},
  "乳白": {en: "wrapped in soft milky-white light", cat: "power"},
  "瑠璃": {en: "with deep lapis lazuli blue gemstone tones", cat: "abstract"},
  "琥珀": {en: "with warm translucent amber glow", cat: "abstract"},
  "緋色": {en: "with vivid scarlet vermilion accents", cat: "abstract"},
  "群青": {en: "with rich ultramarine blue tones", cat: "abstract"},
  "銀河": {en: "with a swirling galaxy of stars", cat: "nature"},
  "夜光": {en: "glowing with luminous night-light", cat: "power"},
  "薄明": {en: "in dim twilight glow of dawn", cat: "nature"},
  "残光": {en: "trailing fading afterglow light streaks", cat: "power"},
  // 時間・運命
  "黎明": {en: "at the breaking dawn with the first golden sunrise", cat: "nature"},
  "黄昏": {en: "in the dusk of a fiery orange-purple sunset", cat: "nature"},
  "終焉": {en: "at the dramatic end of the world with crumbling skies", cat: "abstract"},
  "始まり": {en: "at a hopeful new beginning with a rising light", cat: "abstract"},
  "記憶": {en: "with floating translucent memory fragments", cat: "abstract"},
  "約束": {en: "bound by a glowing pledge with a shining thread of light", cat: "abstract"},
  "奇跡": {en: "a miracle moment with a pillar of radiant light", cat: "power"},
  "転生": {en: "reborn in a swirling cycle of light and petals", cat: "abstract"},
  "予兆": {en: "an ominous omen with glowing signs in the sky", cat: "abstract"},
  "継承": {en: "passing a glowing heirloom to the next generation", cat: "abstract"},
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 選んだ言葉 → 「必ず描くもの」
// 以前は種類（武器・仲間・背景…）ごとに1〜2個までしか使わず、同じ種類を3つ選ぶと
// 2つが無視されていた（桜・月・星→「桜」だけ）。さらに辞書に無い言葉は黙って捨てていた。
// いまは選んだ全部を使い、辞書に無い言葉も言葉そのものをテーマとして渡す。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function buildKeyElements(words: string[]): string[] {
  return words.map((w) => WORD_MAP[w]?.en ?? `the theme of "${w}"`);
}

interface GenerateImageRequest {
  attribute: string;
  cardName: string;
  cardType: string;
  rarity: string;
  designWords: string[];
  tone: string;
}

export const generateCardImage = onCall(
  {
    region: "asia-northeast1",
    timeoutSeconds: 120,
    memory: "256MiB",
    // REPLICATE_API_TOKEN は未登録（スキップ中）。generateImageWithFallbackは
    // トークン無し時にエラーを投げ、自動的にLeonardoへフォールバックする。
    // Replicateを登録したら IMAGE_PROVIDER_SECRETS （imageProviders.ts）に差し替える。
    secrets: ["LEONARDO_API_KEY"],
  },
  async (request) => {
    const data = request.data as GenerateImageRequest;
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "認証が必要です");
    }

    await checkAndIncrementDailyGenerationCount(request.auth.uid);

    const attr = data.attribute ?? "joy";
    const rarity = (data.rarity ?? "n").toLowerCase();
    const tone = data.tone ?? "normal";
    const cardType = data.cardType ?? "balance";
    const designWords: string[] = (data.designWords ?? []).slice(0, 3);
    const cardName = (data.cardName ?? "").trim();

    // ── ベース要素（属性・レアリティで固定） ──
    // 人型/非人型を含む16案から生成のたびにランダムに選び、構図・光・差し色・装飾もランダムに足す
    const character = pickCharacterVariant(attr);
    const variation = pickVariation(attr);
    const palette = ATTR_PALETTE[attr] ?? ATTR_PALETTE["joy"];
    const bg = RARITY_BG[attr]?.[rarity] ?? RARITY_BG["joy"]["n"];
    const pose = TYPE_POSE[cardType] ?? TYPE_POSE["balance"];
    const toneStyle = TONE_STYLE[tone] ?? TONE_STYLE["normal"];
    const rarityQuality = RARITY_QUALITY[rarity] ?? "";

    // ── 選んだ言葉（最大3つ）は全部を「必ず描くもの」として先頭で強く指定し、末尾でも繰り返す ──
    const keyElements = buildKeyElements(designWords);
    const keyLead = keyElements.length > 0 ?
      `The image MUST clearly and prominently show ALL ${keyElements.length} of these key elements, each one plainly visible and recognizable: ${keyElements.map((e, i) => `(${i + 1}) ${e}`).join("; ")}` :
      "";
    const keyTail = keyElements.length > 0 ? `featuring ${keyElements.join(", ")}` : "";

    // ── キャラクター部分（選んだ言葉は先頭の keyLead に入れるのでここには入れない） ──
    const charParts = [
      character,
      cardName ? `embodying "${cardName}"` : "",
      pose,
      toneStyle,
    ].filter(Boolean).join(", ");

    // ── 背景部分（レアリティ別の基本背景。選んだ言葉の場所・自然は keyLead 側で指定済み） ──
    const bgParts = bg;

    // ── 最終プロンプト（選んだ言葉を最優先・スタイルは統一） ──
    const prompt = [
      keyLead,
      charParts,
      variation,
      bgParts,
      palette,
      rarityQuality,
      "digital fantasy TCG card illustration, centered character portrait, vibrant vivid colors, professional clean artwork, dramatic lighting",
      keyTail,
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
    // 毎回異なるseedを渡し、同じプロンプトでも構図が似通わないようにする
    const seed = Math.floor(Math.random() * 2147483000);
    let imageBuffer: Buffer;
    let providerUsed: "replicate" | "leonardo";
    try {
      const generated = await generateImageWithFallback(prompt, negativePrompt, seed);
      imageBuffer = generated.buffer;
      providerUsed = generated.provider;
    } catch {
      throw new HttpsError("internal", "画像生成に失敗しました（Replicate/Leonardo両方失敗）");
    }

    const bucket = getStorage().bucket();
    const userId = request.auth.uid;
    const filename = `user_cards/${userId}/${Date.now()}.png`;
    const file = bucket.file(filename);

    await file.save(imageBuffer, {contentType: "image/png"});
    await file.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;
    return {imageUrl: publicUrl, promptUsed: prompt, provider: providerUsed};
  }
);
