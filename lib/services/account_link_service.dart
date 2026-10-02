import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Googleアカウントでのログイン/引き継ぎの結果
enum AccountLinkResult {
  /// 今の(匿名)アカウントにGoogleを紐付けた。データはそのまま
  linked,

  /// そのGoogleアカウントは既に別のデータに紐付いていたため、そちらへ切り替えた
  /// (再インストール・機種変更で引き継ぐケース)
  switchedToExisting,

  cancelled,
  failed,
}

/// 匿名ログインのデータ(コイン・カード・デッキ・ランク)を、Googleアカウントに紐付けて
/// 端末変更・再インストールで引き継げるようにする。
class AccountLinkService {
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // Android: serverClientIdは省略するとgoogle-servicesのdefault_web_client_idを使う
    await GoogleSignIn.instance.initialize();
    _initialized = true;
  }

  static User? get _user => FirebaseAuth.instance.currentUser;

  /// 現在のアカウントにGoogleが紐付いているか
  static bool get isLinked => _googleInfo != null;

  /// 紐付け済みGoogleアカウントのメールアドレス
  static String? get linkedEmail => _googleInfo?.email;

  static UserInfo? get _googleInfo {
    final user = _user;
    if (user == null) return null;
    for (final p in user.providerData) {
      if (p.providerId == 'google.com') return p;
    }
    return null;
  }

  static Future<AccountLinkResult> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return AccountLinkResult.failed;
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final current = _user;
      if (current != null && current.isAnonymous) {
        try {
          // 今のデータを残したままGoogleを紐付ける
          await current.linkWithCredential(credential);
          return AccountLinkResult.linked;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // 既にこのGoogleアカウントに紐付いたデータがある → そのデータへ切り替える
            await FirebaseAuth.instance.signInWithCredential(e.credential ?? credential);
            return AccountLinkResult.switchedToExisting;
          }
          rethrow;
        }
      }
      await FirebaseAuth.instance.signInWithCredential(credential);
      return AccountLinkResult.switchedToExisting;
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      return e.code == GoogleSignInExceptionCode.canceled
          ? AccountLinkResult.cancelled
          : AccountLinkResult.failed;
    } catch (e) {
      debugPrint('Account link failed: $e');
      return AccountLinkResult.failed;
    }
  }
}
