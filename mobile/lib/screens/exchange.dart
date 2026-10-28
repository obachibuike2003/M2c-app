import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';

/// Naira to yuan and crypto and back, using the wallet on the account.
/// Same rates and maths as the website's exchange page.
class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  final _amount = TextEditingController();
  bool _buy = true; // buy = naira to asset, sell = asset to naira
  String _asset = 'CNY';
  String? _error;
  bool _busy = false;

  String get _from => _buy ? 'NGN' : _asset;
  String get _to => _buy ? _asset : 'NGN';
  num get _value => num.tryParse(_amount.text.trim()) ?? 0;
  ({String code, String name, bool crypto, int dp, double buy, double sell}) get _rate =>
      AppConfig.rates.firstWhere((r) => r.code == _asset);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _setMode(bool buy) => setState(() {
        _buy = buy;
        _amount.clear();
        _error = null;
      });

  Future<void> _submit() async {
    final s = context.read<AppState>();
    if (s.user == null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen(reason: 'Sign in to exchange with your wallet.')));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final got = await s.exchange(_from, _to, _value);
      if (!mounted) return;
      _amount.clear();
      showMessage(context, 'You received ${moneyIn(got, _to)}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final signedIn = s.user != null;
    final balance = s.balances[_from] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Exchange'), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Text('Naira to RMB and crypto, in seconds.', style: Brand.head(22)),
        const SizedBox(height: 4),
        const Text('Change naira to yuan, USDT, Bitcoin and more at clear rates.', style: TextStyle(color: Brand.muted, height: 1.4)),
        const SizedBox(height: 16),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Buy with naira')),
                ButtonSegment(value: false, label: Text('Sell for naira')),
              ],
              selected: {_buy},
              showSelectedIcon: false,
              onSelectionChanged: (v) => _setMode(v.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Brand.ink,
                selectedForegroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            _box(
              label: 'You pay',
              value: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                onChanged: (_) => setState(() => _error = null),
                style: Brand.head(26),
                decoration: const InputDecoration(hintText: '0', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.zero),
              ),
              code: _from,
            ),
            Center(
              child: Pressable(
                  onTap: () => _setMode(!_buy),
                  scale: 0.9,
                  child: Semantics(
                    button: true,
                    label: 'Swap direction',
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Brand.line), boxShadow: Brand.shadow),
                      child: const Icon(Icons.swap_vert_rounded, color: Brand.red600),
                    ),
                  ),
                ),
            ),
            _box(
              label: 'You receive',
              value: Text(moneyIn(s.quote(_from, _to, _value), _to), style: Brand.head(26), maxLines: 1, overflow: TextOverflow.ellipsis),
              code: _to,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('1 $_asset = ${money(_buy ? _rate.buy : _rate.sell)}', style: const TextStyle(color: Brand.muted, fontSize: 13))),
              if (signedIn) ...[
                Text('Balance: ${moneyIn(balance, _from)}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                TextButton(
                  onPressed: balance > 0 ? () => setState(() => _amount.text = '$balance') : null,
                  child: const Text('Use all'),
                ),
              ],
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: const TextStyle(color: Brand.red600, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(signedIn ? 'Exchange $_from to $_to' : 'Sign in to exchange'),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        signedIn ? _wallet(s) : _howItWorks(),
        const SizedBox(height: 22),
        const SectionHead(kicker: 'Rates', title: 'Today\'s rates'),
        CardBox(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (final (i, r) in AppConfig.rates.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
              InkWell(
                onTap: () => setState(() {
                  _asset = r.code;
                  _amount.clear();
                  _error = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    _CoinDot(code: r.code, selected: r.code == _asset),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('1 ${r.code}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Buy ${money(r.buy)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Sell ${money(r.sell)}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                    ]),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        const Text('Demo rates, set by Easy2buy. They are not live market prices.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _box({required String label, required Widget value, required String code}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(color: Brand.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: value),
            const SizedBox(width: 8),
            code == 'NGN' ? const _CodeChip('NGN') : _assetPicker(),
          ]),
        ]),
      );

  Widget _assetPicker() => PopupMenuButton<String>(
        initialValue: _asset,
        tooltip: 'Currency',
        onSelected: (c) => setState(() {
          _asset = c;
          _error = null;
        }),
        itemBuilder: (_) => [for (final r in AppConfig.rates) PopupMenuItem(value: r.code, child: Text('${r.code}  ·  ${r.name}'))],
        child: _CodeChip(_asset, dropdown: true),
      );

  Widget _wallet(AppState s) {
    final b = s.balances;
    final held = AppConfig.rates.where((r) => (b[r.code] ?? 0) > 0);
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your wallet', style: Brand.head(18)),
        const SizedBox(height: 10),
        _walletRow('Naira', moneyIn(b['NGN'] ?? 0, 'NGN')),
        for (final r in held) _walletRow(r.name, moneyIn(b[r.code]!, r.code)),
        if ((b['NGN'] ?? 0) == 0 && held.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Your wallet is empty. Add naira from the website\'s wallet page to start exchanging.', style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.4)),
          ),
      ]),
    );
  }

  Widget _walletRow(String name, String amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(color: Brand.muted))),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _howItWorks() => CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How it works', style: Brand.head(18)),
          const SizedBox(height: 10),
          for (final step in const [
            'Create an account and add naira to your wallet',
            'Exchange naira to yuan (RMB) or crypto at the rate shown',
            'Send it out to Alipay, WeChat, a bank or a crypto address',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle, color: Brand.green, size: 19),
                const SizedBox(width: 10),
                Expanded(child: Text(step, style: const TextStyle(height: 1.4))),
              ]),
            ),
        ]),
      );
}

class _CodeChip extends StatelessWidget {
  final String code;
  final bool dropdown;
  const _CodeChip(this.code, {this.dropdown = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(12, 8, dropdown ? 6 : 12, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: Brand.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(code, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (dropdown) const Icon(Icons.expand_more_rounded, size: 20, color: Brand.muted),
        ]),
      );
}

class _CoinDot extends StatelessWidget {
  final String code;
  final bool selected;
  const _CoinDot({required this.code, required this.selected});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: easeOutStrong,
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? Brand.red : Brand.redSoft, shape: BoxShape.circle),
        child: Text(code.length > 3 ? code.substring(0, 3) : code,
            style: TextStyle(color: selected ? Colors.white : Brand.red600, fontWeight: FontWeight.w800, fontSize: 11.5)),
      );
}
