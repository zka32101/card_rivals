import 'package:cloud_firestore/cloud_firestore.dart';

// カード育成（特訓）システム
// レベルはcopyWith可能な進捗値としてFirestoreに保存し、実数値への反映は
// 表示・対戦の両方で必ずこの関数を通す（クライアント/サーバーで計算式を揃えるため、
// functions/src配下にも同じ定数・式を複製している）。
const int kMaxCardLevel = 5;
const int kCardLevelAttackBonus = 2;
const int kCardLevelDefenseBonus = 2;
const int kCardLevelSpeedBonus = 1;

// currentLevel（0〜4）から次のレベルへ特訓するのに必要なコイン数
int cardLevelUpCost(int currentLevel) => 50 * (currentLevel + 1);

class UserCard {
  final String cardId;
  final String userId;
  final String attribute; // "joy", "anger", "sadness"
  final int cost;
  final int attackPower;
  final int defensePower;
  final int speed;
  final Map<String, String> cardName; // {"jp": "...", "en": "..."}
  final Map<String, String> cardDescription;
  final String imageUrl;
  final String imagePromptUsed;
  final int bonusPointsEarned;
  final int totalVictoriesWithCard;
  final int todayVictoriesCount;
  final int wins;
  final int losses;
  final Timestamp createdAt;
  // 共同創作: もう一人のクリエイター（null = 単独創作）
  final String? coCreatorId;
  final String? coCreatorName;
  // 特訓レベル（0〜kMaxCardLevel）。実際のバトル用ステータスは
  // attackPower/defensePower/speed（作成時の基礎値）にレベルボーナスを
  // 加算したもの — leveledAttackPower等を使うこと。
  final int level;
  // レンタル一覧に公開しているか（trueの間、他ユーザーが人気度ランキングから閲覧・レンタルできる）
  final bool isPublic;
  // レンタル料金（表示専用の参考値。実際の請求額はレンタル日数プラン
  // ×rentCard Cloud Function側の固定テーブルで決まる — lib/screens/popular_cards_screen.dart
  // の_rentalPlansと同じ値を使う。将来、日数プランをこの値ベースに変える余地を残すため保持）
  final int rentalCostPerDay;
  // 累計レンタル回数・累計レンタル収益（rentCard Cloud FunctionがAdmin SDK経由で更新する）
  final int totalRentalCount;
  final int totalRentalEarnings;

  UserCard({
    required this.cardId,
    required this.userId,
    required this.attribute,
    required this.cost,
    required this.attackPower,
    required this.defensePower,
    required this.speed,
    required this.cardName,
    required this.cardDescription,
    this.imageUrl = '',
    this.imagePromptUsed = '',
    this.bonusPointsEarned = 0,
    this.totalVictoriesWithCard = 0,
    this.todayVictoriesCount = 0,
    this.wins = 0,
    this.losses = 0,
    required this.createdAt,
    this.coCreatorId,
    this.coCreatorName,
    this.level = 0,
    this.isPublic = false,
    this.rentalCostPerDay = 50,
    this.totalRentalCount = 0,
    this.totalRentalEarnings = 0,
  });

  String get nameJp => cardName['jp'] ?? '';
  String get nameEn => cardName['en'] ?? '';
  bool get isCoCreated => coCreatorId != null && coCreatorId!.isNotEmpty;

  int get leveledAttackPower => attackPower + level * kCardLevelAttackBonus;
  int get leveledDefensePower => defensePower + level * kCardLevelDefenseBonus;
  int get leveledSpeed => speed + level * kCardLevelSpeedBonus;

  String getCardType() {
    final params = [attackPower, defensePower, speed];
    final max = params.reduce((a, b) => a > b ? a : b);
    if (attackPower == max && attackPower > defensePower && attackPower > speed) return 'attack';
    if (defensePower == max && defensePower > attackPower && defensePower > speed) return 'defense';
    if (speed == max && speed > attackPower && speed > defensePower) return 'speed';
    return 'balance';
  }

  double get winRate => (wins + losses) == 0 ? 0 : wins / (wins + losses);

  Map<String, dynamic> toMap() => {
    'cardId': cardId,
    'userId': userId,
    'attribute': attribute,
    'cost': cost,
    'attackPower': attackPower,
    'defensePower': defensePower,
    'speed': speed,
    'cardName': cardName,
    'cardDescription': cardDescription,
    'imageUrl': imageUrl,
    'imagePromptUsed': imagePromptUsed,
    'bonusPointsEarned': bonusPointsEarned,
    'totalVictoriesWithCard': totalVictoriesWithCard,
    'todayVictoriesCount': todayVictoriesCount,
    'wins': wins,
    'losses': losses,
    'createdAt': createdAt,
    'coCreatorId': coCreatorId,
    'coCreatorName': coCreatorName,
    'level': level,
    'isPublic': isPublic,
    'rentalCostPerDay': rentalCostPerDay,
    'totalRentalCount': totalRentalCount,
    'totalRentalEarnings': totalRentalEarnings,
  };

