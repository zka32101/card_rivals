import 'dart:io';

import 'package:card_rivals/widgets/ui_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('11種すべてに、対応する画像ファイルがある', () {
    for (final k in UiIconKind.values) {
      expect(File(k.assetPath).existsSync(), isTrue, reason: k.assetPath);
    }
    expect(UiIconKind.values.length, 11);
  });

  test('pubspec に assets/ui_icons/ が登録されている', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/ui_icons/'));
  });

  testWidgets('UiIconText は、アイコンと文字を並べて出す', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: UiIconText(UiIconKind.coin, '103')),
    ));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('103'), findsOneWidget);
  });
}
