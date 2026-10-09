import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;

import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:card_rivals/main.dart' show appRoutes;
import 'package:card_rivals/models/deck_preset.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/auth_provider.dart';
import 'package:card_rivals/providers/collection_provider.dart';
import 'package:card_rivals/providers/deck_presets_provider.dart';
import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:card_rivals/providers/vip_provider.dart';
import 'package:card_rivals/services/functions_service.dart';
import 'package:card_rivals/theme/kingdom_theme.dart';

final jpChars = RegExp(r'[ぁ-んァ-ヶ一-龠]');

class ScreenSpec {
  final String name;
  final Size size;
  final double textScale;
  const ScreenSpec(this.name, this.size, this.textScale);
}

const viewports = [
  ScreenSpec('normal', Size(411, 860), 1.0),
  ScreenSpec('narrow-1.0', Size(360, 640), 1.0),
  ScreenSpec('narrow-1.3', Size(360, 640), 1.3),
  ScreenSpec('narrow-2.0', Size(360, 640), 2.0),
];

const localizationDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// 画面上の全Textから日本語を含む文字列を集める（ユーザー作成データ除外は呼び出し側で）。
List<String> japaneseTexts(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    final s = w.text.toPlainText();
    if (!jpChars.hasMatch(s)) continue;
    // ユーザー作成データ（カード名・デッキ名・他プレイヤー名）は日本語のままで正しい
    if (userDataMarkers.any(s.contains)) continue;
    out.add(s);
  }
  return out;
}

/// フィクスチャに含まれるユーザー作成の日本語データ
const userDataMarkers = ['とても長い', 'わたしの最強デッキ'];

Widget wrapApp({
  required Widget child,
  required Locale locale,
  required double textScale,
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: overrides,
      // Riverpod 3は失敗したFutureProviderを指数バックオフで自動再試行し、その間は
      // 「読み込み中」のままになる。テストでは即座にエラー状態として検証したいので再試行しない。
      retry: (_, _) => null,
      child: MaterialApp(
        locale: locale,
        theme: testTheme(),
        localizationsDelegates: localizationDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

Widget wrapRouter({
  required String location,
  required Locale locale,
  required double textScale,
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: overrides,
      // Riverpod 3は失敗したFutureProviderを指数バックオフで自動再試行し、その間は
      // 「読み込み中」のままになる。テストでは即座にエラー状態として検証したいので再試行しない。
      retry: (_, _) => null,
      child: MaterialApp.router(
        locale: locale,
        theme: testTheme(),
        localizationsDelegates: localizationDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(routes: appRoutes, initialLocation: location),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
      ),
    );

void setViewport(WidgetTester tester, ScreenSpec v) {
  tester.view.physicalSize = v.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// body実行中に出たFlutterError（RenderFlexオーバーフロー含む）を全て集めて返す。
/// onErrorは必ずexpectの前に元へ戻す（戻さないとテスト基盤が壊れる）。
Future<List<String>> collectErrors(Future<void> Function() body, {String? tag}) async {
  final errors = <String>[];
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final full = d.toString().replaceAll(RegExp(r'\s+'), ' ');
    final loc = RegExp(r'(lib/[\w/]+\.dart:\d+)').firstMatch(full)?.group(1);
    errors.add(loc == null ? full : '$full @ $loc');
  };
  try {
    await body();
  } finally {
    FlutterError.onError = prev;
  }
  if (tag != null && errors.isNotEmpty && Platform.environment['SMOKE_LOG'] != null) {
    File(Platform.environment['SMOKE_LOG']!)
        .writeAsStringSync('$tag\t${errors.join(' || ')}\n', mode: FileMode.append);
  }
  return errors;
}

/// アニメーションが常時走る画面向け: pumpAndSettleの代わりに時間を進める。
Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}


/// flutter_testは既定で全文字が1emの等幅フォント(Ahem)になり、実機よりはるかに幅広く測るため
/// 偽のオーバーフローが大量に出る。Android実機に近い幅で測るため、FlutterSDK同梱のRoboto
/// （Latin）と、あればOS同梱の日本語フォント（日本語）を読み込む。
/// 日本語フォントが見つからない環境では日本語の幅は近似になる（Latinは正確）。
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData?> read(String path) async {
    final f = File(path);
    if (!f.existsSync()) return null;
    return ByteData.sublistView(await f.readAsBytes());
  }

  for (final family in ['Roboto', 'serif']) {
    final loader = FontLoader(family);
    var any = false;
    for (final name in ['regular', 'bold', 'medium']) {
      final d = await read('$dir/roboto-$name.ttf');
      if (d != null) {
        loader.addFont(Future.value(d));
        any = true;
      }
    }
    if (any) await loader.load();
  }
  for (final cand in [
    'C:/Windows/Fonts/NotoSansJP-VF.ttf',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
  ]) {
    final d = await read(cand);
    if (d != null) {
      final loader = FontLoader('TestJP')..addFont(Future.value(d));
      await loader.load();
      _jpFontLoaded = true;
      break;
    }
  }
}

bool _jpFontLoaded = false;

ThemeData testTheme() {
  final base = Kingdom.materialTheme();
  if (!_jpFontLoaded) return base;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: const ['TestJP']),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: const ['TestJP']),
  );
}

