import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../brand_refresh.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
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
            actions: [
              IconButton(
                tooltip: 'Account',
                onPressed: () => widget.goToTab(4),
                icon: u == null
                    ? const Icon(Icons.person_outline)
                    : CircleAvatar(radius: 15, backgroundColor: Brand.red, child: Text(u.firstName.isEmpty ? '?' : u.firstName[0].toUpperCase(), style: Brand.head(14, color: Colors.white))),
              ),
              const SizedBox(width: 8),
            ],
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
                  action: 'All',
                  onAction: () => widget.goToTab(1),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: s.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final c = s.categories[i];
                    return FadeIn(
                      delay: Duration(milliseconds: 40 * (i % 8)),
                      child: Pressable(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(categoryId: c.id))),
                        child: SizedBox(
                          width: 78,
                          child: Column(children: [
                            CategoryBubble(category: c, size: 64),
                            const SizedBox(height: 8),
                            Text(c.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (!s.isBusiness) SliverToBoxAdapter(child: _FlashDeals(products: s.products)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: SectionHead(
                  kicker: 'For you',
                  title: s.isBusiness ? 'Picked for your business' : 'Recommended for you',
                ),
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

class _HeroSlider extends StatefulWidget {
  final ValueChanged<int> goToTab;
  const _HeroSlider({required this.goToTab});

  @override
  State<_HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<_HeroSlider> {
  final _pages = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pages.hasClients || reduceMotion(context)) return;
      _pages.animateToPage((_index + 1) % _slides.length, duration: const Duration(milliseconds: 520), curve: easeDrawer);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 220,
        child: NotificationListener<ScrollStartNotification>(
          // A swipe by hand resets the auto-advance, so it never jumps right after.
          onNotification: (n) {
            if (n.dragDetails != null) _restart();
            return false;
          },
          child: PageView.builder(
            controller: _pages,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _SlideCard(slide: _slides[i], onTap: () => widget.goToTab(_slides[i].tab))),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: easeOutStrong,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(color: i == _index ? Brand.red : const Color(0xFFD3D5DC), borderRadius: BorderRadius.circular(9)),
          ),
      ]),
    ]);
  }
}

class _SlideCard extends StatelessWidget {
  final _Slide slide;
  final VoidCallback onTap;
  const _SlideCard({required this.slide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photo = slide.photo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(fit: StackFit.expand, children: [
        if (photo == null)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF3A50), Brand.red, Brand.red700]),
            ),
          )
        else ...[
          NetImage(photo, fit: BoxFit.cover, placeholder: const ColoredBox(color: Brand.ink)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xE6111216), Color(0x66111216)]),
            ),
          ),
        ],
        // The soft ring the site draws on its red slide.
        if (photo == null)
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 26)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
              child: Text(slide.eyebrow.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
            ),
            const Spacer(),
            Text(slide.title, style: Brand.head(25, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.05)),
            Text(slide.accent, style: Brand.head(25, weight: FontWeight.w800, color: photo == null ? const Color(0xFFFFD6DB) : const Color(0xFFFF8A95)).copyWith(height: 1.1)),
            const SizedBox(height: 6),
            Text(slide.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5, height: 1.35)),
            const SizedBox(height: 12),
            Pressable(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text(slide.cta, style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ]),
        ),
      ]),
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
