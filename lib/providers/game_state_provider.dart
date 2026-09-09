import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_card.dart';
import '../data/seed_cards_data.dart';
import 'auth_provider.dart';

// 全カード（シードカード→PlayCard変換）プロバイダー
final allPlayCardsProvider = Provider<List<PlayCard>>((ref) {
  return seedCardsData.map((sc) => PlayCard(
    cardId: sc.cardId,
    attribute: sc.attribute,
    cost: sc.cost,
    attackPower: sc.attackPower,
    defensePower: sc.defensePower,
    speed: sc.speed,
    nameJp: sc.nameJp,
    nameEn: sc.nameEn,
    imageUrl: sc.imageUrl,
    isSeedCard: true,
  )).toList();
});

// 防衛デッキ（5枚）
final defenseDeckProvider = StateProvider<List<PlayCard>>((ref) {
  // デフォルト：シードカードの最初の5枚
  final allCards = ref.read(allPlayCardsProvider);
  return allCards.take(5).toList();
});

// 攻撃デッキ選択中
final selectedAttackDeckProvider = StateProvider<List<PlayCard>>((ref) => []);

// 連勝/PvPボーナスの1日あたり合計獲得上限（コイン）
// UI文言「1日上限🪙２０」に対応する、実際に強制する側の定数
const int kDailyBonusCoinCap = 15;

// ジェムの使い道（機能ブースト）
// 連勝シールド: 敗北時に1個消費して連勝数のリセットを防ぐ
const int kStreakShieldGemCost = 3;
// 本日のデイリーボーナス上限を+20拡張する（1日に購入できる回数の上限あり）
const int kDailyBonusCapExtensionGemCost = 5;
const int kDailyBonusCapExtensionAmount = 20;
const int kDailyBonusCapExtensionMaxPerDay = 2;
// 本日のミッションセットを引き直す（未クレームの進捗は失われる）
const int kMissionRerollGemCost = 2;

// UTC時刻をJST（UTC+9）基準の yyyy-MM-dd 文字列に変換する
String _dateKeyJst(DateTime utcTime) {
  final jst = utcTime.add(const Duration(hours: 9));
  return '${jst.year.toString().padLeft(4, '0')}-'
      '${jst.month.toString().padLeft(2, '0')}-'
      '${jst.day.toString().padLeft(2, '0')}';
}

// JST（UTC+9）基準の「今日」を yyyy-MM-dd 文字列で返す
// 端末のタイムゾーン設定に依存せず日次リセットの境界を揃えるため
String todayKeyJst() => _dateKeyJst(DateTime.now().toUtc());

// JST基準の「昨日」を yyyy-MM-dd 文字列で返す（連続ログイン判定に使用）
String _yesterdayKeyJst() => _dateKeyJst(DateTime.now().toUtc().subtract(const Duration(days: 1)));

// ユーザーウォレット
class WalletState {
  final int totalPoints;
  final int todayPoints;
  final int todayWins;
  final int coinBalance;
  final int gemBalance;
  final int winStreak; // 連勝数
  final int dailyBonusCoinsEarned; // dailyBonusDate内で連勝/PvPボーナスにより獲得した累計コイン
  final String dailyBonusDate; // dailyBonusCoinsEarned が対応する日付（JST, yyyy-MM-dd）
  final int streakShieldCount; // 連勝シールドの所持数（ジェムで購入、敗北時に自動消費）
  final int dailyBonusCapExtra; // dailyBonusCapExtraDate内でジェム購入により拡張された当日の追加上限
  final String dailyBonusCapExtraDate; // dailyBonusCapExtra が対応する日付（JST, yyyy-MM-dd）
  final int loginStreak; // 連続ログイン日数（デイリーボーナスを連続で受け取った日数）
  final String lastLoginDate; // 直近にデイリーボーナスを受け取った日（JST, yyyy-MM-dd）。空文字=未受取

  const WalletState({
    this.totalPoints = 0,
    this.todayPoints = 0,
    this.todayWins = 0,
    this.coinBalance = 100,
    this.gemBalance = 0,
    this.winStreak = 0,
    this.dailyBonusCoinsEarned = 0,
    this.dailyBonusDate = '',
    this.streakShieldCount = 0,
    this.dailyBonusCapExtra = 0,
    this.dailyBonusCapExtraDate = '',
    this.loginStreak = 0,
    this.lastLoginDate = '',
  });

