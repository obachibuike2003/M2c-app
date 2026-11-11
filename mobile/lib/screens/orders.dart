import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'payment.dart';

String _date(DateTime? d) {
  if (d == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}

class OrdersScreen extends StatefulWidget {
  /// True when it's the bottom bar's Orders tab (no back arrow).
  final bool asTab;
  const OrdersScreen({super.key, this.asTab = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _orders;
  int _version = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when an order is placed (the tab stays alive in the background).
    final v = context.select<AppState, int>((s) => s.ordersVersion);
    if (v != _version) {
      _version = v;
      _orders = context.read<AppState>().myOrders();
    }
  }

  Future<void> _reload() async {
    final f = context.read<AppState>().myOrders();
    setState(() => _orders = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders'), automaticallyImplyLeading: !widget.asTab),
      body: FutureBuilder<List<Order>>(
        future: _orders,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Brand.red));
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Couldn\'t load your orders',
              text: snap.error.toString(),
              action: FilledButton(onPressed: _reload, child: const Text('Try again')),
            );
          }
          final orders = snap.data!;
          if (orders.isEmpty) {
            return RefreshIndicator(
              color: Brand.red,
              onRefresh: _reload,
              child: ListView(children: const [
                SizedBox(height: 60),
                EmptyState(icon: Icons.inventory_2_outlined, title: 'No orders yet', text: 'When you place an order it shows up here, with every step from the factory in China to your door.'),
              ]),
            );
          }
          return RefreshIndicator(
            color: Brand.red,
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final o = orders[i];
                final last = AppConfig.trackStages.length - 1;
                return FadeIn(
                  delay: Duration(milliseconds: 40 * (i % 6)),
                  child: Pressable(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
                    child: CardBox(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(o.id, style: Brand.head(17)),
                          const Spacer(),
                          o.status == 'Awaiting payment' || o.status == 'Payment expired'
                              ? Pill(o.status, bg: const Color(0xFFFFF1D6), fg: const Color(0xFF8F4D00))
                              : Pill(o.status, bg: o.stage == last ? Brand.greenSoft : Brand.blueSoft, fg: o.stage == last ? Brand.green : Brand.blue),
                        ]),
                        const SizedBox(height: 4),
                        Text('${_date(o.createdAt)} · ${o.items.length} item${o.items.length == 1 ? '' : 's'} · ${money(o.total)}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                        if (!o.awaitingPayment && o.status != 'Cancelled' && o.status != 'Payment expired') ...[
                          const SizedBox(height: 6),
                          Text('Step ${o.stage + 1} of ${AppConfig.trackStages.length}: ${AppConfig.trackStages[o.stage.clamp(0, last)].text}',
                              style: const TextStyle(fontSize: 13, height: 1.35)),
                        ],
                        if (o.awaitingPayment)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                              onPressed: () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(order: o)));
                                if (mounted) _reload();
                              },
                              icon: const Icon(Icons.lock_outline, size: 17),
                              label: Text('Pay now · ${money(o.total)}'),
                            ),
                          ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: LinearProgressIndicator(
                            value: (o.stage + 1) / AppConfig.trackStages.length,
                            minHeight: 7,
                            backgroundColor: const Color(0xFFECECF0),
                            valueColor: const AlwaysStoppedAnimation(Brand.red),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final stages = AppConfig.trackStages;
    final when = <int, DateTime>{
      for (final t in (o.raw['tracking'] as List? ?? const []))
        if (t is Map && t['stage'] is num && DateTime.tryParse('${t['at']}') != null) (t['stage'] as num).toInt(): DateTime.parse('${t['at']}'),
    };
    final current = stages[o.stage.clamp(0, stages.length - 1)];
    return Scaffold(
      appBar: AppBar(title: Text(o.id)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Current status', style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 2),
            Text(o.awaitingPayment ? 'Awaiting payment' : current.name, style: Brand.head(22)),
            const SizedBox(height: 4),
            Text(o.awaitingPayment ? 'Pay for this order and we start on it straight away.' : current.text, style: const TextStyle(color: Brand.muted, height: 1.4)),
            const SizedBox(height: 18),
            for (var i = 0; i < stages.length; i++)
              _step(stages[i].name, o.awaitingPayment ? 'next' : i < o.stage ? 'done' : i == o.stage ? 'now' : 'next', i == stages.length - 1,
                  o.awaitingPayment ? null : when[i]),
          ]),
        ),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('What\'s in it', style: Brand.head(18)),
            const SizedBox(height: 10),
            for (final it in o.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${it['qty']} × ${it['name']}')),
                  Text(money(((it['price'] as num) * (it['qty'] as num))), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            const Divider(height: 22, color: Brand.line),
            Row(children: [Text('Total', style: Brand.head(17)), const Spacer(), Text(money(o.total), style: Brand.head(20, weight: FontWeight.w800))]),
          ]),
        ),
      ]),
    );
  }

  Widget _step(String name, String state, bool isLast, DateTime? at) {
    final done = state == 'done';
    final now = state == 'now';
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Brand.green : Colors.white,
              border: Border.all(color: done ? Brand.green : now ? Brand.red : const Color(0xFFD3D5DC), width: 2),
              boxShadow: now ? const [BoxShadow(color: Brand.redSoft, spreadRadius: 4)] : null,
            ),
            child: done
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : now
                    ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Brand.red, shape: BoxShape.circle)))
                    : null,
          ),
          if (!isLast) Expanded(child: Container(width: 2, color: done ? Brand.green : const Color(0xFFE2E3E8))),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontWeight: done || now ? FontWeight.w700 : FontWeight.w500, color: done || now ? Brand.ink : const Color(0xFF9A9EA8))),
              if ((done || now) && at != null) Text(_date(at), style: const TextStyle(color: Brand.muted, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}
