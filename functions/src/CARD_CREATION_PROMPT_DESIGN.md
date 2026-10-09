# カード作成（ユーザー創作）AIプロンプト設計

`generateCardImage.ts`（Cloud Functions, `asia-northeast1`）が、アプリ内「カード作成」画面
（`card_creation_screen_v2.dart` → `FunctionsService.generateCardImage`）から呼ばれた際に
実際に組み立てるプロンプトの構造。

シードカード（運営製・既存50枚）向けの簡易版は
[tools/seed_card_image_gen/PROMPT_DESIGN.md](../../tools/seed_card_image_gen/PROMPT_DESIGN.md) を参照。
本ドキュメントはユーザーが自分でカードを創作する際の、デザインワード辞書とトーン選択を含む
フル機能版のプロンプト設計を扱う。

## 使用モデル

- **Replicate Flux Schnell**（version: `5f24084160c9089501c1b3545d9be3c27883ae2239b6f412990e82d4a6210f8f`）
- 標準品質設定: `512x512` / `num_inference_steps: 4`
- 生成画像は Firebase Storage の `user_cards/{userId}/{timestamp}.png` に保存され公開URL化される
- Callable Function（`context.auth` 必須、タイムアウト120秒・メモリ256MB）

## 入力（`GenerateImageRequest`）

| フィールド | 型 | 内容 |
|---|---|---|
| `attribute` | string | 喜(joy)/怒(anger)/哀(sadness)。未指定時は joy |
| `cardName` | string | カード名（プロンプトに `embodying "名前"` として埋め込み） |
| `cardType` | string | attack / defense / speed / balance（ステータス配分から判定） |
| `rarity` | string | n / r / sr / ur |
| `designWords` | string[] | ユーザーが選んだデザインワード（**最大3個**まで採用） |
| `tone` | string | cute / cool / dark / elegant / normal |

## プロンプト組み立て順序

```
キャラクター基本形 + 武器語 + 相棒語 + 特質語 + カード名埋め込み + ポーズ + トーン
→ 背景（基本 + 環境語 + オーラ語）→ 属性パレット → レアリティ品質句
→ TCGカード指定 → 除外指定
```

シードカード版との最大の違いは、**ユーザーが選んだ最大3つのデザインワードが
カテゴリ別スロットに自動振り分けされ、キャラクター描写と背景に自然に溶け込む**点。

## 見た目のバリエーション（毎回ランダム）

同じ属性・同じデザインワードでも毎回違う絵になるよう、生成のたびに次をランダムに決める。

- キャラクター案: 属性ごとに16案（人型＋精霊・幻獣など非人型）から選ぶ（以前はカード名のハッシュで固定）
- 構図・光・装飾・差し色（`pickVariation`）: 属性パレットは崩さず、カメラ位置・ライティング・細部装飾・差し色を足す
- 画像生成の `seed`: 毎回ランダム値を Replicate / Leonardo に渡す

## 制御軸

| 要素 | 制御軸 | 内容 |
|---|---|---|
| キャラクター像 | 属性（喜/怒/哀） | 黄金の英雄／深紅の戦士／藍色の魔導士 |
| 背景 | 属性 × レアリティ | N=単色グラデーション → UR=天空都市・浮島 |
| ポーズ | ステータス型（攻撃/防御/速度/バランス） | 前傾攻撃姿勢／盾構え／疾走／中央構え |
| トーン | **ユーザー選択（5種）** | cute / cool / dark / elegant / normal |
| デザインワード | **ユーザー選択（最大3語・100語辞書）** | 武器・相棒・オーラ・環境・特質の5スロットに自動配分 |
| 品質強調句 | レアリティ | N=なし → UR=「legendary epic masterpiece」 |

## トーン別スタイル句（`TONE_STYLE`）

| トーン | 内容 |
|---|---|
| cute | soft rounded features, gentle warm expression, pastel accents, charming kawaii-inspired |
| cool | sharp defined features, determined confident expression, high contrast dramatic lighting |
| dark | brooding mysterious atmosphere, deep shadows, smoldering gothic intensity |
| elegant | graceful refined posture, flowing ornate garments, noble aristocratic bearing |
| normal | balanced natural proportions, clean composition |

シードカード版は `cool` 固定（運営製の統一house style）だが、ユーザー創作版は
上記5種から選択できることで個性を出せる。

## デザインワード → スロット振り分けロジック

100語の日本語デザインワード辞書（`WORD_MAP`）は、各語に英語プロンプト句と
カテゴリ（`weapon` / `companion` / `power` / `nature` / `place` / `abstract`）が
紐づいている。ユーザーが選んだ語（最大3）はカテゴリ別バケツに振り分けられたのち、
以下の5スロットに **最大1〜2個ずつ** 割り当てられる（`buildDesignSlots`）。

| スロット | 由来カテゴリ | 割り当て数 | 使われ方 |
|---|---|---|---|
| weaponSlot | weapon | 最大1 | キャラクター描写に直接連結 |
| companionSlot | companion | 最大1 | キャラクター描写に直接連結 |
| auraSlot | power | 最大1 | 背景側に「〜energy aura」として付加 |
| envSlot | place（優先）→ nature | 最大1 | 背景側に「with 〜 in the scene」として付加 |
| traitSlot | abstract | 最大2 | キャラクター描写に直接連結 |

