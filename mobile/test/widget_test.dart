import 'package:flutter_test/flutter_test.dart';

import 'package:easy2buy/app_state.dart';
import 'package:easy2buy/widgets.dart';

void main() {
  test('money formats naira like the website', () {
    expect(money(0), '₦0');
    expect(money(2500), '₦2,500');
    expect(money(1234567), '₦1,234,567');
    expect(money(-50000), '-₦50,000');
  });

  test('exchange quotes match the website', () {
    final s = AppState();
    expect(s.quote('NGN', 'CNY', 10000), 45.66); // 10000 / 219, floored to 2 dp
    expect(s.quote('CNY', 'NGN', 100), 21300);
    expect(s.quote('NGN', 'BTC', 1000000), 0.00606060); // 8 dp
    expect(s.quote('NGN', 'CNY', 0), 0);
  });

  test('wallet amounts format per currency', () {
    expect(moneyIn(1500, 'NGN'), '₦1,500');
    expect(moneyIn(45.5, 'CNY'), '¥45.50');
    expect(moneyIn(0.0060606, 'BTC'), '0.0060606 BTC');
    expect(moneyIn(12000.5, 'USDT'), '12,000.5 USDT');
  });

  test('compact counts', () {
    expect(compact(950), '950');
    expect(compact(1200), '1.2k');
    expect(compact(15000), '15k');
  });
}
