import 'package:flutter_test/flutter_test.dart';

import 'package:easy2buy/config.dart';
import 'package:easy2buy/widgets.dart';

void main() {
  test('money formats naira like the website', () {
    expect(money(0), '₦0');
    expect(money(2500), '₦2,500');
    expect(money(1234567), '₦1,234,567');
    expect(money(-50000), '-₦50,000');
  });

  test('order tracker has every step, ending at delivery', () {
    expect(AppConfig.trackStages.length, 10);
    expect(AppConfig.trackStages.first.name, 'Order placed');
    expect(AppConfig.trackStages.last.name, 'Delivered');
  });

  test('compact counts', () {
    expect(compact(950), '950');
    expect(compact(1200), '1.2k');
    expect(compact(15000), '15k');
  });
}
