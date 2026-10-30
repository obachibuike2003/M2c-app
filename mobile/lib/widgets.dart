import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'config.dart';
import 'models.dart';
import 'media.dart';
import 'screens/product.dart';
import 'screens/studio.dart';
import 'theme.dart';

// ---------------------------------------------------------------- motion

/// Strong ease-out: starts fast so the UI feels like it heard you.
const easeOutStrong = Cubic(0.23, 1, 0.32, 1);

/// iOS-like drawer curve, for sheets and things that slide in.
const easeDrawer = Cubic(0.32, 0.72, 0, 1);

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Anything tappable presses down slightly, so the app feels like it's listening.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 140),
        curve: easeOutStrong,
        child: widget.child,
      ),
    );
  }
}

/// Fades and rises into place, after [delay]. Used to stagger grids; it never
/// blocks taps, and does nothing when the phone asks for reduced motion.
class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    const d = Duration(milliseconds: 320);
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: d,
      curve: easeOutStrong,
      child: AnimatedSlide(offset: _shown ? Offset.zero : const Offset(0, 0.04), duration: d, curve: easeOutStrong, child: widget.child),
    );
  }
}

// ---------------------------------------------------------------- formatting

String money(num amount) {
  final whole = amount.round().abs().toString();
  final out = StringBuffer(amount < 0 ? '-₦' : '₦');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return out.toString();
}

/// An amount in any wallet currency: ₦ and ¥ get symbols, crypto shows its code.
String moneyIn(num amount, String code) {
  var s = amount.abs().toStringAsFixed(AppState.dpOf(code));
  // Like the site: yuan always shows 2 decimals, everything else drops trailing zeros.
  if (code != 'CNY' && s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  final parts = s.split('.');
  final n = '${amount < 0 ? '-' : ''}${money(int.parse(parts[0])).substring(1)}${parts.length > 1 ? '.${parts[1]}' : ''}';
  return code == 'NGN' ? '₦$n' : code == 'CNY' ? '¥$n' : '$n $code';
}

String compact(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.0', '')}k' : '$n';

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle, color: error ? const Color(0xFFFF8A95) : const Color(0xFF6BE3A0), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(milliseconds: 2600),
    ));
}

// ---------------------------------------------------------------- brand

/// The red shopping bag with the "E" (assets/logo_mark.png, cut from assets/Easybuy.jpeg).
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/logo_mark.png',
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: '${AppConfig.appName} logo',
      );
}

class Logo extends StatelessWidget {
  final Color color;
  const Logo({super.key, this.color = Brand.ink});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const LogoMark(),
        const SizedBox(width: 9),
        Wordmark(size: 22, color: color),
      ]);
}

/// "Eazy2buy" with a tiny "china" after it, matching the domain eazy2buychina.com.
class Wordmark extends StatelessWidget {
  final double size;
  final Color color, chinaColor;
  const Wordmark({super.key, this.size = 22, this.color = Brand.ink, this.chinaColor = Brand.red600});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${AppConfig.appName} China',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(AppConfig.appName, style: Brand.head(size, weight: FontWeight.w800, color: color).copyWith(letterSpacing: -size * 0.02)),
          const SizedBox(width: 2),
          // Small but readable: never below 10 points.
          Text('china', style: TextStyle(fontSize: size * 0.5 < 10 ? 10 : size * 0.5, fontWeight: FontWeight.w700, color: chinaColor, letterSpacing: 0.3)),
        ]),
      );
}

// ---------------------------------------------------------------- images

/// Product and category photos: a path on the website, a full URL, or an
/// uploaded image saved as a data: URL. Falls back to [placeholder].
class NetImage extends StatelessWidget {
  final String src;
  final BoxFit fit;
  final Widget placeholder;
  const NetImage(this.src, {super.key, this.fit = BoxFit.contain, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return placeholder;
    if (src.startsWith('data:')) {
      try {
        return Image.memory(base64Decode(src.substring(src.indexOf(',') + 1)), fit: fit, errorBuilder: (_, _, _) => placeholder);
      } catch (_) {
        return placeholder;
      }
    }
    final url = src.startsWith('http') ? src : '${AppConfig.siteBase}/$src';
    return Image.network(
      url,
      fit: fit,
      // On the web build, fall back to a plain <img> if the photo host has no CORS headers.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 220), curve: easeOutStrong, child: child),
    );
  }
}

const _categoryIcons = <String, IconData>{
  'factory': Icons.factory_outlined, 'flask': Icons.science_outlined, 'phone': Icons.smartphone,
  'monitor': Icons.desktop_windows_outlined, 'cpu': Icons.memory, 'shirt': Icons.checkroom,
  'sparkle': Icons.auto_awesome_outlined, 'droplet': Icons.water_drop_outlined, 'sofa': Icons.weekend_outlined,
  'cup': Icons.coffee_outlined, 'bag': Icons.shopping_bag_outlined, 'clock': Icons.watch_outlined,
  'smile': Icons.sports_soccer, 'car': Icons.directions_car_outlined, 'box': Icons.inventory_2_outlined,
};

IconData categoryIcon(String name) => _categoryIcons[name] ?? Icons.inventory_2_outlined;

/// The soft tinted circle used for categories (and as a stand-in product photo).
class CategoryBubble extends StatelessWidget {
  final Category? category;
  final double size;
  final bool showPhoto;
  const CategoryBubble({super.key, required this.category, this.size = 64, this.showPhoto = true});

