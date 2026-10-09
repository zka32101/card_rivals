// デザイン言葉・カテゴリの英語表示ラベル。
// キー（日本語）はサーバー(WORD_MAP)と保存データで使う値なので変更しない。
// ここは「画面に出す名前」だけを英語化する。
const Map<String, String> kCardDesignWordLabelsEn = {
  // 自然・季節
  '桜': 'Cherry Blossom', '月': 'Moon', '星': 'Star', '雪': 'Snow', '炎': 'Flame',
  '風': 'Wind', '雨': 'Rain', '海': 'Sea', '山': 'Mountain', '森': 'Forest',
  '花': 'Flower', '太陽': 'Sun', '雲': 'Cloud', '雷': 'Thunder', '虹': 'Rainbow',
  '波': 'Wave', '砂漠': 'Desert', '滝': 'Waterfall', '峰': 'Peak', '谷': 'Valley',
  '氷河': 'Glacier', '朝霧': 'Morning Mist', '大地': 'Earth', '嵐': 'Storm',
  '流星': 'Meteor', '極光': 'Aurora', '潮騒': 'Sea Murmur', '新緑': 'Fresh Green',
  '紅葉': 'Autumn Leaves', '氷晶': 'Ice Crystal',
  // 感情・心
  '喜び': 'Joy', '勇気': 'Courage', '希望': 'Hope', '愛': 'Love', '誇り': 'Pride',
  '幸福': 'Happiness', '輝き': 'Radiance', '温暖': 'Warmth', '優雅': 'Elegance',
  '神秘': 'Mystery', '静寂': 'Silence', '深淵': 'Abyss', '炎心': 'Fiery Heart',
  '鋼鉄': 'Steel', '柔和': 'Gentleness', '清廉': 'Integrity', '純潔': 'Purity',
  '雄大': 'Grandeur', '優美': 'Grace', '荘厳': 'Majesty', '哀愁': 'Melancholy',
  '慈愛': 'Compassion', '執念': 'Tenacity', '情熱': 'Passion', '安らぎ': 'Serenity',
  '孤高': 'Solitude', '覚悟': 'Resolve', '憧憬': 'Longing', '慟哭': 'Wailing',
  '祈り': 'Prayer',
  // 力・戦い
  '剣': 'Sword', '盾': 'Shield', '槍': 'Spear', '弓': 'Bow', '戦士': 'Warrior',
  '騎士': 'Knight', '将軍': 'General', '王冠': 'Crown', '玉座': 'Throne', '城': 'Castle',
  '力': 'Power', '闘志': 'Fighting Spirit', '勝利': 'Victory', '征服': 'Conquest',
  '無敵': 'Invincible', '覇者': 'Conqueror', '英雄': 'Hero', '伝説': 'Legend',
  '神話': 'Myth', '栄光': 'Glory', '軍旗': 'War Banner', '要塞': 'Fortress',
  '刃': 'Blade', '鎧': 'Armor', '戦場': 'Battlefield', '守護': 'Guardian',
  '反逆': 'Rebellion', '進撃': 'Onslaught', '雄叫び': 'Battle Cry', '不屈': 'Unyielding',
  // 動物・生物
  '龍': 'Dragon', '鷲': 'Eagle', '獅子': 'Lion', '虎': 'Tiger', '熊': 'Bear',
  '狼': 'Wolf', '鹿': 'Deer', '馬': 'Horse', '象': 'Elephant', '鮫': 'Shark',
  '鷹': 'Hawk', '鶴': 'Crane', '蛇': 'Serpent', '猫': 'Cat', '犬': 'Dog',
  '鳳凰': 'Phoenix', 'ユニコーン': 'Unicorn', 'グリフォン': 'Griffin', '鬼': 'Oni',
  '天使': 'Angel', '悪魔': 'Demon', '麒麟': 'Qilin', '梟': 'Owl', '蝶': 'Butterfly',
  '蜘蛛': 'Spider', '亀': 'Turtle', '狐': 'Fox', '兎': 'Rabbit', '海竜': 'Sea Dragon',
  '精霊': 'Spirit',
  // 色・光
  '金': 'Gold', '銀': 'Silver', '青': 'Blue', '紅': 'Crimson', '紫': 'Purple',
  '緑': 'Green', '黒': 'Black', '白': 'White', '虹色': 'Rainbow Hue', 'オーロラ': 'Aurora Borealis',
  '光': 'Light', '影': 'Shadow', '煌き': 'Sparkle', '暗黒': 'Darkness', '真紅': 'Scarlet',
  '藍': 'Indigo', '翠': 'Emerald', '黄金': 'Golden', '白銀': 'Platinum',
  '漆黒': 'Jet Black', '乳白': 'Milky White', '瑠璃': 'Lapis', '琥珀': 'Amber',
  '緋色': 'Vermilion', '群青': 'Ultramarine', '銀河': 'Galaxy', '夜光': 'Night Glow',
  '薄明': 'Twilight', '残光': 'Afterglow',
  // 時間・運命
  '時間': 'Time', '永遠': 'Eternity', '運命': 'Fate', '未来': 'Future', '過去': 'Past',
  '今': 'Now', '刹那': 'Instant', '輪廻': 'Samsara', '因果': 'Karma', '宿命': 'Destiny',
  '黎明': 'Dawn', '黄昏': 'Dusk', '終焉': 'The End', '始まり': 'Beginning',
  '記憶': 'Memory', '約束': 'Promise', '奇跡': 'Miracle', '転生': 'Reincarnation',
  '予兆': 'Omen', '継承': 'Legacy',
};

const Map<String, String> kCardDesignCategoryLabelsEn = {
  '自然・季節': 'Nature & Seasons',
  '感情・心': 'Emotion & Heart',
  '力・戦い': 'Power & Battle',
  '動物・生物': 'Creatures',
  '色・光': 'Color & Light',
  '時間・運命': 'Time & Fate',
};

/// 表示用ラベル。英語ロケールのときだけ英訳、未登録語は原文を返す。
String designWordLabel(String word, String languageCode) =>
    languageCode == 'en' ? (kCardDesignWordLabelsEn[word] ?? word) : word;

String designCategoryLabel(String category, String languageCode) =>
    languageCode == 'en' ? (kCardDesignCategoryLabelsEn[category] ?? category) : category;
