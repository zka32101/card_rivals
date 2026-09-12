import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  // AdMob アプリ ID（Google Play Console で取得）
  static const String _adMobAppId = 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy';

  // バナー広告ユニットID（テスト ID）
  static const String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  // インタースティシャル広告ユニットID（テスト ID）
  static const String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // リワード広告ユニットID（テスト ID）
  static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static bool _isInitialized = false;

  /// Google Mobile Ads を初期化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    } catch (e) {
      // Ads 初期化エラー
    }
  }

  /// バナー広告を読み込み
  static BannerAd createBannerAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    )..load();
  }

  /// インタースティシャル広告を読み込み
  static Future<void> loadInterstitialAd({
    required void Function() onAdLoaded,
    required void Function(LoadAdError) onAdFailedToLoad,
  }) async {
    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (_) {
          onAdLoaded();
        },
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  /// リワード広告を読み込み
  static Future<void> loadRewardedAd({
    required void Function() onAdLoaded,
    required void Function(LoadAdError) onAdFailedToLoad,
  }) async {
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (_) {
          onAdLoaded();
        },
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  /// テスト広告か確認
  static bool get isTestAdEnabled {
    // 本番環境では false に変更
    return true;
  }
}
