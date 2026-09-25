import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 広告サービス（無料ユーザー向け）
// VIPパス加入者には広告を一切表示しない。呼び出し側（画面）で
// vipStatusProvider を確認してから showBanner/showInterstitial を呼ぶこと。
//
// デバッグビルドでは誤って本番広告ユニットに実インプレッションを送らないよう
// Google公式のテスト広告ユニットIDを使用し、リリースビルドでのみ本番IDを使う。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AdService {
  static const String _bannerAdUnitIdTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialAdUnitIdTest = 'ca-app-pub-3940256099942544/1033173712';

  static const String _bannerAdUnitIdProd = 'ca-app-pub-5058227312086483/5391698485';
  static const String _interstitialAdUnitIdProd = 'ca-app-pub-5058227312086483/2765535147';

  static String get bannerAdUnitId => kReleaseMode ? _bannerAdUnitIdProd : _bannerAdUnitIdTest;
  static String get interstitialAdUnitId => kReleaseMode ? _interstitialAdUnitIdProd : _interstitialAdUnitIdTest;

  static bool _initialized = false;

  /// main() から一度だけ呼ぶ
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('AdMob initialize failed: $e');
    }
  }

  /// バナー広告を読み込む。呼び出し側で dispose() を忘れないこと。
  static BannerAd createBannerAd({required VoidCallback onLoaded, required void Function(LoadAdError error) onFailed}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed(error);
        },
      ),
    )..load();
  }

  static InterstitialAd? _interstitialAd;
  static bool _interstitialLoading = false;

  /// 次に表示するインタースティシャル広告を先読みしておく。
  /// バトル画面遷移時など、実際の表示より少し前に呼んでおくと体感の待ちが減る。
  static void preloadInterstitial() {
    if (_interstitialAd != null || _interstitialLoading) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _interstitialAd = null;
          _interstitialLoading = false;
        },
      ),
    );
  }

  /// 読み込み済みのインタースティシャル広告を表示する。
  /// 読み込みが間に合っていない場合は何もしない（バトル体験を止めない）。
  static void showInterstitialIfReady({VoidCallback? onDismissed}) {
    final ad = _interstitialAd;
    if (ad == null) {
      onDismissed?.call();
      return;
    }
    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onDismissed?.call();
        preloadInterstitial(); // 次回表示用に先読みしておく
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        onDismissed?.call();
        preloadInterstitial();
      },
    );
    ad.show();
  }
}