  @override
  Widget build(BuildContext context) {
    final hue = (category?.hue ?? 220).toDouble();
    final icon = Icon(categoryIcon(category?.icon ?? 'box'), size: size * 0.42, color: HSLColor.fromAHSL(1, hue, 0.5, 0.38).toColor());
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.4, -0.5), radius: 1.1, colors: [Colors.white, HSLColor.fromAHSL(1, hue, 0.75, 0.9).toColor()]),
        boxShadow: const [BoxShadow(color: Color(0x0D111216), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Center(child: showPhoto && category != null ? NetImage(category!.img, placeholder: icon) : icon),
    );
  }
}

// ---------------------------------------------------------------- products

class ProductCard extends StatelessWidget {
  final Product product;
  final int index;

  /// Flash-deal style: a "claimed" bar in place of the rating row, like the site.
  final bool deal;
  const ProductCard({super.key, required this.product, this.index = 0, this.deal = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = product;
    final min = s.minQty(p);
    final unit = s.unitPrice(p, min);
    final out = p.stock < min;
    final fav = s.isFav(p.id);

    return FadeIn(
      delay: Duration(milliseconds: 40 * (index % 6)),
      child: Pressable(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productId: p.id))),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Brand.radius), boxShadow: Brand.shadow),
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFF2F3F6), borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.all(10),
                    child: Hero(
                      tag: 'p-${p.id}',
                      child: NetImage(p.img, placeholder: Center(child: CategoryBubble(category: s.category(p.cat), showPhoto: false))),
                    ),
                  ),
                ),
                if (p.used) Positioned(left: 8, bottom: 8, child: _badge('Used', const Color(0xFFFFF1D6), const Color(0xFF8F4D00))),
                if (!s.isBusiness && p.discount > 0)
                  Positioned(left: 6, top: 6, child: _badge('-${p.discount}%', Brand.red, Colors.white)),
                // Business buyers: put your logo on it (AiStudio), like the website's red "+".
                if (s.isBusiness && isCustomizable(p) && !out)
                  Positioned(
                    top: 6,
                    right: 46,
                    child: _RoundIconButton(
                      icon: Icons.add,
                      color: Brand.red700,
                      label: 'Customise ${p.name} with your logo',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudioScreen(productId: p.id))),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _RoundIconButton(
                    icon: fav ? Icons.favorite : Icons.favorite_border,
                    color: fav ? Brand.red : Brand.muted,
                    onTap: () => _toggleFav(context, s, p),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _RoundIconButton(
                    icon: out ? Icons.close : Icons.add,
                    dark: true,
                    onTap: out
                        ? null
                        : () {
                            final err = s.addToCart(p, min);
                            showMessage(context, err ?? (min > 1 ? 'Added $min to cart' : 'Added to cart'), error: err != null);
                          },
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.25)),
            const SizedBox(height: 6),
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
              Text(money(unit), style: Brand.head(16, color: Brand.red600)),
              if (s.isBusiness)
                Text(out ? 'Not enough for bulk' : 'each · min. $min', style: const TextStyle(fontSize: 11, color: Brand.blue, fontWeight: FontWeight.w600))
              else if (p.discount > 0)
                Text(money(p.oldPrice), style: const TextStyle(fontSize: 11.5, color: Brand.muted, decoration: TextDecoration.lineThrough)),
            ]),
            const SizedBox(height: 4),
            if (deal)
              _Claimed(percent: 35 + p.sold % 58) // same made-up-but-stable figure the site shows
            else
            Row(children: [
              const Icon(Icons.star_rounded, size: 15, color: Brand.star),
              Text(' ${p.rating > 0 ? p.rating.toStringAsFixed(1) : 'New'}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${compact(p.sold)} sold', style: const TextStyle(fontSize: 11.5, color: Brand.muted)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Claimed extends StatelessWidget {
  final int percent;
  const _Claimed({required this.percent});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: Brand.redSoft,
              valueColor: const AlwaysStoppedAnimation(Brand.red),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$percent% claimed', style: const TextStyle(fontSize: 11, color: Brand.muted, fontWeight: FontWeight.w600)),
      ]);
}

Future<void> _toggleFav(BuildContext context, AppState s, Product p) async {
  if (s.user == null) {
    showMessage(context, 'Sign in to save products', error: true);
    return;
  }
  final adding = !s.isFav(p.id);
  try {
    await s.toggleFav(p.id);
    if (context.mounted) showMessage(context, adding ? 'Saved to your favourites' : 'Removed from favourites');
  } catch (e) {
    if (context.mounted) showMessage(context, e.toString(), error: true);
  }
}

Future<void> toggleFavourite(BuildContext context, Product p) => _toggleFav(context, context.read<AppState>(), p);

Widget _badge(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final bool dark;
  final String? label;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, this.color, this.dark = false, this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? (onTap == null ? Brand.muted : Brand.ink) : Colors.white.withValues(alpha: 0.92),
            boxShadow: const [BoxShadow(color: Color(0x14111216), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Icon(icon, size: 19, color: dark ? Colors.white : color),
        ),
      ),
      );
}

