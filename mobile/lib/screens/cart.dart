import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';
import 'orders.dart';
import 'product.dart';

class CartScreen extends StatelessWidget {
  /// True when shown as a tab of the main shell (no back button).
  final bool asTab;
  const CartScreen({super.key, this.asTab = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final lines = s.cartLines;
    final short = lines.where((l) => l.short).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart'), automaticallyImplyLeading: !asTab),
      body: lines.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              text: 'Browse factory-priced goods from China and add what you like.',
              action: asTab ? null : FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Keep shopping')),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              for (final (i, l) in lines.indexed)
                FadeIn(
                  delay: Duration(milliseconds: 40 * (i % 6)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CardBox(
                      padding: const EdgeInsets.all(12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Pressable(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productId: l.product.id))),
                          child: Container(
                            width: 82,
                            height: 82,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFF2F3F6), borderRadius: BorderRadius.circular(12)),
                            // A customised line shows the design instead of the plain photo.
                            child: NetImage(
                              (l.custom?['preview'] as String?)?.isNotEmpty == true ? l.custom!['preview'] as String : l.product.img,
                              placeholder: CategoryBubble(category: s.category(l.product.cat), size: 56, showPhoto: false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${money(l.unit)}${s.isBusiness ? ' each' : ''}', style: Brand.head(16, color: Brand.red600)),
                            if (l.custom != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [
                                  const Icon(Icons.brush_outlined, size: 14, color: Brand.blue),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      (l.custom!['notes'] as String?)?.isNotEmpty == true ? 'Your logo · ${l.custom!['notes']}' : 'Customised with your logo',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Brand.blue, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ]),
                              ),
                            if (l.short)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Business minimum is ${s.minQty(l.product)}', style: const TextStyle(color: Color(0xFF8F4D00), fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            const SizedBox(height: 8),
                            Row(children: [
                              QtyStepper(value: l.qty, max: l.product.stock, onChanged: (v) => s.setQty(l.product.id, v)),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: () => s.setQty(l.product.id, 0),
                                icon: const Icon(Icons.delete_outline, color: Brand.muted),
                              ),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              CardBox(
                child: Column(children: [
                  _row('Subtotal', money(s.subtotal)),
                  _row('Delivery', s.shipping == 0 ? 'Free' : money(s.shipping)),
                  if (s.shipping > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text('Free delivery from ${money(AppConfig.freeShippingFrom)}. Add ${money(AppConfig.freeShippingFrom - s.subtotal)} more.',
                          style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                    ),
                  const Divider(height: 20, color: Brand.line),
                  Row(children: [
                    Text('Total', style: Brand.head(18)),
                    const Spacer(),
                    Text(money(s.total), style: Brand.head(22, weight: FontWeight.w800)),
                  ]),
                ]),
              ),
            ]),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton(
                  onPressed: short.isNotEmpty
                      ? () => showMessage(context, 'Business orders need at least ${s.minQty(short.first.product)} of "${short.first.product.name}".', error: true)
                      : () => _checkout(context, s),
                  child: Text('Checkout · ${money(s.total)}'),
                ),
              ),
            ),
    );
  }

  Future<void> _checkout(BuildContext context, AppState s) async {
    if (s.user == null) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen(reason: 'Sign in to place your order')));
      if (ok != true || !context.mounted) return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Text(label, style: const TextStyle(color: Brand.muted)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
      );
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _f;
  bool _busy = false;

  static const _fields = [('name', 'Full name'), ('phone', 'Phone number'), ('street', 'Street address'), ('city', 'City'), ('state', 'State')];

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final saved = s.user?.address ?? {};
    _f = {
      for (final (key, _) in _fields)
        key: TextEditingController(text: (saved[key] ?? (key == 'name' ? s.user?.name : key == 'phone' ? s.user?.phone : '') ?? '').toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _place() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = context.read<AppState>();
    try {
      final order = await s.placeOrder({for (final e in _f.entries) e.key: e.value.text.trim()});
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => OrderPlacedScreen(orderId: order.id, total: order.total)), (r) => r.isFirst);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivery address', style: Brand.head(18)),
              const SizedBox(height: 14),
              for (final (key, label) in _fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _f[key],
                    decoration: InputDecoration(labelText: label),
                    keyboardType: key == 'phone' ? TextInputType.phone : TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your ${label.toLowerCase()}' : null,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          CardBox(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Brand.redSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.payments_outlined, color: Brand.red600),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pay on delivery', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Pay when your goods arrive.', style: TextStyle(color: Brand.muted, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.check_circle, color: Brand.green),
            ]),
          ),
          const SizedBox(height: 14),
          CardBox(
            child: Column(children: [
              for (final l in s.cartLines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('${l.qty} × ${l.product.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(money(l.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              const Divider(height: 20, color: Brand.line),
              Row(children: [const Text('Delivery', style: TextStyle(color: Brand.muted)), const Spacer(), Text(s.shipping == 0 ? 'Free' : money(s.shipping))]),
              const SizedBox(height: 8),
              Row(children: [Text('Total', style: Brand.head(18)), const Spacer(), Text(money(s.total), style: Brand.head(22, weight: FontWeight.w800))]),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FilledButton(
            onPressed: _busy || s.cartLines.isEmpty ? null : _place,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text('Place order · ${money(s.total)}'),
          ),
        ),
      ),
    );
  }
}

class OrderPlacedScreen extends StatelessWidget {
  final String orderId;
  final int total;
  const OrderPlacedScreen({super.key, required this.orderId, required this.total});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: Duration(milliseconds: reduceMotion(context) ? 0 : 520),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(color: Brand.greenSoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Brand.green, size: 62),
              ),
            ),
            const SizedBox(height: 24),
            Text('Order placed!', style: Brand.head(28, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('$orderId · ${money(total)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('We\'ll buy your goods from the factory and keep you posted at every step.',
                textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, height: 1.5)),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OrdersScreen())),
              child: const Text('Track my order'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue shopping'),
            ),
          ]),
        ),
      ),
    );
  }
}
