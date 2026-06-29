import 'package:construction_erp_phase5/core/value_objects/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money stores rupees as integer paise', () {
    expect(Money.parseRupees('123.45').paise, 12345);
    expect(Money.rupees(10).paise, 1000);
  });

  test('money adds and subtracts without double', () {
    final total = Money.parseRupees('100.10') + Money.parseRupees('0.90');
    expect(total.paise, 10100);
    expect((total - Money.rupees(1)).paise, 10000);
  });
}
