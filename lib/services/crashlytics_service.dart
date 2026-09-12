import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  static Future<void> initialize() async {
    // Firebase Crashlytics を初期化
    if (!kDebugMode) {
      // 本番環境でのみ有効化
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Crashlytics を有効化
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  /// エラーをログ出力
  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: fatal,
    );
  }

  /// カスタムログを記録
  static void log(String message) {
    FirebaseCrashlytics.instance.log(message);
  }

  /// ユーザー情報を設定
  static Future<void> setUserId(String userId) async {
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }
}
