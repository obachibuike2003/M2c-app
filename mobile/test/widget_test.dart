import 'package:flutter_test/flutter_test.dart';

import 'package:easy2buy/widgets.dart';

void main() {
  test('money formats naira like the website', () {
    expect(money(0), '₦0');
    expect(money(2500), '₦2,500');
    expect(money(1234567), '₦1,234,567');
    expect(money(-50000), '-₦50,000');
  });

  test('compact counts', () {
    expect(compact(950), '950');
    expect(compact(1200), '1.2k');
    expect(compact(15000), '15k');
  });
}