**優先順位の意図**: 同じカテゴリの語を複数選んでも先頭のみ採用され暴走を防ぐ。
`place` は `nature` より背景として具体性が高いため優先。

### デザインワード辞書の例（全100語、`WORD_MAP` より抜粋）

| カテゴリ | 日本語 | 英語プロンプト句 |
|---|---|---|
| weapon | 剣 | wielding a gleaming radiant sword |
| weapon | 盾 | holding an ornate glowing shield |
| companion | 龍 | with a majestic dragon companion |
| companion | 鳳凰 | with a magnificent phoenix rising behind |
| power | 炎 | with dancing flames around |
| power | 黄金 | encased in golden gleaming radiance |
| nature | 桜 | swirling cherry blossom petals |
| nature | オーロラ | under dazzling aurora borealis |
| place | 城 | grand fortress castle background |
| place | 玉座 | before an ornate glowing throne |
| abstract | 勇気 | exuding fierce courage |
| abstract | 神秘 | shrouded in mystical energy |

全100語は辞書分類: 自然・季節(19語) / 感情・心(19語) / 力・戦い(19語) /
動物・生物(20語) / 色・光(19語) / 時間・運命(10語)。完全なテーブルは
[generateCardImage.ts](generateCardImage.ts) の `WORD_MAP` を参照。

## 生成例

### 例1: 喜属性・SR・「剣」「龍」「勇気」を選択・toneはcool

**採用スロット**: weaponSlot=`wielding a gleaming radiant sword`,
companionSlot=`with a majestic dragon companion`, traitSlot=`exuding fierce courage`
（abstractは1語のみ選択のため1個採用）

**Prompt:**
```
radiant fantasy hero, golden glowing aura, warm smile, luminous flowing hair,
brilliant sun-motif armor, wielding a gleaming radiant sword, with a majestic
dragon companion, exuding fierce courage, embodying "黄金の剣士", aggressive
forward combat pose, weapon raised, explosive offensive energy burst, sharp
defined features, determined confident expression, high contrast dramatic
lighting, majestic golden palace, divine light rays through parting clouds,
holy atmosphere, warm golden amber sunlit color palette, bright vivid
contrast, highly detailed, cinematic dramatic lighting, rich textures,,
digital fantasy TCG card illustration, centered character portrait, vibrant
vivid colors, professional clean artwork, dramatic lighting, no text no
watermark no border
```

### 例2: 哀属性・R・「城」「桜」を選択・toneはelegant

**採用スロット**: envSlot=`桜`（natureだが place 語が無いため nature 側が採用）,
または「城」がplace → envSlot=`grand fortress castle background`（place優先）

**Prompt:**
```
serene ethereal mage, soft blue-violet glow, gentle melancholic eyes, midnight
robes adorned with silver stars, embodying "月下の詩人", firm protective
stance, shield raised, radiant barrier aura surrounding body, graceful refined
posture, flowing ornate garments, noble aristocratic bearing, moonlit
mystical lake, silver mist, ancient gnarled trees background, with grand
fortress castle background in the scene, midnight blue indigo moonlit silver
color palette, cool ethereal tones, detailed illustration, atmospheric
lighting,, digital fantasy TCG card illustration, centered character
portrait, vibrant vivid colors, professional clean artwork, dramatic
lighting, no text no watermark no border
```

> ⚠️ 既知の軽微な不具合（シードカード版と共通）: R以上の品質句末尾でカンマが二重になる
> （例: `atmospheric lighting,,`）。Flux生成への実害はないが要修正候補。

## Negative Prompt（全カード共通・シードカード版と同一）

```
text, words, letters, numbers, watermark, signature, card frame, border, UI,
HUD, ugly, blurry, low quality, deformed, mutated, malformed, extra limbs,
bad anatomy, extra fingers, duplicate, oversaturated, washed out
```

## 生成後の保存フロー

1. Replicate予測をポーリング（2秒間隔・最大15回試行=30秒でタイムアウト扱い）
2. 生成画像を取得しFirebase Storageへアップロード（`user_cards/{userId}/{timestamp}.png`）
3. `makePublic()`で公開URL化し、クライアントへ `{imageUrl, promptUsed}` を返却

## シードカード版との差分まとめ

| 項目 | シードカード版（`tools/seed_card_image_gen/`） | カード作成版（本ドキュメント） |
|---|---|---|
| 用途 | 運営製50枚の一括生成 | ユーザー創作カードの都度生成 |
| トーン | `cool` 固定 | 5種から選択可能 |
| デザインワード | なし | 100語辞書から最大3語選択 |
| 実行環境 | ローカルNode.jsツール（Replicate/Leonardo） | Firebase Cloud Functions（Replicateのみ） |
| 認証 | 不要（開発者ローカル実行） | Firebase Auth必須 |
| 保存先 | ローカル`output/`フォルダ | Firebase Storage（公開URL） |
