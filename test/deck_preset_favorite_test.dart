import 'package:flutter_test/flutter_test.dart';
import 'package:card_rivals/models/deck_preset.dart';

void main() {
  DeckPreset base({bool? fav}) => DeckPreset(
        id: 'p1',
        userId: 'u',
        name: '速攻デッキ',
        cardIds: const ['a', 'b'],
        isFavorite: fav ?? false,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

  test('isFavorite はデフォルト false で、toMap/fromMap を往復する', () {
    expect(base().isFavorite, isFalse);
    final map = base(fav: true).toMap();
    expect(map['isFavorite'], isTrue);
    final restored = DeckPreset.fromMap(map, id: 'p1', userId: 'u');
    expect(restored.isFavorite, isTrue);
    expect(restored.name, '速攻デッキ');
  });

  test('isFavorite を持たない既存データは false として読める', () {
    final map = base().toMap()..remove('isFavorite');
    expect(DeckPreset.fromMap(map, id: 'p1', userId: 'u').isFavorite, isFalse);
  });

  test('copyWith で isFavorite だけ切り替えられる', () {
    final fav = base().copyWith(isFavorite: true);
    expect(fav.isFavorite, isTrue);
    expect(fav.name, '速攻デッキ');
  });
}
