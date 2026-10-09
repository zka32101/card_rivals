import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:card_rivals/data/opponent_pool_names.dart';
import 'package:card_rivals/data/seed_cards_data.dart';

final _jp = RegExp(r'[\u3040-\u30FF\u3400-\u9FFF\uFF00-\uFFEF]');

void main() {
  test('全シードカードのnameEnが非空で日本語を含まない', () {
    expect(seedCardsData, isNotEmpty);
    for (final c in seedCardsData) {
      expect(c.nameEn.trim(), isNotEmpty, reason: c.cardId);
      expect(_jp.hasMatch(c.nameEn), isFalse, reason: '${c.cardId}: ${c.nameEn}');
    }
  });

  test('対戦相手プールの英語名が非空・日本語なし', () {
    for (final e in opponentPoolNamesEn.entries) {
      expect(e.value.trim(), isNotEmpty, reason: e.key);
      expect(_jp.hasMatch(e.value), isFalse, reason: e.key);
    }
  });

  test('pvpMatch.ts の OPPONENT_POOL 全カードに英語名がある(サーバー値/クライアント補完)', () {
    final src = File('functions/src/pvpMatch.ts').readAsStringSync();
    final rows = RegExp(r'\{cardId: "(\w+)"[^\n]*\}').allMatches(src).toList();
    expect(rows, isNotEmpty);
    final seedEn = {for (final c in seedCardsData) c.cardId: c.nameEn};
    for (final m in rows) {
      final id = m.group(1)!;
      final line = m.group(0)!;
      final server = RegExp(r'nameEn: "([^"]+)"').firstMatch(line)?.group(1);
      expect(server, isNotNull, reason: 'server nameEn missing: $id');
      expect(_jp.hasMatch(server!), isFalse, reason: id);
      final client = opponentPoolNamesEn[id] ?? seedEn[id];
      expect(client, isNotNull, reason: 'client fallback missing: $id');
      expect(client, server, reason: id);
    }
  });
}
