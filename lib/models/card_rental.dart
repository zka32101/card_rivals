import 'card_name.dart';

class CardPopularityScore {
  final String cardId;
  final String cardName; // 日本語名（無ければ英語名）
  final String cardNameEn;
  final String creatorId;
  final String creatorName;
  final String attribute;
  final int cost;

  final int totalUsageCount;
  final int totalRentalCount;
  final int totalBattlesWithCard;
  final int totalWinsWithCard;
  final double winRate;
  final int totalEarnings;

  final double popularityScore;
  final int rank;
  final DateTime lastUpdated;

  CardPopularityScore({
    required this.cardId,
    required this.cardName,
    this.cardNameEn = '',
    required this.creatorId,
    required this.creatorName,
    required this.attribute,
    required this.cost,
    required this.totalUsageCount,
    required this.totalRentalCount,
    required this.totalBattlesWithCard,
    required this.totalWinsWithCard,
    required this.winRate,
    required this.totalEarnings,
    required this.popularityScore,
    this.rank = 0,
    required this.lastUpdated,
  });

  /// 表示言語に合わせたカード名（英語名が無ければ元の名前）
  String nameFor(String lang) => pickCardName(lang, jp: cardName, en: cardNameEn);

  // レンタル回数で進化するオーナーカードのレベル（0=無印, 1〜3=進化段階）
  // しきい値: 5回=Lv1, 15回=Lv2, 30回=Lv3
  int get evolutionLevel {
    if (totalRentalCount >= 30) return 3;
    if (totalRentalCount >= 15) return 2;
    if (totalRentalCount >= 5) return 1;
    return 0;
  }

  int get rentalsUntilNextEvolution {
    const thresholds = [5, 15, 30];
    for (final t in thresholds) {
      if (totalRentalCount < t) return t - totalRentalCount;
    }
    return 0; // 最大進化済み
  }

  String get evolutionBadge => switch (evolutionLevel) {
    1 => '✨Lv.1',
    2 => '💫Lv.2',
    3 => '🌟Lv.3',
    _ => '',
  };

  String get attributeEmoji => switch (attribute) {
    'joy' => '☀️',
    'anger' => '🔥',
    'sadness' => '🌙',
    _ => '⭐',
  };
}
