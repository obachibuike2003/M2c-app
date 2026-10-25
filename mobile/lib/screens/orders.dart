import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

String _date(DateTime? d) {
  if (d == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = context.read<AppState>().myOrders();
  }

  Future<void> _reload() async {
    final f = context.read<AppState>().myOrders();
    setState(() => _orders = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
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
            return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No orders yet', text: 'When you place an order it shows up here, with every step from China to your door.');
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
                          Pill(o.status, bg: o.stage == last ? Brand.greenSoft : Brand.blueSoft, fg: o.stage == last ? Brand.green : Brand.blue),
                        ]),
                        const SizedBox(height: 4),
                        Text('${_date(o.createdAt)} · ${o.items.length} item${o.items.length == 1 ? '' : 's'} · ${money(o.total)}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
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
    return Scaffold(
      appBar: AppBar(title: Text(o.id)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Current status', style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 2),
            Text(stages[o.stage.clamp(0, stages.length - 1)], style: Brand.head(22)),
            const SizedBox(height: 18),
            for (var i = 0; i < stages.length; i++) _step(stages[i], i < o.stage ? 'done' : i == o.stage ? 'now' : 'next', i == stages.length - 1),
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

  Widget _step(String name, String state, bool isLast) {
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
            child: Text(name, style: TextStyle(fontWeight: done || now ? FontWeight.w700 : FontWeight.w500, color: done || now ? Brand.ink : const Color(0xFF9A9EA8))),
          ),
        ),
      ]),
    );
  }
}
