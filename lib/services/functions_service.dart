import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Cloud Functions呼び出しの薄いラッパー。実機では従来どおり FirebaseFunctions を呼ぶ。
/// テストでは [FunctionsService.debugHandler] を差し替えるとサーバー関数なしで動かせる。
class _Functions {
  const _Functions();
  _Callable httpsCallable(String name, {HttpsCallableOptions? options}) => _Callable(name, options);
}

class _CallResult {
  final dynamic data;
  const _CallResult(this.data);
}

class _Callable {
  final String name;
  final HttpsCallableOptions? options;
  const _Callable(this.name, this.options);

  Future<_CallResult> call(Map<String, dynamic> params) async {
    final handler = FunctionsService.debugHandler;
    if (handler != null) return _CallResult(await handler(name, params));
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1').httpsCallable(name, options: options);
    return _CallResult((await callable.call(params)).data);
  }
}

class FunctionsService {
  /// テスト専用: 関数名と引数を受け取り、サーバーの戻り値(data)を返す/例外を投げる。
  @visibleForTesting
  static Future<dynamic> Function(String name, Map<String, dynamic> params)? debugHandler;

  static const _functions = _Functions();

  // カード名生成（Claude Haiku）
  static Future<List<String>> generateCardName({
    required String attribute,
    required int cost,
    required int attack,
    required int defense,
    required int speed,
    required String tone,
    String language = 'ja', // 'ja' | 'en'（英語表示のときは英語のカード名を生成）
  }) async {
    final callable = _functions.httpsCallable('generateCardName');
    final result = await callable.call({
      'attribute': attribute,
      'cost': cost,
      'attack': attack,
      'defense': defense,
      'speed': speed,
      'tone': tone,
      'language': language,
    });
    final names = List<String>.from(result.data['names'] as List);
    return names;
  }