  WalletState copyWith({
    int? totalPoints,
    int? todayPoints,
    int? todayWins,
    int? coinBalance,
    int? gemBalance,
    int? winStreak,
    int? dailyBonusCoinsEarned,
    String? dailyBonusDate,
    int? streakShieldCount,
    int? dailyBonusCapExtra,
    String? dailyBonusCapExtraDate,
    int? loginStreak,
    String? lastLoginDate,
  }) =>
    WalletState(
      totalPoints: totalPoints ?? this.totalPoints,
      todayPoints: todayPoints ?? this.todayPoints,
      todayWins: todayWins ?? this.todayWins,
      coinBalance: coinBalance ?? this.coinBalance,
      gemBalance: gemBalance ?? this.gemBalance,
      winStreak: winStreak ?? this.winStreak,
      dailyBonusCoinsEarned: dailyBonusCoinsEarned ?? this.dailyBonusCoinsEarned,
      dailyBonusDate: dailyBonusDate ?? this.dailyBonusDate,
      streakShieldCount: streakShieldCount ?? this.streakShieldCount,
      dailyBonusCapExtra: dailyBonusCapExtra ?? this.dailyBonusCapExtra,
      dailyBonusCapExtraDate: dailyBonusCapExtraDate ?? this.dailyBonusCapExtraDate,
      loginStreak: loginStreak ?? this.loginStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
    );

  /// 連勝ボーナス: 3連勝=+5, 5連勝=+10, 7連勝+=+15
  int get streakBonus {
    if (winStreak >= 7) return 15;
    if (winStreak >= 5) return 10;
    if (winStreak >= 3) return 5;
    return 0;
  }

  // 今日のジェム購入による拡張分（他の日の値は無視する）
  int get _todayCapExtra => dailyBonusCapExtraDate == todayKeyJst() ? dailyBonusCapExtra : 0;

  // 今日すでに使った分を差し引いた、残りの1日ボーナス上限（ジェム拡張分・VIP加算分を含む）
  int remainingDailyBonusCap({bool isVip = false}) {
    final earnedToday = dailyBonusDate == todayKeyJst() ? dailyBonusCoinsEarned : 0;
    final cap = kDailyBonusCoinCap + _todayCapExtra + (isVip ? kVipDailyBonusCapBoost : 0);
    final remaining = cap - earnedToday;
    return remaining < 0 ? 0 : remaining;
  }

  // 本日すでにジェムで購入した上限拡張の回数（kDailyBonusCapExtensionMaxPerDayとの比較用）
  int get dailyBonusCapExtensionsUsedToday => _todayCapExtra ~/ kDailyBonusCapExtensionAmount;

  // 1日上限を考慮した上で、実際に獲得した後のウォレット状態を返す
  // 戻り値: （更新後のWalletState, 実際に加算されたコイン額）
  (WalletState, int) grantDailyBonus(int rawAmount, {bool isVip = false}) {
    if (rawAmount <= 0) return (this, 0);
    final today = todayKeyJst();
    final earnedToday = dailyBonusDate == today ? dailyBonusCoinsEarned : 0;
    final cap = kDailyBonusCoinCap + _todayCapExtra + (isVip ? kVipDailyBonusCapBoost : 0);
    final remaining = cap - earnedToday;
    final granted = rawAmount > remaining ? (remaining < 0 ? 0 : remaining) : rawAmount;
    if (granted <= 0) return (this, 0);
    return (
      copyWith(
        coinBalance: coinBalance + granted,
        dailyBonusCoinsEarned: earnedToday + granted,
        dailyBonusDate: today,
      ),
      granted,
    );
  }

  // ジェムで本日のデイリーボーナス上限を+kDailyBonusCapExtensionAmountする。
  // 呼び出し側でgemBalance/dailyBonusCapExtensionsUsedTodayの上限チェック済みであること。
  WalletState extendDailyBonusCap() {
    final today = todayKeyJst();
    return copyWith(
      gemBalance: gemBalance - kDailyBonusCapExtensionGemCost,
      dailyBonusCapExtra: _todayCapExtra + kDailyBonusCapExtensionAmount,
      dailyBonusCapExtraDate: today,
    );
  }

  // ジェムで連勝シールドを1個購入する。呼び出し側でgemBalanceの上限チェック済みであること。
  WalletState buyStreakShield() => copyWith(
        gemBalance: gemBalance - kStreakShieldGemCost,
        streakShieldCount: streakShieldCount + 1,
      );

  // 本日まだデイリーログインボーナスを受け取っていなければtrue。
  // これがfalseのままダイアログを出す/受取処理を呼ぶと、アプリ再起動のたびに
  // 何度でもコインを受け取れてしまう（かつてこの日付チェック自体が存在しなかった）。
  bool get canClaimDailyLogin => lastLoginDate != todayKeyJst();

