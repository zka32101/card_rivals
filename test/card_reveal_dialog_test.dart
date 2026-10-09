import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:card_rivals/models/user_card.dart';
import 'package:card_rivals/widgets/card_reveal_dialog.dart';

PlayCard _card() => PlayCard(
      cardId: 'c1',
      attribute: 'joy',
      cost: 2,
      attackPower: 10,
      defensePower: 22,
      speed: 2,
      nameJp: 'にっこり天使',
    );

void main() {
  testWidgets('開封ダイアログ: 表面を出してもレイアウトがはみ出さない（下段34pxはみ出し回帰）', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => CardRevealDialog.show(context, _card()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));

    // カードパック（裏面）をタップして開封。演出は繰り返しアニメを含むので pumpAndSettle は使わない。
    await tester.tap(find.byType(CardRevealDialog));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('にっこり天使'), findsWidgets);
    // RenderFlex overflow は、テストでは例外として溜まる。
    expect(tester.takeException(), isNull);
  });
}
