import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../brand_refresh.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account.dart';
import 'exchange.dart';
import 'photo_search.dart';
import 'shop.dart';

class HomeScreen extends StatefulWidget {
  /// Jumps the shell to another tab (0 Home, 1 Shop, 2 Exchange, 3 Cart, 4 Account).
  final ValueChanged<int> goToTab;
  const HomeScreen({super.key, required this.goToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _page = 12;
  String _cat = '';
  int _shown = _page;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    final list = s.recommended.length >= s.products.length ? s.recommended : _ordered(s);
    final filtered = list.where((p) => _cat.isEmpty || p.cat == _cat).toList();

    return Scaffold(
      body: BrandRefresh(
        onRefresh: () async {
          await s.refresh();
          if (context.mounted && s.loadError != null && s.products.isNotEmpty) showMessage(context, s.loadError!, error: true);
        },
        // Under the pinned logo row (64) and search bar (60).
        top: MediaQuery.paddingOf(context).top + 124,
        builder: (context, hold) => CustomScrollView(physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Brand.bg,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 64,
            titleSpacing: 16,
            title: const Logo(),
            actions: [ModeSwitch(goToTab: widget.goToTab), const SizedBox(width: 14)],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Pressable(
                  onTap: () => openSearch(context),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.only(left: 16, right: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: Brand.line)),
                    child: Row(children: [
                      const Icon(Icons.search, color: Brand.muted, size: 21),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Search phones, cars, raw materials', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted))),
                      const CameraSearchButton(),
                      const SizedBox(width: 6),
                      SearchGoButton(onTap: () => openSearch(context)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: hold)), // keeps the red refresh header open while loading
          if (s.loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Brand.red)))
          else if (s.loadError != null && s.products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Can\'t reach Easy2buy',
                text: s.loadError!,
                action: FilledButton(onPressed: s.refresh, child: const Text('Try again')),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: u == null ? 'Welcome! ' : 'Hi, ${u.firstName}! ', style: Brand.head(20)),
                  TextSpan(text: 'What are you buying today?', style: Brand.head(20, weight: FontWeight.w500, color: Brand.muted)),
                ])),
              ),
            ),
            SliverToBoxAdapter(child: _HeroSlider(goToTab: widget.goToTab)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
                child: SectionHead(
                  kicker: 'Browse',
                  title: 'Shop by category',
                  action: 'All categories',
                  onAction: () => widget.goToTab(1),
                ),
              ),
            ),
            // Every category in a grid, like the website: 4 across on phones, more on wider screens.
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverLayoutBuilder(builder: (context, box) {
                final cols = box.crossAxisExtent > 700 ? 6 : box.crossAxisExtent > 500 ? 5 : 4;
                final cell = (box.crossAxisExtent - 10 * (cols - 1)) / cols;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 14, mainAxisExtent: cell + 44,
                  ),
                  delegate: SliverChildBuilderDelegate(childCount: s.categories.length, (context, i) {
                    final c = s.categories[i];
                    return FadeIn(
                      delay: Duration(milliseconds: 30 * (i % 8)),
                      child: Pressable(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(categoryId: c.id))),
                        child: Column(children: [
                          CategoryBubble(category: c, size: cell),
                          const SizedBox(height: 7),
                          Text(c.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, color: Brand.ink)),
                        ]),
                      ),
                    );
                  }),
                );
              }),
            ),
            if (!s.isBusiness) SliverToBoxAdapter(child: _FlashDeals(products: s.products)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionHead(
                    kicker: 'For you',
                    title: s.isBusiness ? 'Picked for your business' : 'Recommended for you',
                  ),
                  if (s.searches.isNotEmpty || s.views.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        const Icon(Icons.auto_awesome, size: 15, color: Brand.red600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.searches.isNotEmpty
                                ? 'Based on your searches: ${s.searches.take(3).join(', ')}'
                                : 'Based on what you\'ve been looking at',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Brand.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                  for (final c in <({String id, String name})>[(id: '', name: 'All'), for (final c in s.categories) (id: c.id, name: c.name)])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: _cat == c.id,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _cat = c.id;
                          _shown = _page;
                        }),
                      ),
                    ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: filtered.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Text('No products here yet.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted)))
                    : ProductGrid(key: ValueKey(_cat), products: filtered.take(_shown).toList()),
              ),
            ),
            if (_shown < filtered.length)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: OutlinedButton(onPressed: () => setState(() => _shown += _page), child: const Text('Show more')),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ]),
      ),
    );
  }

  /// The backend's picks first, then everything else by best-selling, so
  /// "Show more" can keep going past the first dozen like on the site.
  List<Product> _ordered(AppState s) {
    final seen = {for (final p in s.recommended) p.id};
    final rest = s.products.where((p) => !seen.contains(p.id)).toList()..sort((a, b) => b.sold.compareTo(a.sold));
    return [...s.recommended, ...rest];
  }
}

