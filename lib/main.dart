import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'models/user_card.dart';
import 'providers/auth_provider.dart';
import 'providers/collection_provider.dart';
import 'providers/game_state_provider.dart';
import 'providers/hydration.dart';
import 'providers/locale_provider.dart';
import 'providers/migration_provider.dart';
import 'screens/bonus_detail_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/explanation_screen.dart';
import 'screens/main_shell.dart';
import 'screens/purchase_history_screen.dart';
import 'screens/season_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'theme/kingdom_theme.dart';
import 'widgets/startup_splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初期化中は組織ロゴ付きの起動画面を表示する（本来のrunAppが後で置き換える）。
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: StartupSplash()));
  // リリースビルドではdebugPrint()の出力を抑制する。debugPrintはpackage:flutter/
  // foundation.dartが公開する差し替え可能な関数ポインタなので、ここで1箇所無効化
  // するだけでアプリ全体（lib/配下の全debugPrint呼び出し）に効く。
  // エラーメッセージ自体に機密情報は含めていないが、配布ビルドのログに何も
  // 出さないのが原則のため抑制する。
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // AndroidネイティブのFirebaseInitProviderがgoogle-services.jsonから
    // 既定のFirebaseAppを自動初期化済みの場合、Dart側の明示initializeAppは
    // "duplicate-app" で失敗する。既に初期化済みなだけなので無視して続行する。
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }
  try {
    // ウォレット/カード/ランキングなど全機能がFirestoreのユーザードキュメントに
    // 紐づくため、匿名認証ユーザーを起動時に確立しておく。これを怠ると
    // currentUser が常にnullとなり、保存系の処理が全て無言でno-opになる。
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    // 匿名認証が失敗しても（オフライン等）アプリ自体は起動を継続する。
    // ログイン状態に依存する機能はcurrentUserIdProvider経由でnullを見て
    // ローカルのみの動作にフォールバックする。
    debugPrint('Anonymous sign-in failed: $e');
  }
  try {
    await PurchaseService.init();
  } catch (e) {
    // RevenueCat未設定（APIキー未発行）でも課金以外の機能は使えるようにアプリを止めない
    debugPrint('PurchaseService init failed: $e');
  }
  try {
    await AdService.initialize();
    AdService.preloadInterstitial();
  } catch (e) {
    // 広告SDKの初期化失敗でもアプリ本体は止めない（無料版でも広告なしで遊べる）
    debugPrint('AdService initialize failed: $e');
  }
  final initialLocale = await loadSavedLocale();
  runApp(
    ProviderScope(
      overrides: [localeProvider.overrideWith((ref) => initialLocale)],
      child: const CardRivalsApp(),
    ),
  );
}

class CardRivalsApp extends ConsumerWidget {
  const CardRivalsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    // 言語設定の変更を端末に保存（再起動後も維持）
    ref.listen<Locale>(localeProvider, (previous, next) => saveLocale(next));

    // Firestoreに保存済みのウォレットを、ユーザーごとに1回だけ
    // ローカルのwalletProviderへ反映する（未反映のままだと再起動のたびに
    // コイン/ジェムが初期値へリセットされたように見えるバグがあった）。
    ref.listen<AsyncValue<WalletState?>>(userWalletProvider, (previous, next) {
      final uid = ref.read(currentUserIdProvider);
      final wallet = valueToHydrate(next, uid: uid, hydratedUid: ref.read(walletHydratedForUidProvider));
      if (wallet == null || uid == null) return;
      ref.read(walletProvider.notifier).state = wallet;
      ref.read(walletHydratedForUidProvider.notifier).state = uid;
      markWalletHydrated(uid);
    });

    // 課金(RevenueCat)のユーザーをFirebaseのuidに紐付ける。再インストール・復元時に
    // 同じアカウントの購入として扱えるようにするため。
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (next != null) PurchaseService.syncUser(next);
    });

    // 属性移住状態も同様に、ユーザーごとに1回だけFirestoreから復元する。
    ref.listen<AsyncValue<MigrationState?>>(userMigrationProvider, (previous, next) {
      final uid = ref.read(currentUserIdProvider);
      final migration = valueToHydrate(next, uid: uid, hydratedUid: ref.read(migrationHydratedForUidProvider));
      if (migration == null || uid == null) return;
      ref.read(migrationStateProvider.notifier).state = migration;
      ref.read(migrationHydratedForUidProvider.notifier).state = uid;
    });

    // 作成済みカードも同様に、ユーザーごとに1回だけFirestoreから復元する。
    ref.listen<AsyncValue<List<UserCard>?>>(userCardsFirestoreProvider, (previous, next) {
      final uid = ref.read(currentUserIdProvider);
      final cards = valueToHydrate(next, uid: uid, hydratedUid: ref.read(myCardsHydratedForUidProvider));
      if (cards == null || uid == null) return;
      ref.read(myCardsProvider.notifier).state = cards;
      ref.read(myCardsHydratedForUidProvider.notifier).state = uid;
    });

    return MaterialApp.router(
      routerConfig: _router,
      title: 'Card Rivals',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: Kingdom.materialTheme(),
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainShell(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopScreen(),
    ),
    GoRoute(
      path: '/bonus-detail',
      builder: (context, state) => const BonusDetailScreen(),
    ),
    GoRoute(
      path: '/purchase-history',
      builder: (context, state) => const PurchaseHistoryScreen(),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
    GoRoute(
      path: '/contact',
      builder: (context, state) => const ContactScreen(),
    ),
    GoRoute(
      path: '/season',
      builder: (context, state) => const SeasonScreen(),
    ),
    GoRoute(
      path: '/explanation',
      builder: (context, state) => const ExplanationScreen(),
    ),
  ],
);
