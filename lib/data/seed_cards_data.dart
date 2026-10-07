import '../models/seed_card.dart';

final seedCardsData = <SeedCard>[
  // 喜（Joy）C1（20pt）: 1枚
  SeedCard(
    cardId: 'joy_c1_001',
    attribute: 'joy',
    cost: 1,
    attackPower: 10,
    defensePower: 5,
    speed: 5,
    nameJp: '太陽の子',
    nameEn: 'Child of Sun',
    descriptionJp: '太陽のように明るい心',
    descriptionEn: 'Bright as the sun',
    imageUrl: 'assets/card_art/joy_c1_001.png',
  ),

  // 喜（Joy）C2（25pt）: 1枚
  SeedCard(
    cardId: 'joy_c2_001',
    attribute: 'joy',
    cost: 2,
    attackPower: 14,
    defensePower: 6,
    speed: 5,
    nameJp: '光の騎士',
    nameEn: 'Knight of Light',
    descriptionJp: '光を剣に変える勇者',
    descriptionEn: 'Warrior of light',
    imageUrl: 'assets/card_art/joy_c2_001.png',
  ),

  // 喜（Joy）C3（30pt）: 1枚
  SeedCard(
    cardId: 'joy_c3_001',
    attribute: 'joy',
    cost: 3,
    attackPower: 18,
    defensePower: 7,
    speed: 5,
    nameJp: '希望の君主',
    nameEn: 'Lord of Hope',
    descriptionJp: '希望を象徴する王',
    descriptionEn: 'King of hope',
    imageUrl: 'assets/card_art/joy_c3_001.png',
  ),

  // 喜（Joy）C4→R（25pt）: 1枚（シードカードはN/Rのみのため降格・ステータス縮小）
  SeedCard(
    cardId: 'joy_c4_001',
    attribute: 'joy',
    cost: 2,
    attackPower: 14,
    defensePower: 6,
    speed: 5,
    nameJp: '黄金の皇帝',
    nameEn: 'Golden Emperor',
    descriptionJp: '絶大な力と輝き',
    descriptionEn: 'Power and radiance',
    imageUrl: 'assets/card_art/joy_c4_001.png',
  ),

  // 喜（Joy）C5→N（20pt）: 1枚（シードカードはN/Rのみのため降格・ステータス縮小）
  SeedCard(
    cardId: 'joy_c5_001',
    attribute: 'joy',
    cost: 1,
    attackPower: 11,
    defensePower: 5,
    speed: 4,
    nameJp: '太陽神',
    nameEn: 'Sun God',
    descriptionJp: 'すべての光の源',
    descriptionEn: 'Source of all light',
    imageUrl: 'assets/card_art/joy_c5_001.png',
  ),

  // 怒（Anger）C1（20pt）: 1枚
  SeedCard(
    cardId: 'anger_c1_001',
    attribute: 'anger',
    cost: 1,
    attackPower: 10,
    defensePower: 5,
    speed: 5,
    nameJp: '炎の精',
    nameEn: 'Spirit of Fire',
    descriptionJp: '燃える怒りの象徴',
    descriptionEn: 'Symbol of burning rage',
    imageUrl: 'assets/card_art/anger_c1_001.png',
  ),

  // 怒（Anger）C2（25pt）: 1枚
  SeedCard(
    cardId: 'anger_c2_001',
    attribute: 'anger',
    cost: 2,
    attackPower: 14,
    defensePower: 6,
    speed: 5,
    nameJp: '怒りの王',
    nameEn: 'King of Anger',
    descriptionJp: '激しく力強い王',
    descriptionEn: 'Fierce and mighty',
    imageUrl: 'assets/card_art/anger_c2_001.png',
  ),

  // 怒（Anger）C3（30pt）: 1枚
  SeedCard(
    cardId: 'anger_c3_001',
    attribute: 'anger',
    cost: 3,
    attackPower: 20,
    defensePower: 6,
    speed: 4,
    nameJp: '怒りの王',
    nameEn: 'Anger King',
    descriptionJp: '全ての怒りを集める',
    descriptionEn: 'Gathers all rage',
    imageUrl: 'assets/card_art/anger_c3_001.png',
  ),

  // 怒（Anger）C4→R（25pt）: 1枚（シードカードはN/Rのみのため降格・ステータス縮小）
  SeedCard(
    cardId: 'anger_c4_001',
    attribute: 'anger',
    cost: 2,
    attackPower: 16,
    defensePower: 5,
    speed: 4,
    nameJp: '火の帝王',
    nameEn: 'Emperor of Fire',
    descriptionJp: '炎の全てを統べる',
    descriptionEn: 'Master of all flames',
    imageUrl: 'assets/card_art/anger_c4_001.png',
  ),

  // 怒（Anger）C5→N（20pt）: 1枚（シードカードはN/Rのみのため降格・ステータス縮小）
  SeedCard(
    cardId: 'anger_c5_001',
    attribute: 'anger',
    cost: 1,
    attackPower: 12,
    defensePower: 5,
    speed: 3,
    nameJp: '炎神',
    nameEn: 'Fire God',
    descriptionJp: '全ての炎の源',
    descriptionEn: 'Source of all fire',
    imageUrl: 'assets/card_art/anger_c5_001.png',
  ),

  // 哀（Sadness）C1（20pt）: 1枚
  SeedCard(
    cardId: 'sadness_c1_001',
    attribute: 'sadness',
    cost: 1,
    attackPower: 8,
    defensePower: 7,
    speed: 5,
    nameJp: '闇の精',
    nameEn: 'Spirit of Shadow',
    descriptionJp: '深き悲しみの化身',
    descriptionEn: 'Embodiment of sorrow',
    imageUrl: 'assets/card_art/sadness_c1_001.png',
  ),

  // 哀（Sadness）C2（25pt）: 1枚
  SeedCard(
    cardId: 'sadness_c2_001',
    attribute: 'sadness',
    cost: 2,
    attackPower: 12,
    defensePower: 8,
    speed: 5,
    nameJp: '悲しみの王',
    nameEn: 'King of Sadness',
    descriptionJp: '深き悲しみを統べる',
    descriptionEn: 'Master of sorrow',
    imageUrl: 'assets/card_art/sadness_c2_001.png',
  ),

  // 哀（Sadness）C3（30pt）: 1枚
  SeedCard(
    cardId: 'sadness_c3_001',
    attribute: 'sadness',
    cost: 3,
    attackPower: 8,
    defensePower: 18,
    speed: 4,
    nameJp: '悲しみの王',
    nameEn: 'Lord of Sorrow',
    descriptionJp: '全ての悲しみを受け入れる',
    descriptionEn: 'Accepts all sorrow',
    imageUrl: 'assets/card_art/sadness_c3_001.png',
  ),

  // 哀（Sadness）C4→R（25pt）: 1枚（シードカードはN/Rのみのため降格・ステータス縮小）
  SeedCard(
    cardId: 'sadness_c4_001',
    attribute: 'sadness',
    cost: 2,
    attackPower: 13,
    defensePower: 8,
    speed: 4,
    nameJp: '深淵の帝王',
    nameEn: 'Emperor of Abyss',
    descriptionJp: '深き淵の全てを統べる',
    descriptionEn: 'Master of the abyss',
    imageUrl: 'assets/card_art/sadness_c4_001.png',
  ),

  // 哀（Sadness）C5→N（20pt）: 1枚（シードカードはN/Rのみのため降格・ステータス縮小）
  SeedCard(
    cardId: 'sadness_c5_001',
    attribute: 'sadness',
    cost: 1,
    attackPower: 10,
    defensePower: 7,
    speed: 3,
    nameJp: '夜神',
    nameEn: 'God of Night',
    descriptionJp: '全ての暗黒の源',
    descriptionEn: 'Source of all darkness',
    imageUrl: 'assets/card_art/sadness_c5_001.png',
  ),
];
