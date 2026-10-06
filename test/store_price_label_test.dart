import 'package:flutter_test/flutter_test.dart';
import 'package:card_rivals/services/purchase_service.dart';

void main() {
  test('固定の金額を、ストアの価格に置き換える', () {
    expect(PurchaseService.withStorePrice('¥480/月で加入する', '¥460'), '¥460/月で加入する');
    expect(PurchaseService.withStorePrice('¥3,700/年で加入する（約36%おトク）', '¥3,600'),
        '¥3,600/年で加入する（約36%おトク）');
  });

  test('ストア価格が無ければ、ラベルはそのまま', () {
    expect(PurchaseService.withStorePrice('¥480/月で加入する', null), '¥480/月で加入する');
    expect(PurchaseService.withStorePrice('¥480/月で加入する', ''), '¥480/月で加入する');
  });
}
