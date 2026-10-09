import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_rivals/l10n/app_localizations.dart';
import 'package:card_rivals/models/card_move.dart';
import 'package:card_rivals/widgets/move_effects.dart';

Widget _host(CardMoveId id, double t) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox.expand(
          child: MoveEffectOverlay(
            animation: AlwaysStoppedAnimation(t),
            moveId: id,
            color: Colors.amber,
          ),
        ),
      ),
    );

void main() {
  const attackMoves = [
    CardMoveId.slash,
    CardMoveId.pierce,
    CardMoveId.heavyBlow,
    CardMoveId.weakPoint,
  ];

  test('攻撃系4種だけが専用の攻撃エフェクトを持つ', () {
    for (final id in CardMoveId.values) {
      expect(moveHasAttackEffect(id), attackMoves.contains(id), reason: '$id');
    }
  });

  for (final id in attackMoves) {
    testWidgets('$id: 全フェーズを例外なく描画できる', (tester) async {
      for (final t in [0.05, 0.2, 0.45, 0.55, 0.7, 0.85, 0.99]) {
        await tester.pumpWidget(_host(id, t));
        expect(tester.takeException(), isNull, reason: '$id t=$t');
      }
    });
  }

  testWidgets('技名カットインはカットイン区間のみ表示される', (tester) async {
    await tester.pumpWidget(_host(CardMoveId.slash, 0.25));
    expect(find.textContaining('一閃'), findsOneWidget);
    await tester.pumpWidget(_host(CardMoveId.slash, 0.8));
    expect(find.textContaining('一閃'), findsNothing);
  });

  testWidgets('再生前(0)と終了後(1)は何も描かない', (tester) async {
    await tester.pumpWidget(_host(CardMoveId.heavyBlow, 0));
    expect(find.textContaining('ごうりき'), findsNothing);
    await tester.pumpWidget(_host(CardMoveId.heavyBlow, 1));
    expect(find.textContaining('ごうりき'), findsNothing);
  });

  testWidgets('補助系わざもカットインは表示される', (tester) async {
    await tester.pumpWidget(_host(CardMoveId.ironWall, 0.25));
    expect(find.textContaining('てつぺき'), findsOneWidget);
  });
}
