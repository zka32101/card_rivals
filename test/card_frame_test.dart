import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:card_rivals/models/card_frame.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/providers/game_state_provider.dart';
import 'package:card_rivals/widgets/card_widget.dart';

PlayCard _card({int cost = 3}) => PlayCard(
      cardId: 'c1',
      attribute: 'joy',
      cost: cost,
      attackPower: 10,
      defensePower: 8,
      speed: 5,
      nameJp: 'テスト',
      nameEn: 'Test',
    );

void main() {
  group('kCardFrames', () {
    test('10件・id重複なし・価格はコインかジェムのどちらか1つ・アセット存在', () {
      expect(kCardFrames.length, 10);
      expect(kCardFrames.map((f) => f.id).toSet().length, 10);
      for (final f in kCardFrames) {
        expect((f.priceCoins != null) != (f.priceGems != null), isTrue, reason: f.id);
        expect(f.price, greaterThan(0));
        expect(File(f.assetPath).existsSync(), isTrue, reason: f.assetPath);
        final h = f.holeNorm;
        expect(h.left, inInclusiveRange(0, 1));
        expect(h.right, greaterThan(h.left));
        expect(h.bottom, greaterThan(h.top));
        expect(h.right, lessThanOrEqualTo(1));
        expect(h.bottom, lessThanOrEqualTo(1));
        expect(f.currency == FrameCurrency.coin, f.id.startsWith('coin_'));
      }
      expect(cardFrameById('nope'), isNull);
      expect(cardFrameById(null), isNull);
    });
  });

  group('購入ロジック', () {
    const inv = FrameInventory();

    test('コイン購入: 残高が減り所持に追加、自動装着はしない', () {
      const w = WalletState(coinBalance: 1000, gemBalance: 7);
      final r = purchaseFrameLogic(w, inv, 'coin_iron');
      expect(r.ok, isTrue);
      expect(r.wallet.coinBalance, 700);
      expect(r.wallet.gemBalance, 7);
      expect(r.inventory.owns('coin_iron'), isTrue);
      expect(r.inventory.equippedId, isNull);
    });

    test('ジェム購入', () {
      const w = WalletState(coinBalance: 5, gemBalance: 40);
      final r = purchaseFrameLogic(w, inv, 'gem_rainbow');
      expect(r.ok, isTrue);
      expect(r.wallet.gemBalance, 0);
      expect(r.wallet.coinBalance, 5);
    });

    test('残高不足は拒否（コイン・ジェム）。ちょうどなら購入可', () {
      const w = WalletState(coinBalance: 299, gemBalance: 29);
      expect(purchaseFrameLogic(w, inv, 'coin_iron').status, FramePurchaseStatus.insufficientFunds);
      expect(purchaseFrameLogic(w, inv, 'gem_gold').status, FramePurchaseStatus.insufficientFunds);
      final r = purchaseFrameLogic(const WalletState(coinBalance: 300), inv, 'coin_iron');
      expect(r.ok, isTrue);
      expect(r.wallet.coinBalance, 0);
    });

    test('通貨違いの残高では買えない', () {
      const w = WalletState(coinBalance: 99999, gemBalance: 0);
      expect(purchaseFrameLogic(w, inv, 'gem_gold').status, FramePurchaseStatus.insufficientFunds);
    });

    test('二重購入防止（残高も変わらない）', () {
      const w = WalletState(coinBalance: 1000);
      final first = purchaseFrameLogic(w, inv, 'coin_iron');
      final second = purchaseFrameLogic(first.wallet, first.inventory, 'coin_iron');
      expect(second.status, FramePurchaseStatus.alreadyOwned);
      expect(second.wallet.coinBalance, 700);
      expect(second.inventory.ownedIds, ['coin_iron']);
    });

    test('存在しないIDは拒否', () {
      final r = purchaseFrameLogic(const WalletState(coinBalance: 1000), inv, 'zzz');
      expect(r.status, FramePurchaseStatus.unknownFrame);
    });

    test('装着/解除/未所持は装着不可', () {
      const owned = FrameInventory(ownedIds: ['coin_iron', 'gem_ice']);
      expect(equipFrameLogic(owned, 'coin_silver').equippedId, isNull);
      final eq = equipFrameLogic(owned, 'gem_ice');
      expect(eq.equippedId, 'gem_ice');
      expect(eq.validEquippedId, 'gem_ice');
      expect(equipFrameLogic(eq, 'coin_iron').equippedId, 'coin_iron');
      final un = unequipFrameLogic(eq);
      expect(un.equippedId, isNull);
      expect(un.ownedIds, owned.ownedIds);
    });

    test('Firestore入出力: 不正値は無視', () {
      final i = FrameInventory.fromMap({'ownedIds': ['coin_iron', 3, 'coin_iron'], 'equippedId': 'gem_gold'});
      expect(i.ownedIds, ['coin_iron']);
      expect(i.validEquippedId, isNull); // 未所持の装着は無効
      expect(FrameInventory.fromMap(null).ownedIds, isEmpty);
      expect(FrameInventory.fromMap(i.toMap()).ownedIds, ['coin_iron']);
    });
  });

  group('CardWidget frameId', () {
    Widget host(Widget child, {double width = 160, double? height}) => ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ja'), Locale('en')],
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, height: height, child: child),
              ),
            ),
          ),
        );

    testWidgets('全フレーム・SR/URでもオーバーフロー例外が出ない', (tester) async {
      for (final f in kCardFrames) {
        for (final compact in [false, true]) {
          await tester.pumpWidget(host(
            CardWidget(card: _card(cost: 5), size: 160, compact: compact, frameId: f.id),
            height: 400,
          ));
          await tester.pump();
          final ex = tester.takeException();
          expect(ex, isNull, reason: "${f.id} compact=$compact $ex");
          // 全体の幅は size 以下に収まる
          expect(tester.getSize(find.byType(CardWidget)).width, lessThanOrEqualTo(160.01), reason: f.id);
        }
      }
    });

    testWidgets('frameIdがnull/不明なら従来と同一（FittedBox・フレーム画像なし）', (tester) async {
      await tester.pumpWidget(host(CardWidget(card: _card(), size: 150)));
      final plain = tester.getSize(find.byType(CardWidget));
      expect(find.byType(FittedBox), findsNothing);

      await tester.pumpWidget(host(CardWidget(card: _card(), size: 150, frameId: 'unknown')));
      expect(tester.getSize(find.byType(CardWidget)), plain);
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('フレームを渡すとフレーム画像が描画される', (tester) async {
      await tester.pumpWidget(host(CardWidget(card: _card(), size: 150, frameId: 'coin_silver')));
      expect(find.byType(FittedBox), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });
  });
}