// ---------------------------------------------------------------- mode switch

/// "Personal | Business" in the header, like the website's. Business needs an
/// account and a business name, so it asks for those the first time.
class ModeSwitch extends StatelessWidget {
  final ValueChanged<int> goToTab;
  const ModeSwitch({super.key, required this.goToTab});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final business = s.isBusiness;

    Future<void> choose(bool toBusiness) async {
      if (toBusiness == business) return;
      if (s.user == null) {
        showMessage(context, 'Sign in first, then switch to business');
        goToTab(4);
        return;
      }
      final biz = s.user!.business;
      if (toBusiness && (biz?['name'] == null || biz?['type'] == null)) return showBusinessSheet(context);
      try {
        await (toBusiness ? s.setBusiness('${biz!['name']}', '${biz['type']}') : s.setPersonal());
        if (context.mounted) showMessage(context, toBusiness ? 'You are now buying as a business' : 'You are buying for yourself');
      } catch (e) {
        if (context.mounted) showMessage(context, e.toString(), error: true);
      }
    }

    Widget option(String label, bool on, bool isBusiness) => Semantics(
          button: true,
          selected: on,
          label: 'Buying as $label',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => choose(isBusiness),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: easeOutStrong,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(color: on ? Brand.blue : Colors.transparent, borderRadius: BorderRadius.circular(99)),
              child: Text(label, style: TextStyle(color: on ? Colors.white : Brand.muted, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE9EAEF), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('Personal', !business, false), option('Business', business, true)]),
    );
  }
}

// ---------------------------------------------------------------- hero

class _Slide {
  final String eyebrow, title, accent, text, cta;
  final String? photo;
  final int tab; // which bottom tab the button opens
  const _Slide({required this.eyebrow, required this.title, required this.accent, required this.text, required this.cta, this.photo, this.tab = 1});
}

final _slides = [
  const _Slide(
    eyebrow: 'Direct from China',
    title: 'Factory prices,',
    accent: 'paid in naira.',
    text: 'Phones, fashion, home and more, shipped from China to your door.',
    cta: 'Start shopping',
  ),
  _Slide(
    eyebrow: 'Shipping',
    title: 'From the factory',
    accent: 'to your door.',
    text: 'Orders reach you in 7 to 18 days, with free delivery above ${money(AppConfig.freeShippingFrom)}.',
    cta: 'Browse products',
    photo: 'assets/banners/ship.jpg',
  ),
  const _Slide(
    eyebrow: 'Exchange',
    title: 'Naira to RMB and crypto,',
    accent: 'in seconds.',
    text: 'Change naira to yuan, USDT, Bitcoin and more at clear rates.',
    cta: 'Exchange now',
    photo: 'assets/banners/bitcoin.jpg',
    tab: 2,
  ),
];

/// The home slider, animated like the website's: slides crossfade, the text
/// rises in, photos slowly zoom, product photos float on the red slide, and
/// the dots fill up as each slide's time runs out. Swipe to change slide.
class _HeroSlider extends StatefulWidget {
  final ValueChanged<int> goToTab;
  const _HeroSlider({required this.goToTab});

