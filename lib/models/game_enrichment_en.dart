// バッジ/実績の英語表示ラベル（id キーで引く。idと保存データは変えない）。
import 'game_enrichment.dart';

const Map<String, (String, String)> _badgeEn = {
  'first_victory': ('First Victory', 'Win your first PvP battle'),
  'first_card_created': ('Card Crafter', 'Create your first card'),
  'ten_victories': ('Ten Wins', 'Win 10 or more PvP battles'),
  'fifty_victories': ('Fifty Wins', 'Win 50 or more PvP battles'),
  'hundred_victories': ('Hundred Wins', 'Win 100 or more PvP battles'),
  'bronze_rank': ('Bronze Rank', 'Reach 500 ELO'),
  'silver_rank': ('Silver Medal', 'Reach 1000 ELO'),
  'gold_rank': ('Gold Medal', 'Reach 1500 ELO'),
  'platinum_rank': ('Platinum Rank', 'Reach 2000 ELO'),
  'diamond_rank': ('Diamond Rank', 'Reach 2500 ELO'),
  'five_cards': ('Card Collector', 'Create 5 cards'),
  'all_attributes': ('Attribute Master', 'Create cards of all 3 attributes'),
  'seven_day_streak': ('Daily Player', 'Play 7 days in a row'),
  'thirty_day_streak': ('Veteran', 'Play 30 days in a row'),
  'comeback_win': ('Big Comeback', 'Win from 1 HP'),
  'perfect_victory': ('Flawless Victory', 'Win without taking damage'),
};

const Map<String, (String, String)> _achievementEn = {
  'win_10': ('10 Wins', 'Win 10 PvP battles'),
  'win_50': ('50 Wins', 'Win 50 PvP battles'),
  'rating_1000': ('ELO 1000', 'Reach an ELO rating of 1000'),
  'rating_1500': ('ELO 1500', 'Reach an ELO rating of 1500'),
  'cards_5': ('5 Cards', 'Create 5 cards'),
  'streak_7': ('7-Day Streak', 'Battle 7 days in a row'),
};

String badgeNameFor(Badge b, String lang) =>
    lang == 'en' ? (_badgeEn[b.id]?.$1 ?? b.name) : b.name;
String badgeDescriptionFor(Badge b, String lang) =>
    lang == 'en' ? (_badgeEn[b.id]?.$2 ?? b.description) : b.description;
String achievementTitleFor(AchievementProgress a, String lang) =>
    lang == 'en' ? (_achievementEn[a.id]?.$1 ?? a.title) : a.title;
String achievementDescriptionFor(AchievementProgress a, String lang) =>
    lang == 'en' ? (_achievementEn[a.id]?.$2 ?? a.description) : a.description;

const Map<String, String> _achievementBadge = {
  'win_10': 'ten_victories',
  'win_50': 'fifty_victories',
  'rating_1000': 'silver_rank',
  'rating_1500': 'gold_rank',
  'cards_5': 'five_cards',
  'streak_7': 'seven_day_streak',
};

/// 実績の報酬表示（例: 'バッジ: 十勝士 🥈' → 'Badge: Ten Wins 🥈'）。
String achievementRewardFor(AchievementProgress a, String lang) {
  final r = a.reward;
  if (r == null || lang != 'en') return r ?? '';
  final name = _badgeEn[_achievementBadge[a.id]]?.$1;
  if (name == null) return r;
  final emoji = r.split(' ').last;
  return 'Badge: $name $emoji';
}
