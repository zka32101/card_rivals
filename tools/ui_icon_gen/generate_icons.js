#!/usr/bin/env node
// UIアイコン 一括生成ツール（Leonardo.ai版）
// 画面で絵文字（🪙💎☀️🔥🌙⚔️🛡️⚡🥇🥈🥉）を使っている所を置き換える11枚を生成する。
// 透過にするため、白(#FFFFFF)の背景で生成し、あとで chroma_key.py で抜く。コスト最小設定。
// 既存ファイルは自動スキップ（--forceで上書き）。
//
// 使い方（PowerShellで事前に $env:LEONARDO_API_KEY="xxxx" 済みなら省略可）:
//   node generate_icons.js --all
//   node generate_icons.js --ids first_victory,first_card_created
//   node generate_icons.js --all --force

const fs = require('fs');
const path = require('path');

const LEONARDO_API_KEY = process.env.LEONARDO_API_KEY;
const LEONARDO_MODEL_ID = process.env.LEONARDO_MODEL_ID || 'de7d3faf-762f-48e0-b3b7-9d0ac3a3fcf3';
const API_BASE = 'https://cloud.leonardo.ai/api/rest/v1';
const OUTPUT_DIR = path.join(__dirname, 'output');

// 共通の土台: 円形メダル、金/ブロンズの縁取り、Card Rivalsの世界観（夜空紺+金箔+羊皮紙）
const BASE_PROMPT =
  'A single isolated game asset object, bold flat vector game-art style with soft inner glow, thick clean silhouette readable at 48px, ' +
  'gold-leaf details with deep navy accents (night-sky fantasy card game), high contrast, ' +
  'the object fills about 80 percent of the canvas and is centered, on a plain pure white background (#FFFFFF), ' +
  'sticker cutout look, no rounded-square tile, no frame, no panel, no cast shadow, no text, no letters, no watermark.';

const NEGATIVE_PROMPT =
  'app icon tile, rounded square background, colored background, purple background, gradient background, vignette, ' +
  'frame, border panel, text, letters, words, watermark, signature, blurry, photorealistic, human face, realistic person, ' +
  'scenery, multiple objects, shield, badge, emblem, circle behind object, square panel, plaque, tile, border corners, cropped, off-center, cast shadow, drop shadow, low quality, jpeg artifacts';

const BADGES = [
  { id: 'coin', motif: 'a single thick round gold coin seen slightly from the front, embossed with a small star in the center, shining edge' },
  { id: 'gem', motif: 'a single faceted brilliant-cut blue-violet gemstone (sapphire), sparkling highlights' },
  { id: 'attr_joy', motif: 'a golden-yellow sun with short rays, warm glowing orb style, symbol of joy' },
  { id: 'attr_anger', motif: 'a crimson-red flame, bold teardrop fire shape, glowing orb style, symbol of anger' },
  { id: 'attr_sadness', motif: 'an indigo-blue crescent moon with a faint glow, glowing orb style, symbol of sadness' },
  { id: 'stat_attack', motif: 'a single upright steel sword with a gold crossguard, pointing up' },
  { id: 'stat_defense', motif: 'a single heater shield, steel blue face with a gold rim, small star emblem' },
  { id: 'stat_speed', motif: 'a lightning bolt symbol cut out as a sticker: golden yellow zigzag bolt with a thick dark navy outline, tightly cropped, only the bolt' },
  { id: 'medal_gold', motif: 'a round gold medal hanging from a V-shaped navy ribbon with gold edges, embossed with a star, shiny, same design as a silver and a bronze medal but gold' },
  { id: 'medal_silver', motif: 'a round silver medal hanging from a V-shaped navy ribbon with gold edges, embossed with a star, shiny' },
  { id: 'medal_bronze', motif: 'a round bronze medal hanging from a V-shaped navy ribbon with gold edges, embossed with a star, shiny' },
];

function buildPrompt(motif) {
  return `${BASE_PROMPT} Central motif: ${motif}.`;
}

async function generateImage(prompt) {
  const createRes = await fetch(`${API_BASE}/generations`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${LEONARDO_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      prompt,
      negative_prompt: NEGATIVE_PROMPT,
      modelId: LEONARDO_MODEL_ID,
      width: 512,
      height: 512,
      num_images: 1,
      alchemy: false,
      photoReal: false,
    }),
  });

  if (!createRes.ok) {
    throw new Error(`Leonardo API error (create): ${createRes.status} ${await createRes.text()}`);
  }

  const created = await createRes.json();
  const genId = created?.sdGenerationJob?.generationId;
  if (!genId) {
    throw new Error(`generationId が取得できませんでした: ${JSON.stringify(created)}`);
  }

  let attempts = 0;
  let images = null;
  while (attempts < 30) {
    await new Promise((r) => setTimeout(r, 2000));
    const poll = await fetch(`${API_BASE}/generations/${genId}`, {
      headers: { Authorization: `Bearer ${LEONARDO_API_KEY}` },
    });
    if (!poll.ok) {
      throw new Error(`Leonardo API error (poll): ${poll.status} ${await poll.text()}`);
    }
    const data = await poll.json();
    const gen = data.generations_by_pk;
    if (gen?.status === 'COMPLETE') {
      images = gen.generated_images;
      break;
    }
    if (gen?.status === 'FAILED') {
      throw new Error(`generation failed: ${JSON.stringify(gen)}`);
    }
    attempts++;
  }

  if (!images || !images[0]?.url) {
    throw new Error('画像生成がタイムアウトしました');
  }

  return images[0].url;
}

async function downloadTo(url, filePath) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download failed: ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(filePath, buf);
}

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { ids: null, all: false, force: false };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--ids') opts.ids = args[++i].split(',').map((s) => s.trim());
    else if (args[i] === '--all') opts.all = true;
    else if (args[i] === '--force') opts.force = true;
  }
  return opts;
}

async function main() {
  if (!LEONARDO_API_KEY) {
    console.error('❌ LEONARDO_API_KEY が設定されていません。');
    process.exit(1);
  }
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const opts = parseArgs();
  let target = BADGES;
  if (opts.ids) target = BADGES.filter((b) => opts.ids.includes(b.id));
  else if (!opts.all) target = BADGES.slice(0, 2); // デフォルトはサンプル2枚

  let done = 0;
  for (const badge of target) {
    const outPath = path.join(OUTPUT_DIR, `${badge.id}.png`);
    if (fs.existsSync(outPath) && !opts.force) {
      console.log(`⏭  skip (exists): ${badge.id}`);
      continue;
    }
    try {
      console.log(`🎨 generating: ${badge.id}...`);
      const url = await generateImage(buildPrompt(badge.motif));
      await downloadTo(url, outPath);
      console.log(`✅ saved: ${outPath}`);
      done++;
    } catch (e) {
      console.error(`❌ failed (${badge.id}): ${e.message}`);
    }
  }
  console.log(`\n完了: ${done}/${target.length} 枚生成`);
}

main().catch((e) => {
  console.error('❌ エラー:', e.message);
  process.exit(1);
});
