import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../app_state.dart';
import '../media.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart.dart';

/// Opens Nomba's payment page for an order and waits for the server to
/// confirm the payment. It checks every few seconds and whenever the person
/// comes back to the app, so they never have to tell us they've paid.
class PaymentScreen extends StatefulWidget {
  final Order order;

  /// Open Nomba's page straight away (true when coming from checkout).
  final bool openNow;
  const PaymentScreen({super.key, required this.order, this.openNow = true});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with WidgetsBindingObserver {
  late Order _order = widget.order;
  Timer? _timer;
  bool _checking = false;
  int _checks = 0;

  String? get _link => (_order.raw['payment'] as Map?)?['checkoutLink'] as String?;
  String get _status => ((_order.raw['payment'] as Map?)?['status'] ?? 'pending') as String;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.openNow) WidgetsBinding.instance.addPostFrameCallback((_) => _openPage());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Back from Nomba's page: look straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _openPage() {
    final link = _link;
    if (link != null) openLink(context, Uri.parse(link));
  }

  Future<void> _check() async {
    if (_checking || _status != 'pending') return;
    _checking = true;
    try {
      final o = await context.read<AppState>().paymentStatus(_order.id);
      if (!mounted) return;
      setState(() {
        _order = o;
        _checks++;
      });
      if (_status != 'pending') {
        _timer?.cancel();
        if (_status == 'paid') {
          context.read<AppState>().ordersChanged();
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderPlacedScreen(orderId: o.id, total: o.total, paid: true)));
        }
      }
    } on ApiException {
      // Offline for a moment: the next tick tries again.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _status == 'expired';
    final underpaid = _status == 'underpaid';
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Spacer(),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: expired || underpaid ? Brand.redSoft : Brand.blueSoft, shape: BoxShape.circle),
              child: expired || underpaid
                  ? const Icon(Icons.error_outline, color: Brand.red600, size: 48)
                  : const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(strokeWidth: 3.5, color: Brand.blue)),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            expired ? 'Payment time ran out' : underpaid ? 'Part of the payment is missing' : 'Waiting for your payment',
            textAlign: TextAlign.center,
            style: Brand.head(24),
          ),
          const SizedBox(height: 8),
          Text(
            expired
                ? 'This order wasn\'t paid within the hour, so we released the items. You can order them again.'
                : underpaid
                    ? 'We received less than the order total. Our team will contact you, or chat with customer care.'
                    : 'Pay on Nomba\'s secure page with card, bank transfer or USSD. This screen updates by itself once it\'s done.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          CardBox(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_order.id, style: Brand.head(16)),
                  const Text('Pay with Nomba', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              Text(money(_order.total), style: Brand.head(20, weight: FontWeight.w800)),
            ]),
          ),
          const Spacer(),
          if (!expired && !underpaid) ...[
            FilledButton.icon(
              onPressed: _link == null ? null : _openPage,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Open payment page'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _checking ? null : _check,
              child: Text(_checks == 0 ? 'I\'ve paid, check now' : 'Check again'),
            ),
          ] else
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        ]),
      ),
    );
  }
}
