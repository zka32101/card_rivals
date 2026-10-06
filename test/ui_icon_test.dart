import 'dart:io';

import 'package:card_rivals/widgets/ui_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  iconTextTests();
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

void iconTextTests() {
  testWidgets('IconText: 絵文字を画像に置き換える（異体字セレクタつきも）', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: IconText('🪙100 と ⚔️10 / 🛡️5 ⚡3')),
    ));
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.textContaining('🪙'), findsNothing);
  });

  testWidgets('IconText: 絵文字がなければ、普通の Text と同じ', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: IconText('こんにちは', maxLines: 1)),
    ));
    expect(find.text('こんにちは'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('IconText: 対象外の絵文字は、そのまま文字で残る', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: IconText('🎁 プレゼント 🪙5')),
    ));
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('🎁', findRichText: true), findsOneWidget);
  });
}