  // 本日受け取った場合に表示すべき「Day」（1〜7）。7日サイクルで報酬テーブルを繰り返す。
  // 実際の付与はclaimDailyLogin()側で行う（このgetterは表示専用で状態を変えない）。
  int get pendingLoginStreakDay {
    final continuing = lastLoginDate == _yesterdayKeyJst();
    final nextStreak = continuing ? loginStreak + 1 : 1;
    return ((nextStreak - 1) % 7) + 1;
  }

  // デイリーログインボーナスを確定させる。前日から連続していればストリークを+1、
  // 途切れていれば1にリセットする。本日すでに受取済みなら何もせず自分自身を返す
  // （二重付与防止。呼び出し側でcanClaimDailyLoginを見てダイアログ表示を抑制すること）。
  WalletState claimDailyLogin(int coins) {
    if (!canClaimDailyLogin) return this;
    final continuing = lastLoginDate == _yesterdayKeyJst();
    return copyWith(
      coinBalance: coinBalance + coins,
      loginStreak: continuing ? loginStreak + 1 : 1,
      lastLoginDate: todayKeyJst(),
    );
  }

  Map<String, dynamic> toMap() => {
    'totalPoints': totalPoints,
    'todayPoints': todayPoints,
    'todayWins': todayWins,
    'coinBalance': coinBalance,
    'gemBalance': gemBalance,
    'winStreak': winStreak,
    'dailyBonusCoinsEarned': dailyBonusCoinsEarned,
    'dailyBonusDate': dailyBonusDate,
    'streakShieldCount': streakShieldCount,
    'dailyBonusCapExtra': dailyBonusCapExtra,
    'dailyBonusCapExtraDate': dailyBonusCapExtraDate,
    'loginStreak': loginStreak,
    'lastLoginDate': lastLoginDate,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory WalletState.fromMap(Map<String, dynamic> map) {
    return WalletState(
      totalPoints: map['totalPoints'] ?? 0,
      todayPoints: map['todayPoints'] ?? 0,
      todayWins: map['todayWins'] ?? 0,
      coinBalance: map['coinBalance'] ?? 100,
      gemBalance: map['gemBalance'] ?? 0,
      winStreak: map['winStreak'] ?? 0,
      dailyBonusCoinsEarned: map['dailyBonusCoinsEarned'] ?? 0,
      dailyBonusDate: map['dailyBonusDate'] ?? '',
      streakShieldCount: map['streakShieldCount'] ?? 0,
      dailyBonusCapExtra: map['dailyBonusCapExtra'] ?? 0,
      dailyBonusCapExtraDate: map['dailyBonusCapExtraDate'] ?? '',
      loginStreak: map['loginStreak'] ?? 0,
      lastLoginDate: map['lastLoginDate'] ?? '',
    );
  }
}

// ローカル状態管理用（既存）
final walletProvider = StateProvider<WalletState>((ref) => const WalletState());

// walletProviderをFirestoreの値で初期化済みのuid（未初期化はnull）。
// userWalletProviderがロードされるたびに毎回 walletProviderへ上書きすると、
// 対戦・課金などで直後に行ったローカルの楽観的更新を巻き戻してしまうため、
// 「同一ユーザーにつき1回だけ」ハイドレートするためのガードに使う。
final walletHydratedForUidProvider = StateProvider<String?>((ref) => null);

// Firestore統合版：ユーザーのウォレット
final userWalletProvider = FutureProvider<WalletState>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const WalletState();
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wallet')
        .doc('balance')
        .get();

    if (doc.exists) {
      return WalletState.fromMap(doc.data() ?? {});
    } else {
      // 初回作成
      final initialWallet = const WalletState();
      await doc.reference.set(initialWallet.toMap());
      return initialWallet;
    }
  } catch (e) {
    debugPrint('Error loading wallet: $e');
    return const WalletState();
  }
});

// 自分のPvPランク（レーティング・勝敗数・ティア）。
// pvpBattle Cloud Functionがusers/{uid}/rating/currentを更新する唱一の書き込み元。
// クライアント側には「勝利/敗北をローカルで反映する」ような更新手段を意図的に
// 置かない — かつてplayerRankProvider（ローカルStateProvider）がこの役割を
// 担っていたが、addWin()/addLoss()がどこからも呼ばれておらず、実際の対戦結果と
// 無関係にBronze/1000/0勝0敗のまま永久に固定表示されるバグになっていた。
final myPlayerRankProvider = FutureProvider<PlayerRank>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const PlayerRank();

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('rating')
        .doc('current')
        .get();
    final data = doc.data();
    if (data == null) return const PlayerRank();
    return PlayerRank.fromRating(
      (data['rating'] as int?) ?? 1000,
      wins: (data['wins'] as int?) ?? 0,
      losses: (data['losses'] as int?) ?? 0,
    );
  } catch (e) {
    debugPrint('Error loading player rank: $e');
    return const PlayerRank();
  }
});

