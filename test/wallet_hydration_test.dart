import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

import 'package:card_rivals/providers/auth_provider.dart';
import 'package:card_rivals/providers/collection_provider.dart';
import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:card_rivals/providers/migration_provider.dart';
import 'package:card_rivals/providers/hydration.dart';

void main() {
  test('uid確定後のロード中に引き継がれた初期値ではハイドレートせず、実データを反映する', () async {
    final uidP = StateProvider<String?>((ref) => null);
    final gate = Completer<WalletState>();
    // userWalletProviderと同じ形: uid未確定は初期値、確定後はFirestore読み込み(遅延)
    final walletP = FutureProvider<WalletState>((ref) async {
      final uid = ref.watch(uidP);
      if (uid == null) return const WalletState();
      return gate.future;
    });
    final hydratedP = StateProvider<String?>((ref) => null);
    final localP = StateProvider<WalletState>((ref) => const WalletState());

    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen<AsyncValue<WalletState>>(walletP, (prev, next) {
      final uid = c.read(uidP);
      final w = valueToHydrate(next, uid: uid, hydratedUid: c.read(hydratedP));
      if (w == null || uid == null) return;
      c.read(localP.notifier).state = w;
      c.read(hydratedP.notifier).state = uid;
    });

    await c.read(walletP.future); // uid未確定: 初期値が返る
    c.read(uidP.notifier).state = 'u1'; // 匿名認証のuidが届く
    await Future<void>.delayed(Duration.zero);
    expect(c.read(hydratedP), isNull, reason: 'ロード中の古い初期値でハイドレートしてはいけない');

    gate.complete(const WalletState(coinBalance: 777, lastLoginDate: '2026-10-09', loginStreak: 3));
    await c.read(walletP.future);
    expect(c.read(hydratedP), 'u1');
    expect(c.read(localP).coinBalance, 777);
    expect(c.read(localP).lastLoginDate, '2026-10-09');
  });

  test('エラー時・同一uid再通知では反映しない', () {
    expect(valueToHydrate<int>(const AsyncError(1, StackTrace.empty), uid: 'u', hydratedUid: null), isNull);
    expect(valueToHydrate<int>(const AsyncData(5), uid: 'u', hydratedUid: 'u'), isNull);
    expect(valueToHydrate<int>(const AsyncData(5), uid: null, hydratedUid: null), isNull);
    expect(valueToHydrate<int>(const AsyncData(5), uid: 'u', hydratedUid: null), 5);
  });

  test('uid=nullで評価した結果は「実データなし(null)」で、後からuidが確定してもハイドレートされない', () async {
    final uid = StateProvider<String?>((ref) => null);
    final c = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(uid)),
    ]);
    addTearDown(c.dispose);
    final wallet = await c.read(userWalletProvider.future);
    final migration = await c.read(userMigrationProvider.future);
    final cards = await c.read(userCardsFirestoreProvider.future);
    expect(wallet, isNull, reason: '初期値(コイン100・未受取)をdataで返してはいけない');
    expect(migration, isNull);
    expect(cards, isNull);
    // リスナー発火時にはuidが確定済み、という順序でも反映されないこと
    final v = c.read(userWalletProvider);
    expect(valueToHydrate(v, uid: 'u1', hydratedUid: null), isNull);
  });
}
