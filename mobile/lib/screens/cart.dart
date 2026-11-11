import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';
import '../api.dart';
import 'orders.dart';
import 'payment.dart';
import '../media.dart';
import '../models.dart';
import 'product.dart';
import 'studio.dart';

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
                            if (s.isBusiness && l.custom == null && isCustomizable(l.product))
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Pressable(
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudioScreen(productId: l.product.id))),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Brand.blueSoft, borderRadius: BorderRadius.circular(99)),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.brush_outlined, size: 15, color: Brand.blue),
                                      SizedBox(width: 5),
                                      Text('Add your logo', style: TextStyle(color: Brand.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    ]),
                                  ),
                                ),
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
              if (s.user != null) ...[
                const _AddressCard(),
                const SizedBox(height: 10),
              ],
              CardBox(
                child: Column(children: [
                  _row('Subtotal', money(s.subtotal)),
                  if (s.creditToUse > 0) _row('Referral credit', '-${money(s.creditToUse)}'),
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
      bottomNavigationBar: lines.isEmpty ? null : _PayBar(short: short),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Text(label, style: const TextStyle(color: Brand.muted)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
      );
}

const _addressFields = [('name', 'Full name'), ('phone', 'Phone number'), ('street', 'Street address'), ('city', 'City'), ('state', 'State')];

bool _addressComplete(Map<String, dynamic>? a) => a != null && _addressFields.every((f) => '${a[f.$1] ?? ''}'.trim().isNotEmpty);

/// Where the order goes, shown in the cart like Jumia and Temu. Tap to change.
class _AddressCard extends StatelessWidget {
  const _AddressCard();

  @override
  Widget build(BuildContext context) {
    final a = context.select<AppState, Map<String, dynamic>?>((s) => s.user?.address);
    final ok = _addressComplete(a);
    return Pressable(
      onTap: () => editAddress(context),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Brand.redSoft, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.location_on_outlined, color: Brand.red600, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ok
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a!['name']} · ${a['phone']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${a['street']}, ${a['city']}, ${a['state']}', style: const TextStyle(color: Brand.muted, fontSize: 13, height: 1.35)),
                  ])
                : const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add your delivery address', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Where should we deliver your order?', style: TextStyle(color: Brand.muted, fontSize: 13)),
                  ]),
          ),
          Text(ok ? 'Change' : 'Add', style: const TextStyle(color: Brand.red600, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Asks for the delivery address in a sheet and saves it on the account.
/// Returns the address, or null if they closed it.
Future<Map<String, String>?> editAddress(BuildContext context) {
  final s = context.read<AppState>();
  final saved = s.user?.address ?? {};
  final form = GlobalKey<FormState>();
  final f = {
    for (final (key, _) in _addressFields)
      key: TextEditingController(text: '${saved[key] ?? (key == 'name' ? s.user?.name : key == 'phone' ? s.user?.phone : '') ?? ''}'),
  };
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    sheetAnimationStyle: AnimationStyle(curve: easeDrawer, duration: const Duration(milliseconds: 340), reverseDuration: const Duration(milliseconds: 200)),
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Delivery address', style: Brand.head(22)),
              const SizedBox(height: 14),
              for (final (key, label) in _addressFields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: f[key],
                    decoration: InputDecoration(labelText: label),
                    keyboardType: key == 'phone' ? TextInputType.phone : TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your ${label.toLowerCase()}' : null,
                  ),
                ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  final address = {for (final e in f.entries) e.key: e.value.text.trim()};
                  try {
                    await s.updateAccount({'address': address});
                  } catch (_) {/* still use it for this order */}
                  if (sheet.mounted) Navigator.pop(sheet, address);
                },
                child: const Text('Save address'),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// The bar at the bottom of the cart: the total and one Pay button, like
/// Temu and Jumia. Pay places the order and goes straight to payment.
class _PayBar extends StatefulWidget {
  final List<CartView> short;
  const _PayBar({required this.short});

  @override
  State<_PayBar> createState() => _PayBarState();
}

class _PayBarState extends State<_PayBar> {
  bool _busy = false;

  Future<void> _pay() async {
    final s = context.read<AppState>();
    if (widget.short.isNotEmpty) {
      final l = widget.short.first;
      return showMessage(context, 'Business orders need at least ${s.minQty(l.product)} of "${l.product.name}".', error: true);
    }
    if (s.user == null) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen(reason: 'Sign in to pay for your order')));
      if (ok != true || !mounted) return;
    }
    // Business buyers: offer their logo on the goods before they pay.
    final plain = s.isBusiness ? s.cartLines.where((l) => l.custom == null && isCustomizable(l.product)).toList() : const <CartView>[];
    if (plain.isNotEmpty) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        sheetAnimationStyle: AnimationStyle(curve: easeDrawer, duration: const Duration(milliseconds: 340), reverseDuration: const Duration(milliseconds: 200)),
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Add your logo first?', style: Brand.head(22)),
              const SizedBox(height: 6),
              Text(
                '${plain.length == 1 ? plain.first.product.name : '${plain.length} items in your cart'} can carry your brand. '
                'The factory prints it before shipping.',
                style: const TextStyle(color: Brand.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheet, 'brand'),
                icon: const Icon(Icons.brush_outlined, size: 19),
                label: Text(plain.length == 1 ? 'Customise with my logo' : 'Customise ${plain.first.product.name}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => Navigator.pop(sheet, 'skip'), child: const Text('Pay without')),
            ]),
          ),
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'brand') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudioScreen(productId: plain.first.product.id)));
        return;
      }
    }
    if (!mounted) return;
    Map<String, dynamic>? address = s.user?.address;
    if (!_addressComplete(address)) {
      address = await editAddress(context);
      if (address == null || !mounted) return;
    }

    // Placing the order empties the cart, which removes this bar, so keep the
    // navigator and messenger now to open the payment page afterwards.
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final addr = {for (final (key, _) in _addressFields) key: '${address![key]}'.trim()};
      Order order;
      try {
        order = await s.placeOrder(addr, pay: s.payOnline ? 'nomba' : 'delivery');
      } on ApiException catch (e) {
        if (e.code != 'pay_off') rethrow;
        s.payOnline = false; // switched off on the server since we last looked
        order = await s.placeOrder(addr, pay: 'delivery');
      }
      final Widget next = order.awaitingPayment ? PaymentScreen(order: order) : OrderPlacedScreen(orderId: order.id, total: order.total);
      nav.push(MaterialPageRoute(builder: (_) => next));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Brand.red600));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Brand.red600));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final count = s.cartCount;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Brand.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total', style: TextStyle(color: Brand.muted, fontSize: 13)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money(s.total), style: Brand.head(24, weight: FontWeight.w800)),
                ),
                Text(s.shipping == 0 ? 'Free delivery' : 'Includes ${money(s.shipping)} delivery',
                    style: TextStyle(color: s.shipping == 0 ? Brand.green : Brand.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 26)),
                onPressed: _busy ? null : _pay,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : Icon(s.payOnline ? Icons.lock_outline : Icons.check_rounded, size: 19),
                label: Text('${s.payOnline ? 'Pay' : 'Place order'} ($count)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class OrderPlacedScreen extends StatelessWidget {
  final String orderId;
  final int total;

  /// Paid online (vs pay on delivery), for the wording.
  final bool paid;
  const OrderPlacedScreen({super.key, required this.orderId, required this.total, this.paid = false});

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
            Text(paid ? 'Payment received!' : 'Order placed!', style: Brand.head(28, weight: FontWeight.w800)),
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
