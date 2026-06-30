import 'package:construction_erp/core/value_objects/money.dart';
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

  test('money uses Indian digit grouping for release UI', () {
    expect(Money.rupees(123).format(), '₹123.00');
    expect(Money.rupees(1234).format(), '₹1,234.00');
    expect(Money.rupees(123456).format(), '₹1,23,456.00');
    expect(Money.rupees(12345678).format(), '₹1,23,45,678.00');
    expect((-Money.rupees(123456)).format(), '-₹1,23,456.00');
  });
}