// マッチング時のレーティングド参照用（myPlayerRankProviderと同じFirestore読み込みを再利用する）
final myRatingProvider = FutureProvider<int>((ref) async {
  final rank = await ref.watch(myPlayerRankProvider.future);
  return rank.rating;
});

// カード作成1回あたりのコイン消費量。選択したコスト（レアリティ帯 1〜5、
// ステータス予算 20/25/30/35/40 に対応）ごとに価格が変わる。
// 以前は全レアリティで完全に同額（100コイン）だったため、デッキ編成側に
// コストを消費する仏組み（マナ制限など）が無いのと相まって、常に最高レアリティ
// (cost=5)を選ぶこと以外に合理的な選択肢が存在しないバグになっていた。
// レア度が上がるほど「コインあたりの取得ステータス量」が下がる（＝レア度自体に
// プレミアムが付く）設計にしてあり、これは一般的なガチャゲームの経済設計に倦う。
const Map<int, int> kCardCreationCoinCostByTier = {
  1: 80,
  2: 120,
  3: 160,
  4: 220,
  5: 300,
};
// VIPパス加入者向け割引率（全レアリティ帯に一律適用）
const double kVipCardCreationDiscount = 0.2;

// VIPパス特典
const int kVipDailyBonusCapBoost = 10; // デイリーボーナス基本上限への上乗せ

int cardCreationCoinCost({required bool isVip, required int cost}) {
  final base = kCardCreationCoinCostByTier[cost] ?? kCardCreationCoinCostByTier[1]!;
  return isVip ? (base * (1 - kVipCardCreationDiscount)).round() : base;
}

// カード作成: パラメータ抽選（ガチャ）関連
const int kParamRerollCoinCost = 30; // 引き直し1回あたりのコイン消費量
const int kParamRerollMaxCount = 3; // 1回のカード作成で引き直せる最大回数
const double kParamBigHitChance = 0.12; // 「当たり」（予算上振れ）が出る確率
const double kParamBigHitBonusPercent = 0.15; // 当たり時の予算上乗せ率

// ウォレット更新関数
// 一時的なネットワーク断でコイン/ジェム付与（特に課金直後）が消えてしまわないよう、
// 数回リトライしてから諾める。呼び出し側は戻り値のbool（永続化に成功したか）を見て、
// 課金など重要な操作では失敗時にユーザーへ警告を出すこと。
Future<bool> updateWallet(String userId, WalletState wallet) async {
  const maxAttempts = 3;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .doc('balance')
          .set(wallet.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error updating wallet (attempt $attempt/$maxAttempts): $e');
      if (attempt == maxAttempts) return false;
      await Future.delayed(Duration(milliseconds: 300 * attempt));
    }
  }
  return false;
}

// プレイヤーランク
class PlayerRank {
  final int rating;
  final String tier;
  final int wins;
  final int losses;

  const PlayerRank({
    this.rating = 1000,
    this.tier = 'bronze',
    this.wins = 0,
    this.losses = 0,
  });

  // ratingからtierを自動算出してPlayerRankを組み立てる。レーティングの更新は
  // 必ずpvpBattle Cloud Function（サーバー側）でのみ行われるため、このクラスに
  // 「対戦結果をローカルで反映する」ような更新メソッドは意図的に持たせない。
  factory PlayerRank.fromRating(int rating, {int wins = 0, int losses = 0}) =>
      PlayerRank(rating: rating, tier: tierForRating(rating), wins: wins, losses: losses);

  String get tierLabel {
    switch (tier) {
      case 'bronze': return 'ブロンズ';
      case 'silver': return 'シルバー';
      case 'gold': return 'ゴールド';
      case 'platinum': return 'プラチナ';
      case 'diamond': return 'ダイヤモンド';
      default: return 'ブロンズ';
    }
  }

  String get tierEmoji {
    switch (tier) {
      case 'bronze': return '🥉';
      case 'silver': return '🥈';
      case 'gold': return '🥇';
      case 'platinum': return '💎';
      case 'diamond': return '👑';
      default: return '🥉';
    }
  }

  static String tierForRating(int r) {
    if (r >= 2100) return 'diamond';
    if (r >= 1800) return 'platinum';
    if (r >= 1500) return 'gold';
    if (r >= 1200) return 'silver';
    return 'bronze';
  }
}

// シードカード属性フィルター
final attributeFilterProvider = StateProvider<String?>((ref) => null);