  factory UserCard.fromMap(Map<String, dynamic> map) => UserCard(
    cardId: map['cardId'] ?? '',
    userId: map['userId'] ?? '',
    attribute: map['attribute'] ?? 'joy',
    cost: map['cost'] ?? 1,
    attackPower: map['attackPower'] ?? 0,
    defensePower: map['defensePower'] ?? 0,
    speed: map['speed'] ?? 0,
    cardName: Map<String, String>.from(map['cardName'] ?? {'jp': '', 'en': ''}),
    cardDescription: Map<String, String>.from(map['cardDescription'] ?? {'jp': '', 'en': ''}),
    imageUrl: map['imageUrl'] ?? '',
    imagePromptUsed: map['imagePromptUsed'] ?? '',
    bonusPointsEarned: map['bonusPointsEarned'] ?? 0,
    totalVictoriesWithCard: map['totalVictoriesWithCard'] ?? 0,
    todayVictoriesCount: map['todayVictoriesCount'] ?? 0,
    wins: map['wins'] ?? 0,
    losses: map['losses'] ?? 0,
    createdAt: map['createdAt'] ?? Timestamp.now(),
    coCreatorId: map['coCreatorId'],
    coCreatorName: map['coCreatorName'],
    level: map['level'] ?? 0,
    isPublic: map['isPublic'] ?? false,
    rentalCostPerDay: map['rentalCostPerDay'] ?? 50,
    totalRentalCount: map['totalRentalCount'] ?? 0,
    totalRentalEarnings: map['totalRentalEarnings'] ?? 0,
  );

  UserCard copyWith({
    String? imageUrl,
    Map<String, String>? cardName,
    int? wins,
    int? losses,
    int? bonusPointsEarned,
    int? totalVictoriesWithCard,
    int? todayVictoriesCount,
    int? level,
    bool? isPublic,
    int? rentalCostPerDay,
    int? totalRentalCount,
    int? totalRentalEarnings,
  }) {
    return UserCard(
      cardId: cardId,
      userId: userId,
      attribute: attribute,
      cost: cost,
      attackPower: attackPower,
      defensePower: defensePower,
      speed: speed,
      cardName: cardName ?? this.cardName,
      cardDescription: cardDescription,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePromptUsed: imagePromptUsed,
      bonusPointsEarned: bonusPointsEarned ?? this.bonusPointsEarned,
      totalVictoriesWithCard: totalVictoriesWithCard ?? this.totalVictoriesWithCard,
      todayVictoriesCount: todayVictoriesCount ?? this.todayVictoriesCount,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      createdAt: createdAt,
      coCreatorId: coCreatorId,
      coCreatorName: coCreatorName,
      level: level ?? this.level,
      isPublic: isPublic ?? this.isPublic,
      rentalCostPerDay: rentalCostPerDay ?? this.rentalCostPerDay,
      totalRentalCount: totalRentalCount ?? this.totalRentalCount,
      totalRentalEarnings: totalRentalEarnings ?? this.totalRentalEarnings,
    );
  }

  // バトル・表示で扱う統一形式(PlayCard)へ変換する。レベルボーナスを織り込んだ
  // 実数値をそのままPlayCard.attackPower等に反映する。
  PlayCard toPlayCard() => PlayCard(
        cardId: cardId,
        attribute: attribute,
        cost: cost,
        attackPower: leveledAttackPower,
        defensePower: leveledDefensePower,
        speed: leveledSpeed,
        nameJp: nameJp,
        nameEn: nameEn,
        imageUrl: imageUrl,
        isSeedCard: false,
        coCreatorName: coCreatorName,
        level: level,
      );
}

// カードレアリティ
enum CardRarity { n, r, sr, ur }

// ユーザーとシードカード両方を統一的に扱う抽象カード
class PlayCard {
  final String cardId;
  final String attribute;
  final int cost;
  final int attackPower;
  final int defensePower;
  final int speed;
  final String nameJp;
  final String nameEn;
  final String imageUrl;
  final bool isSeedCard;
  // 共同創作: もう一人のクリエイター名（null = 単独創作）
  final String? coCreatorName;
  // 特訓レベル（シードカードは常に0。attackPower等には既にレベルボーナスが
  // 織り込み済みで、この値は表示専用）
  final int level;
  // レンタル中のカードか（他ユーザーから期間限定で借りているカード）。
  // trueの場合、cardIdは自分のcards/rentalsではなく貸し手のカードIDを指す —
  // battleEligibleCardsProvider（collection_provider.dart）が有効なレンタル記録から
  // 生成するもので、通常はこのフラグを手動でtrueにしない。
  final bool isRented;

  PlayCard({
    required this.cardId,
    required this.attribute,
    required this.cost,
    required this.attackPower,
    required this.defensePower,
    required this.speed,
    required this.nameJp,
    this.nameEn = '',
    this.imageUrl = '',
    this.isSeedCard = true,
    this.coCreatorName,
    this.level = 0,
    this.isRented = false,
  });

  bool get isCoCreated => coCreatorName != null && coCreatorName!.isNotEmpty;

  CardRarity get rarity => switch (cost) {
    1 => CardRarity.n,
    2 => CardRarity.r,
    3 => CardRarity.r,
    4 => CardRarity.sr,
    _ => CardRarity.ur,
  };

  String get rarityLabel => switch (rarity) {
    CardRarity.n => 'N',
    CardRarity.r => 'R',
    CardRarity.sr => 'SR',
    CardRarity.ur => 'UR',
  };

  String getCardType() {
    final params = [attackPower, defensePower, speed];
    final max = params.reduce((a, b) => a > b ? a : b);
    if (attackPower == max && attackPower > defensePower && attackPower > speed) return 'attack';
    if (defensePower == max && defensePower > attackPower && defensePower > speed) return 'defense';
    if (speed == max && speed > attackPower && speed > defensePower) return 'speed';
    return 'balance';
  }

}
