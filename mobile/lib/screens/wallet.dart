import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exchange.dart';

/// The wallet, the website's wallet.html: naira balance, add money (demo),
/// send out, yuan and crypto balances, and the history on this device.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    if (u == null) return const Scaffold(body: EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'Sign in to see your wallet', text: 'Your naira, yuan and crypto live here.'));
    final b = s.balances;
    final txns = s.txns;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Text('Hi, ${u.firstName}', style: Brand.head(26)),
        Text(u.email, style: const TextStyle(color: Brand.muted, fontSize: 13)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF3A50), Brand.red, Brand.red700]),
            boxShadow: const [BoxShadow(color: Color(0x40E0182D), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Naira balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(end: (b['NGN'] ?? 0).toDouble()),
              duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
              curve: easeOutStrong,
              builder: (_, v, _) => Text(moneyIn(v.roundToDouble(), 'NGN'), style: Brand.head(36, weight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pill(Icons.add, 'Add money', true, () => _fund(context)),
              _pill(Icons.swap_horiz_rounded, 'Exchange', false, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExchangeScreen()))),
              _pill(Icons.north_east_rounded, 'Send out', false, () => _send(context)),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        SectionHead(
          kicker: 'Balances',
          title: 'Yuan and crypto',
          action: 'Exchange',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExchangeScreen())),
        ),
        TwoColumn(children: [
          for (final r in AppConfig.rates)
            CardBox(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Brand.redSoft, shape: BoxShape.circle),
                  child: Text(r.code, style: TextStyle(color: Brand.red600, fontWeight: FontWeight.w800, fontSize: r.code.length > 3 ? 9.5 : 11)),
                ),
                const SizedBox(height: 8),
                Text(r.name, style: const TextStyle(color: Brand.muted, fontSize: 12)),
                Text(moneyIn(b[r.code] ?? 0, r.code), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
        const SizedBox(height: 22),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Transactions', style: Brand.head(19)),
            const SizedBox(height: 8),
            if (txns.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nothing yet. Add money to get started.', style: TextStyle(color: Brand.muted)))
            else
              for (final t in txns.take(50)) _txn(t),
          ]),
        ),
        const SizedBox(height: 10),
        const Text('Demo: balances are simulated. Transactions made on this phone show here.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _pill(IconData icon, String label, bool solid, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: solid ? Colors.white : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: solid ? 1 : 0.45)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: solid ? Brand.red600 : Colors.white),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: solid ? Brand.ink : Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _txn(Map<String, dynamic> t) {
    final amount = t['amount'] as num;
    final code = t['currency'] as String;
    String signed(num n, String c) => '${n < 0 ? '-' : '+'}${moneyIn(n.abs(), c)}';
    final d = DateTime.fromMillisecondsSinceEpoch((t['createdAt'] as num).toInt());
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final processing = t['status'] == 'processing';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.line))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t['desc']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              Text('${d.day} ${months[d.month - 1]} ${d.year}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
              const SizedBox(width: 8),
              Pill(processing ? 'Processing' : 'Completed', bg: processing ? const Color(0xFFFFF1D6) : Brand.greenSoft, fg: processing ? const Color(0xFF8F4D00) : Brand.green),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(signed(amount, code), style: TextStyle(fontWeight: FontWeight.w700, color: amount < 0 ? Brand.red600 : Brand.green)),
          if (t['gotAmount'] != null) Text(signed(t['gotAmount'] as num, t['gotCurrency'] as String), style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.green)),
        ]),
      ]),
    );
  }

  static void _fund(BuildContext context) {
    final amount = TextEditingController();
    _sheet(context, 'Add money', (sheet, setSheet, error, setError) => [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.blueSoft, borderRadius: BorderRadius.circular(12)),
            child: const Text('Demo: the money is added instantly. The live app would take a bank transfer or card payment here.', style: TextStyle(color: Brand.blue, fontSize: 13)),
          ),
          const SizedBox(height: 14),
          TextField(controller: amount, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Amount (₦)')),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final n in [5000, 20000, 100000, 500000]) ActionChip(label: Text(money(n)), onPressed: () => setSheet(() => amount.text = '$n')),
          ]),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: const TextStyle(color: Brand.red600, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<AppState>().fundWallet(num.tryParse(amount.text.trim()) ?? 0);
                if (sheet.mounted) Navigator.pop(sheet);
                if (context.mounted) showMessage(context, 'Money added to your wallet');
              } catch (e) {
                setError(e.toString());
              }
            },
            child: const Text('Add money'),
          ),
        ]);
  }

  static void _send(BuildContext context) {
    final s = context.read<AppState>();
    final codes = ['NGN', ...AppConfig.rates.map((r) => r.code)];
    var code = 'NGN';
    final amount = TextEditingController();
    final dest = TextEditingController();
    (String, String) labels(String c) => c == 'NGN'
        ? ('Bank account', 'Bank name and account number')
        : c == 'CNY'
            ? ('Alipay, WeChat or bank card', 'Account name and number or ID')
            : ('Wallet address', 'Include the network, for example TRC20');
    _sheet(context, 'Send out', (sheet, setSheet, error, setError) => [
          DropdownButtonFormField<String>(
            initialValue: code,
            decoration: const InputDecoration(labelText: 'Send from'),
            items: [for (final c in codes) DropdownMenuItem(value: c, child: Text('$c (${moneyIn(s.balances[c] ?? 0, c)})'))],
            onChanged: (v) => setSheet(() => code = v ?? 'NGN'),
          ),
          const SizedBox(height: 12),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 12),
          TextField(controller: dest, decoration: InputDecoration(labelText: labels(code).$1, helperText: labels(code).$2)),
          const SizedBox(height: 8),
          const Text('The amount is held from your balance and released once the store confirms the transfer.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: const TextStyle(color: Brand.red600, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              try {
                await s.requestPayout(code, num.tryParse(amount.text.trim()) ?? 0, dest.text);
                if (sheet.mounted) Navigator.pop(sheet);
                if (context.mounted) showMessage(context, 'Sent for processing');
              } catch (e) {
                setError(e.toString());
              }
            },
            child: const Text('Send'),
          ),
        ]);
  }

  /// A bottom sheet with a title, whose body can rebuild itself and show an error.
  static void _sheet(
    BuildContext context,
    String title,
    List<Widget> Function(BuildContext sheet, StateSetter setSheet, String? error, void Function(String) setError) body,
  ) {
    String? error;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: AnimationStyle(curve: easeDrawer, duration: const Duration(milliseconds: 360), reverseDuration: const Duration(milliseconds: 220)),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Brand.head(22)),
            const SizedBox(height: 14),
            ...body(sheet, setSheet, error, (e) => setSheet(() => error = e)),
          ]),
        ),
      ),
    );
  }
}