/// A two-column product grid that sits inside a scroll view.
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  const ProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: (c.maxWidth - 12 * (cols - 1)) / cols + 96,
        ),
        itemCount: products.length,
        // Keyed by product, so when the list re-orders each card keeps its own photo.
        itemBuilder: (_, i) => ProductCard(key: ValueKey(products[i].id), product: products[i], index: i),
      );
    });
  }
}

class SectionHead extends StatelessWidget {
  final String kicker, title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHead({super.key, required this.kicker, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kicker.toUpperCase(), style: const TextStyle(color: Brand.red600, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(title, style: Brand.head(22)),
            ]),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Row(children: [
                Text(action!, style: const TextStyle(color: Brand.red600, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right, color: Brand.red600, size: 20),
              ]),
            ),
        ]),
      );
}

/// The website's dark "page-hero" banner: a photo under a dark wash, a yellow
/// kicker, a big white title and a line of text.
class PageHero extends StatelessWidget {
  final String kicker, title, text, photo;
  const PageHero({super.key, required this.kicker, required this.title, required this.text, required this.photo});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          Positioned.fill(child: NetImage(photo, fit: BoxFit.cover, placeholder: const ColoredBox(color: Brand.ink))),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF5111216), Color(0xD9111216), Color(0x66501018)],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kicker.toUpperCase(), style: const TextStyle(color: Color(0xFFFFC23D), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
              const SizedBox(height: 8),
              Text(title, style: Brand.head(30, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.08, letterSpacing: -0.6)),
              const SizedBox(height: 10),
              Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 15, height: 1.45)),
            ]),
          ),
        ]),
      );
}

/// The website's tool card: red outline icon, bold title, a short muted line.
class ToolCard extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;
  const ToolCard({super.key, required this.icon, required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: title,
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Brand.radius), boxShadow: Brand.shadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Brand.red600, size: 28),
              const SizedBox(height: 10),
              Text(title, style: Brand.head(17).copyWith(height: 1.2)),
              const SizedBox(height: 6),
              Text(text, style: const TextStyle(color: Brand.muted, fontSize: 13.5, height: 1.4)),
            ]),
          ),
        ),
      );
}

/// Two-column grid whose rows grow to fit their tallest card.
class TwoColumn extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const TwoColumn({super.key, required this.children, this.gap = 10});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < children.length ? gap : 0),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: children[i]),
                SizedBox(width: gap),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
              ]),
            ),
          ),
      ]);
}

/// White rounded card, the site's .card.
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Brand.radius), boxShadow: Brand.shadow),
        child: child,
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: Brand.redSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: Brand.red600),
            ),
            const SizedBox(height: 18),
            Text(title, style: Brand.head(20), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, height: 1.45)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

/// − qty + stepper, as on the site's product page and cart.
class QtyStepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 9999});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD3D5DC)), borderRadius: BorderRadius.circular(99), color: Colors.white),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _step(Icons.remove, value > min ? () => onChanged(value - 1) : null),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: Brand.head(16))),
          _step(Icons.add, value < max ? () => onChanged(value + 1) : null),
        ]),
      );

  Widget _step(IconData icon, VoidCallback? onTap) => Pressable(
        onTap: onTap,
        scale: 0.88,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 18, color: onTap == null ? const Color(0xFFC3C5CC) : Brand.ink)),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const Pill(this.text, {super.key, this.bg = Brand.blueSoft, this.fg = Brand.blue});

  @override
  Widget build(BuildContext context) => _badge(text, bg, fg);
}
