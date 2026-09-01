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
import 'providers/locale_provider.dart';
import 'providers/migration_provider.dart';
import 'screens/bonus_detail_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/explanation_screen.dart';
import 'screens/home_screen_v2.dart';
import 'screens/purchase_history_screen.dart';
import 'screens/season_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'services/purchase_service.dart';
import 'theme/kingdom_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // リリースビルドではdebugPrint()の出力を抑制する。debugPrintはpackage:flutter/
  // foundation.dartが公開する差し替え可能な関数ポインタなので、ここで1箇所無効化
  // するだけでアプリ全体（lib/配下の全debugPrint呼び出し）に効く。
  // エラーメッセージ自体に機密情報は含めていないが、配布ビルドのログに何も
  // 出さないのが原則のため抑制する。
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  runApp(
    const ProviderScope(
      child: CardRivalsApp(),
    ),
  );
}

class CardRivalsApp extends ConsumerWidget {
  const CardRivalsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    // Firestoreに保存済みのウォレットを、ユーザーごとに1回だけ
    // ローカルのwalletProviderへ反映する（未反映のままだと再起動のたびに
    // コイン/ジェムが初期値へリセットされたように見えるバグがあった）。
    ref.listen<AsyncValue<WalletState>>(userWalletProvider, (previous, next) {
      final wallet = next.valueOrNull;
      final uid = ref.read(currentUserIdProvider);
      if (wallet == null || uid == null) return;
      if (ref.read(walletHydratedForUidProvider) == uid) return;
      ref.read(walletProvider.notifier).state = wallet;
      ref.read(walletHydratedForUidProvider.notifier).state = uid;
    });

    // 属性移住状態も同様に、ユーザーごとに1回だけFirestoreから復元する。
    ref.listen<AsyncValue<MigrationState>>(userMigrationProvider, (previous, next) {
      final migration = next.valueOrNull;
      final uid = ref.read(currentUserIdProvider);
      if (migration == null || uid == null) return;
      if (ref.read(migrationHydratedForUidProvider) == uid) return;
      ref.read(migrationStateProvider.notifier).state = migration;
      ref.read(migrationHydratedForUidProvider.notifier).state = uid;
    });

    // 作成済みカードも同様に、ユーザーごとに1回だけFirestoreから復元する。
    ref.listen<AsyncValue<List<UserCard>>>(userCardsFirestoreProvider, (previous, next) {
      final cards = next.valueOrNull;
      final uid = ref.read(currentUserIdProvider);
      if (cards == null || uid == null) return;
      if (ref.read(myCardsHydratedForUidProvider) == uid) return;
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
      builder: (context, state) => const HomeScreenV2(),
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
