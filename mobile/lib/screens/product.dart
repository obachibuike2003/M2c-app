import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../media.dart';
import 'cart.dart';
import 'studio.dart';

class ProductScreen extends StatefulWidget {
  final String productId;
  const ProductScreen({super.key, required this.productId});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _pages = PageController();
  int _photo = 0;
  int? _qty;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Same idea as the website's "You may also like": shared words in the name
  /// first (same brand or kind of item), then the same category.
  List<Product> _related(AppState s, Product p) {
    const stop = {'plus', 'pro', 'max', 'mini', 'lite', 'series', 'touring', 'sxt', 'gt', 'edition', 'note', 'the', 'and', 'with', 'for'};
    Set<String> words(String t) => t.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 2 && !stop.contains(w)).toSet();
    final base = words(p.name);
    final scored = [
      for (final x in s.products)
        if (x.id != p.id) (x: x, score: words(x.name).intersection(base).length * 3 + (x.cat == p.cat ? 1 : 0)),
    ]..removeWhere((e) => e.score == 0);
    scored.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : b.x.sold.compareTo(a.x.sold));
    return scored.take(6).map((e) => e.x).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.product(widget.productId);
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.inventory_2_outlined, title: 'Product not found', text: 'It may have been removed.'));
    }
    final min = s.minQty(p);
    final qty = (_qty ?? min).clamp(min, p.stock < min ? min : p.stock);
    final unit = s.unitPrice(p, qty);
    final out = p.stock < min;
    final photos = p.photos;
    final cat = s.category(p.cat);
    final fav = s.isFav(p.id);

    return Scaffold(
      backgroundColor: Brand.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: MediaQuery.sizeOf(context).width.clamp(280, 460),
          backgroundColor: Colors.white,
          leading: _circleBtn(context, Icons.arrow_back, () => Navigator.pop(context)),
          actions: [
            _circleBtn(context, fav ? Icons.favorite : Icons.favorite_border, () => toggleFavourite(context, p), color: fav ? Brand.red : Brand.ink),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: const Color(0xFFF2F3F6),
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 36),
              child: photos.isEmpty
                  ? Center(child: CategoryBubble(category: cat, size: 150, showPhoto: false))
                  : PageView.builder(
                      controller: _pages,
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) {
                        final img = NetImage(photos[i], placeholder: const SizedBox());
                        return i == 0 ? Hero(tag: 'p-${p.id}', child: img) : img;
                      },
                    ),
            ),
          ),
          bottom: photos.length > 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(18),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < photos.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: easeOutStrong,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _photo ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(color: i == _photo ? Brand.red : const Color(0xFFCDCFD6), borderRadius: BorderRadius.circular(9)),
                        ),
                    ]),
                  ),
                )
              : null,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((cat?.name ?? '').toUpperCase(), style: const TextStyle(color: Brand.red600, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(p.name, style: Brand.head(24)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Brand.star, size: 18),
                      Text(' ${p.rating > 0 ? p.rating.toStringAsFixed(1) : 'New'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    Text('${compact(p.sold)} sold', style: const TextStyle(color: Brand.muted)),
                    Pill(p.used ? 'Used' : 'Brand new', bg: p.used ? const Color(0xFFFFF1D6) : Brand.blueSoft, fg: p.used ? const Color(0xFF8F4D00) : Brand.blue),
                    p.stock < 1 ? const Pill('Out of stock', bg: Color(0xFFEEEFF3), fg: Brand.muted) : Pill('${p.stock} in stock', bg: Brand.greenSoft, fg: Brand.green),
                  ]),
                  const SizedBox(height: 16),
                  _priceBox(s, p, unit, qty, min),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    QtyStepper(value: qty, min: min, max: p.stock < min ? min : p.stock, onChanged: (v) => setState(() => _qty = v)),
                  ]),
                  if (s.isBusiness) ...[
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: Text('Total ${money(unit * qty)}', style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600))),
                  ],
                  if (out && p.stock > 0) ...[
                    const SizedBox(height: 12),
                    _notice('Only ${p.stock} left, which is below the business minimum of $min. Switch to personal to buy what\'s left.'),
                  ],
                ]),
              ),
              if (s.isBusiness && isCustomizable(p)) ...[
                const SizedBox(height: 12),
                // AiStudio: business buyers can have their own logo put on the goods.
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: Brand.blueSoft, foregroundColor: Brand.blue, minimumSize: const Size.fromHeight(50)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudioScreen(productId: p.id))),
                  icon: const Icon(Icons.brush_outlined, size: 19),
                  label: const Text('Customise with your logo'),
                ),
              ],
              const SizedBox(height: 14),
              CardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('About this item', style: Brand.head(18)),
                  const SizedBox(height: 8),
                  Text(p.desc, style: const TextStyle(height: 1.55)),
                  const Divider(height: 28, color: Brand.line),
                  _fact(Icons.local_shipping_outlined, 'Ships from China, arrives in about ${p.ship} days.'),
                  _fact(Icons.check_circle_outline, 'Free delivery on orders above ${money(AppConfig.freeShippingFrom)}'),
                  _fact(Icons.verified_user_outlined, 'Pay on delivery. Buyer protection on every order.'),
                ]),
              ),
              Builder(builder: (context) {
                final related = _related(s, p);
                if (related.isEmpty) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(children: [
                    const SectionHead(kicker: 'More like this', title: 'You may also like'),
                    ProductGrid(products: related),
                  ]),
                );
              }),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Brand.line))),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: out ? null : () => _add(context, s, p, qty),
                icon: const Icon(Icons.shopping_cart_outlined, size: 19),
                label: const Text('Add to cart'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: out
                    ? null
                    : () {
                        if (_add(context, s, p, qty, quiet: true)) {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
                        }
                      },
                child: const Text('Buy now'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  bool _add(BuildContext context, AppState s, Product p, int qty, {bool quiet = false}) {
    final err = s.addToCart(p, qty);
    if (err != null || !quiet) showMessage(context, err ?? (qty > 1 ? 'Added $qty to cart' : 'Added to cart'), error: err != null);
    return err == null;
  }

  Widget _priceBox(AppState s, Product p, int unit, int qty, int min) {
    final box = BoxDecoration(color: Brand.bg, borderRadius: BorderRadius.circular(14));
    if (!s.isBusiness) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: box,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(money(p.price), style: Brand.head(30, weight: FontWeight.w800, color: Brand.red600)),
            if (p.discount > 0) ...[
              Text(money(p.oldPrice), style: const TextStyle(color: Brand.muted, decoration: TextDecoration.lineThrough)),
              Pill('Save ${p.discount}%', bg: Brand.greenSoft, fg: Brand.green),
            ],
          ]),
          if (p.stock >= p.businessMin) ...[
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Buying for your business? ', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: 'Get it for ${money(p.price * (1 - AppConfig.bulkTiers.last.off / 100))} each from ${AppConfig.bulkTiers.last.from} pieces. Switch to Business on your account.'),
            ]), style: const TextStyle(fontSize: 13, color: Brand.muted, height: 1.4)),
          ],
        ]),
      );
    }
    final tiers = [(from: min, off: s.bulkOff(min)), ...AppConfig.bulkTiers.where((t) => t.from > min)];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF5F6), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Wholesale price per piece', style: TextStyle(color: Brand.muted, fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(money(unit), style: Brand.head(30, weight: FontWeight.w800, color: Brand.red600)),
          Pill('Min. order $min'),
        ]),
        const SizedBox(height: 10),
        for (final t in tiers)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _activeTier(tiers, qty) == t.from ? Brand.blue : Brand.line, width: _activeTier(tiers, qty) == t.from ? 1.5 : 1),
            ),
            child: Row(children: [
              Text('${t.from}+ pieces'),
              const Spacer(),
              Text(money(p.price * (1 - t.off / 100)), style: const TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(width: 64, child: Text(t.off > 0 ? '${t.off}% off' : 'each', textAlign: TextAlign.right, style: const TextStyle(color: Brand.muted, fontSize: 12))),
            ]),
          ),
      ]),
    );
  }

  int _activeTier(List<({int from, int off})> tiers, int qty) => tiers.lastWhere((t) => qty >= t.from, orElse: () => tiers.first).from;

  Widget _fact(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: Brand.red600),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ]),
      );

  Widget _notice(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Color(0xFF5C3200), fontSize: 13)),
      );

  Widget _circleBtn(BuildContext context, IconData icon, VoidCallback onTap, {Color color = Brand.ink}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Pressable(
          onTap: onTap,
          scale: 0.9,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1A111216), blurRadius: 8, offset: Offset(0, 2))]),
            child: Icon(icon, color: color, size: 21),
          ),
        ),
      );
}