  @override
  State<_HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<_HeroSlider> with TickerProviderStateMixin {
  static const _each = Duration(seconds: 6);

  /// Runs once per slide; when it fills, the next slide comes in. Drives the dots too.
  late final _timer = AnimationController(vsync: this, duration: _each)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _show(_index + 1);
    });

  /// Endless gentle bob for the floating product photos.
  late final _float = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _timer.stop();
      _float.stop();
    } else {
      if (!_timer.isAnimating) _timer.forward(from: _timer.value);
      if (!_float.isAnimating) _float.repeat(reverse: true);
    }
  }

  void _show(int i) {
    setState(() => _index = (i + _slides.length) % _slides.length);
    if (!reduceMotion(context)) _timer.forward(from: 0);
  }

  @override
  void dispose() {
    _timer.dispose();
    _float.dispose();
    super.dispose();
  }

  void _open(_Slide slide) {
    // Business buyers have Business in tab 2, so Exchange opens on its own.
    if (slide.tab == 2 && context.read<AppState>().isBusiness) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExchangeScreen()));
    } else {
      widget.goToTab(slide.tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 120) _show(_index + (v < 0 ? 1 : -1));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 178, // the website's phone slider is about this tall
            child: Stack(fit: StackFit.expand, children: [
              for (var i = 0; i < _slides.length; i++)
                IgnorePointer(
                  ignoring: i != _index,
                  child: AnimatedOpacity(
                    opacity: i == _index ? 1 : 0,
                    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
                    curve: easeOutStrong,
                    child: _SlideCard(slide: _slides[i], active: i == _index, float: _float, onTap: () => _open(_slides[i])),
                  ),
                ),
              // Dots that fill like a progress bar, bottom left as on the website.
              Positioned(
                left: 16,
                bottom: 14,
                child: AnimatedBuilder(
                  animation: _timer,
                  builder: (_, _) => Row(children: [
                    for (var i = 0; i < _slides.length; i++)
                      GestureDetector(
                        onTap: () => _show(i),
                        child: Container(
                          width: 26,
                          height: 3.5,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(4)),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: i < _index ? 0 : i == _index ? (reduceMotion(context) ? 1 : _timer.value) : 0,
                            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  final _Slide slide;
  final bool active;
  final Animation<double> float;
  final VoidCallback onTap;
  const _SlideCard({required this.slide, required this.active, required this.float, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photo = slide.photo;
    final still = reduceMotion(context);
    return Stack(fit: StackFit.expand, children: [
      if (photo == null)
        // The website's red slide: deep red to bright red, a warm glow top right, shade bottom left.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment(-1, -0.6), end: Alignment(1, 0.6), colors: [Color(0xFF8F0A18), Brand.red, Color(0xFFFF4D5F)], stops: [0, 0.48, 1]),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: Alignment(0.64, -0.4), radius: 0.75, colors: [Color(0x61FFC83D), Color(0x00FFC83D)]),
            ),
          ),
        )
      else ...[
        // Slow zoom out, like the website's photo slides.
        AnimatedScale(
          scale: active || still ? 1 : 1.08,
          duration: still ? Duration.zero : const Duration(seconds: 6),
          curve: Curves.easeOut,
          child: NetImage(photo, fit: BoxFit.cover, placeholder: const ColoredBox(color: Brand.ink)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xE60A0A0E), Color(0x9E0A0A0E), Color(0x260A0A0E)], stops: [0, 0.45, 1]),
          ),
        ),
      ],
      if (photo == null) ...[
        // Soft rings behind the products, as on the website.
        Positioned(
          right: -50,
          top: -30,
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2)),
          ),
        ),
        // Floating product photos: they pop in when the slide shows, then bob.
        _Floater(src: 'assets/products/p101-1.webp', right: 10, bottom: 14, size: 118, tilt: 0.07, phase: 0, float: float, active: active, order: 0),
        _Floater(src: 'assets/products/p91-1.webp', right: 112, bottom: 10, size: 96, tilt: -0.09, phase: 0.5, float: float, active: active, order: 1),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          _Rise(active: active, delay: 100, child: SizedBox(
            width: photo == null ? 190 : 260, // keeps clear of the products on the red slide
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${slide.title} '),
                TextSpan(text: slide.accent, style: TextStyle(color: photo == null ? const Color(0xFFFFC83D) : const Color(0xFFFF8A95))),
              ]),
              maxLines: 3,
              style: Brand.head(19, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.15, letterSpacing: -0.3),
            ),
          )),
          const SizedBox(height: 10),
          _Rise(
            active: active,
            delay: 300,
            child: Pressable(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text(slide.cta, style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Rises 30px and fades in each time its slide becomes active (the site's "rise").
class _Rise extends StatelessWidget {
  final bool active;
  final int delay;
  final Widget child;
  const _Rise({required this.active, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(active),
      tween: Tween(begin: active ? 0 : 1, end: 1),
      duration: Duration(milliseconds: active ? 900 + delay : 0),
      curve: Interval(delay / (900 + delay), 1, curve: easeOutStrong),
      builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child)),
      child: child,
    );
  }
}

/// A product photo floating on the red slide, with a soft shadow.
class _Floater extends StatelessWidget {
  final String src;
  final double right, bottom, size, tilt, phase;
  final Animation<double> float;
  final bool active;
  final int order;
  const _Floater({
    required this.src, required this.right, required this.bottom, required this.size,
    required this.tilt, required this.phase, required this.float, required this.active, required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final image = Container(
      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 28, offset: Offset(0, 22), spreadRadius: -10)]),
      child: NetImage(src, placeholder: const SizedBox()),
    );
    return Positioned(
      right: right,
      bottom: bottom,
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        // Pop in, one after the other, each time the slide shows.
        key: ValueKey(active),
        tween: Tween(begin: active && !still ? 0 : 1, end: 1),
        duration: Duration(milliseconds: active && !still ? 900 + 250 + order * 120 : 0),
        curve: Interval((250 + order * 120) / (900 + 250 + order * 120), 1, curve: Curves.easeOutBack),
        builder: (_, t, child) => Opacity(opacity: t.clamp(0, 1), child: Transform.scale(scale: 0.6 + 0.4 * t, child: child)),
        child: still
            ? Transform.rotate(angle: tilt / 2, child: image)
            : AnimatedBuilder(
                animation: float,
                builder: (_, child) {
                  // Offset each one's bob, so they don't move in step.
                  final v = Curves.easeInOut.transform(((float.value + phase) % 1.0 - 0.5).abs() * 2);
                  return Transform.translate(offset: Offset(0, -8 * v), child: Transform.rotate(angle: tilt * v, child: child));
                },
                child: image,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------- flash deals

/// Biggest discounts, with a countdown to midnight when the deals change.
class _FlashDeals extends StatefulWidget {
  final List<Product> products;
  const _FlashDeals({required this.products});

  @override
  State<_FlashDeals> createState() => _FlashDealsState();
}

class _FlashDealsState extends State<_FlashDeals> {
  late Timer _tick;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    if (mounted) setState(() => _left = midnight.difference(now));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deals = widget.products.where((p) => p.discount >= 20 && p.stock > 0).toList()..sort((a, b) => b.discount.compareTo(a.discount));
    if (deals.isEmpty) return const SizedBox.shrink();
    String two(int n) => n.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE3E7), Color(0xFFFFF6F7)]),
          border: Border.all(color: const Color(0xFFFFD0D6)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(children: [
              const Icon(Icons.bolt_rounded, color: Brand.red, size: 26),
              const SizedBox(width: 2),
              Text('Flash deals', style: Brand.head(20, weight: FontWeight.w800)),
              const Spacer(),
              const Text('Ends in ', style: TextStyle(color: Brand.muted, fontSize: 12)),
              for (final (i, part) in [two(_left.inHours), two(_left.inMinutes % 60), two(_left.inSeconds % 60)].indexed) ...[
                if (i > 0) const Text(' : ', style: TextStyle(color: Brand.red600, fontWeight: FontWeight.w800)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(7)),
                  child: Text(part, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 14),
              itemCount: deals.length.clamp(0, 12),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: 160, child: ProductCard(product: deals[i], index: i, deal: true)),
            ),
          ),
        ]),
      ),
    );
  }
}