  // カード画像生成（Replicate Flux）
  // rarity: "n" | "r" | "sr" | "ur"
  // designWords: 3つのデザイン言葉
  // tone: "cute" | "cool" | "dark" | "elegant" | "normal"
  static Future<String> generateCardImage({
    required String attribute,
    required String cardName,
    required String cardType,
    required String rarity,
    required List<String> designWords,
    required String tone,
  }) async {
    final callable = _functions.httpsCallable(
      'generateCardImage',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final result = await callable.call({
      'attribute': attribute,
      'cardName': cardName,
      'cardType': cardType,
      'rarity': rarity,
      'designWords': designWords,
      'tone': tone,
    });
    return result.data['imageUrl'] as String;
  }

  // PvPマッチング
  static Future<Map<String, dynamic>> pvpMatch(int attackerRating) async {
    final callable = _functions.httpsCallable('pvpMatch');
    final result = await callable.call({'attackerRating': attackerRating});
    return Map<String, dynamic>.from(result.data as Map);
  }

  // PvPバトル実行（サーバーサイド・改ざん防止のため結果はサーバーで再計算される）
  // カードの実数値・対戦相手デッキ・属性移住ボーナスは全てサーバー側の正本データから
  // 解決されるため、ここではcardIdとpvpMatchが発行したmatchIdのみを送る。
  static Future<Map<String, dynamic>> pvpBattle({
    required String matchId,
    required List<String> attackerDeckCardIds,
  }) async {
    final callable = _functions.httpsCallable(
      'pvpBattle',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call({
      'matchId': matchId,
      'attackerDeckCardIds': attackerDeckCardIds,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // カードレンタル（サーバーサイド・借り手のコイン減算とクリエイターへの収益付与を
  // アトミックに行う。2ユーザー間の通貨移動のためクライアントの直接Firestore書き込みは
  // 許可していない）
  static Future<Map<String, dynamic>> rentCard({
    required String cardId,
    required String creatorId,
    required int rentalDays,
  }) async {
    final callable = _functions.httpsCallable('rentCard');
    final result = await callable.call({
      'cardId': cardId,
      'creatorId': creatorId,
      'rentalDays': rentalDays,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // ===== Marketplace Functions =====

  /// Create a card listing for sale
  static Future<Map<String, dynamic>> createCardListing({
    required String cardId,
    required int price,
  }) async {
    final callable = _functions.httpsCallable('createCardListing');
    final result = await callable.call({
      'cardId': cardId,
      'price': price,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Buy a card from marketplace
  static Future<Map<String, dynamic>> buyCard({
    required String listingId,
  }) async {
    final callable = _functions.httpsCallable('buyCard');
    final result = await callable.call({'listingId': listingId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Delist a card from marketplace
  static Future<Map<String, dynamic>> delistCard({
    required String listingId,
  }) async {
    final callable = _functions.httpsCallable('delistCard');
    final result = await callable.call({'listingId': listingId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Update price of a card listing
  static Future<Map<String, dynamic>> updateCardListing({
    required String listingId,
    required int newPrice,
  }) async {
    final callable = _functions.httpsCallable('updateCardListing');
    final result = await callable.call({
      'listingId': listingId,
      'newPrice': newPrice,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Create a trade offer
  static Future<Map<String, dynamic>> createTradeOffer({
    required String recipientId,
    required List<String> senderCardIds,
    required List<String> recipientCardIds,
    String? message,
  }) async {
    final callable = _functions.httpsCallable('createTradeOffer');
    final result = await callable.call({
      'recipientId': recipientId,
      'senderCardIds': senderCardIds,
      'recipientCardIds': recipientCardIds,
      'message': message,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Respond to a trade offer
  static Future<Map<String, dynamic>> respondToTradeOffer({
    required String offerId,
    required String action,
  }) async {
    final callable = _functions.httpsCallable('respondToTradeOffer');
    final result = await callable.call({
      'offerId': offerId,
      'action': action,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Cancel a trade offer
  static Future<Map<String, dynamic>> cancelTradeOffer({
    required String offerId,
  }) async {
    final callable = _functions.httpsCallable('cancelTradeOffer');
    final result = await callable.call({'offerId': offerId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Fill a currency listing
  static Future<Map<String, dynamic>> fillCurrencyListing({
    required String listingId,
    int? amount,
  }) async {
    final callable = _functions.httpsCallable('fillCurrencyListing');
    final result = await callable.call({
      'listingId': listingId,
      if (amount != null) 'amount': amount,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // カード作成（サーバーサイド・予算範囲チェックとコイン消費をアトミックに行う。
  // ステータス値はcard_creation_screen_v2.dartのガチャ演出が生成しうる範囲を
  // 超えていると拒否される。レア度(cost)はクライアントには選ばせず、サーバー側の
  // ガチャ抽選のみで決まる（戻り値のcostが実際に付与されたレア度）。
  // attackPower/defensePower/speedはpvpBattleの実ダメージ計算にそのまま使われる
  // ため、クライアントの直接Firestore書き込みは許可していない）
  static Future<Map<String, dynamic>> createCard({
    required String attribute,
    required int attackPower,
    required int defensePower,
    required int speed,
    required String cardNameJp,
    String? cardNameEn,
    String? imageUrl,
    String? coCreatorName,
    required bool isVip,
  }) async {
    final callable = _functions.httpsCallable('createCard');
    final result = await callable.call({
      'attribute': attribute,
      'attackPower': attackPower,
      'defensePower': defensePower,
      'speed': speed,
      'cardNameJp': cardNameJp,
      if (cardNameEn != null) 'cardNameEn': cardNameEn,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (coCreatorName != null) 'coCreatorName': coCreatorName,
      'isVip': isVip,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // カード特訓・レベルアップ（サーバーサイド・レベル上限とコイン消費を検証してから
  // アトミックに+1する。levelもpvpBattleの実ダメージ計算に使われるため同様の理由で
  // クライアントの直接Firestore書き込みは許可していない）
  static Future<Map<String, dynamic>> levelUpCard({required String cardId}) async {
    final callable = _functions.httpsCallable('levelUpCard');
    final result = await callable.call({'cardId': cardId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  // シーズンリワード請求（サーバーサイド・ランク到達判定とジェム/コイン付与を
  // アトミックに行う。unlockedRewardsはpvpBattle同様クライアントの直接書き込みを
  // 許可していないため、必ずこのCloud Function経由で行う）
  static Future<Map<String, dynamic>> claimSeasonReward({
    required String seasonId,
    required String rewardId,
  }) async {
    final callable = _functions.httpsCallable('claimSeasonReward');
    final result = await callable.call({
      'seasonId': seasonId,
      'rewardId': rewardId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // シーズンランキング取得（サーバーサイド集計。クライアントからusersコレクションを
  // 横断読み取りする権限は無いため、Admin SDK経由でこのCloud Functionが代行する）
  static Future<Map<String, dynamic>> getSeasonLeaderboard({required String seasonId}) async {
    final callable = _functions.httpsCallable('getSeasonLeaderboard');
    final result = await callable.call({'seasonId': seasonId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  // 全期間/日次/週次/月次ランキング取得（サーバーサイド集計。
  // periodTypeは 'allTime' | 'daily' | 'weekly' | 'monthly'）
  // 属性別は periodType='attribute' + attribute('joy'|'anger'|'sadness')。
  static Future<Map<String, dynamic>> getPeriodLeaderboard({required String periodType, String? attribute}) async {
    final callable = _functions.httpsCallable('getPeriodLeaderboard');
    final result = await callable.call({
      'periodType': periodType,
      if (attribute != null) 'attribute': attribute,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}