// ───────── テスト用フィクスチャ ─────────

UserCard fakeUserCard(String id, String name, {String attr = 'joy', int cost = 1, int atk = 12, int def = 12, int spd = 10}) => UserCard(
      cardId: id,
      userId: 'u1',
      attribute: attr,
      cost: cost,
      attackPower: atk,
      defensePower: def,
      speed: spd,
      cardName: {'jp': name, 'en': name},
      cardDescription: const {'jp': '', 'en': ''},
      createdAt: Timestamp.now(),
    );

/// 所持カード（ユーザー作成名は日英どちらでも日本語のまま＝英語UIの日本語チェック対象外）
List<UserCard> fakeMyCards([int n = 8]) => [
      for (var i = 0; i < n; i++)
        fakeUserCard('my$i', i == 0 ? 'とても長い名前のユーザー作成カードその$i' : 'Card $i',
            attr: const ['joy', 'anger', 'sadness'][i % 3], cost: 1 + i % 5),
    ];

/// サーバー関数のfake。name -> data。未登録の関数は例外（=サーバー失敗）。
class FakeServer {
  final Map<String, dynamic Function(Map<String, dynamic> params)> handlers = {};
  final List<String> calls = [];

  Future<dynamic> call(String name, Map<String, dynamic> params) async {
    calls.add(name);
    final h = handlers[name];
    if (h == null) throw StateError('fake server: $name not available');
    return h(params);
  }

  void install() => FunctionsService.debugHandler = call;
  void uninstall() => FunctionsService.debugHandler = null;
}

List<Map<String, dynamic>> fakeBoard([int n = 5]) => [
      for (var i = 0; i < n; i++)
        {'rank': i + 1, 'userId': 'x$i', 'userName': i == 0 ? 'とても長いプレイヤー名のユーザーさん' : 'Player $i', 'rating': 1800 - i * 50, 'wins': 30 - i, 'losses': i},
    ];

List<Override> populatedOverrides(
        {int coins = 500, int gems = 12, List<UserCard>? cards, bool vip = false, Future<List<DeckPreset>> Function()? presets}) =>
    [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      walletProvider.overrideWith((ref) => WalletState(coinBalance: coins, gemBalance: gems, lastLoginDate: todayKeyJst())),
      myCardsProvider.overrideWith((ref) => cards ?? fakeMyCards()),
      userDeckPresetsProvider.overrideWith((ref) => (presets ?? () async => [
            DeckPreset(
                id: 'p1',
                userId: 'u1',
                name: 'わたしの最強デッキ',
                cardIds: const ['my0', 'my1', 'my2', 'my3', 'my4'],
                isFavorite: true,
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 2)),
          ])()),
      vipStatusProvider.overrideWith((ref) async => vip),
      myPlayerRankProvider.overrideWith((ref) async => PlayerRank.fromRating(1500, wins: 10, losses: 3)),
    ];
