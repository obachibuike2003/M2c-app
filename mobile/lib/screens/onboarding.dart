import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';

/// Shown while the catalogue loads on launch: the logo on brand red.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Brand.red,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Transform.rotate(
              angle: -0.105,
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 14))],
                ),
                child: Text('E', style: Brand.head(44, weight: FontWeight.w800, color: Brand.red)),
              ),
            ),
            const SizedBox(height: 18),
            Text(AppConfig.appName, style: Brand.head(32, weight: FontWeight.w800, color: Colors.white).copyWith(letterSpacing: -0.6)),
            const SizedBox(height: 4),
            Text(AppConfig.tagline, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _Page {
  final IconData icon;
  final List<String> photos;
  final String title, text;
  const _Page(this.icon, this.photos, this.title, this.text);
}

const _pages = [
  _Page(
    Icons.public,
    ['assets/products/p101-1.webp', 'assets/products/p91-1.webp', 'assets/products/p172-1.webp'],
    'Shop straight from China',
    'Phones, fashion, home goods and raw materials at factory prices, all priced in naira.',
  ),
  _Page(
    Icons.local_shipping_outlined,
    ['assets/products/p193-1.webp', 'assets/products/p101-1.webp', 'assets/products/p91-1.webp'],
    'Delivered to your door',
    'Track every step from the factory to Lagos to you. Pay on delivery, with buyer protection.',
  ),
  _Page(
    Icons.work_outline,
    ['assets/products/p172-1.webp', 'assets/products/p193-1.webp', 'assets/products/p101-1.webp'],
    'Buy in bulk for your business',
    'Switch to Business for wholesale prices from ${AppConfig.bulkMinQty} pieces and up to 15% off.',
  ),
];

/// First-launch walkthrough: Skip, Next, then Get started, which offers
/// sign in, create account or browse as a guest. Calls [onDone] when finished.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _welcome = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 420), curve: easeDrawer);
    } else {
      setState(() => _welcome = true);
    }
  }

  Future<void> _auth(Widget screen) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (ok == true) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 320),
          switchInCurve: easeOutStrong,
          switchOutCurve: easeOutStrong,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: child),
          ),
          child: _welcome ? _welcomeView() : _slidesView(last),
        ),
      ),
    );
  }

  Widget _slidesView(bool last) => Column(key: const ValueKey('slides'), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(children: [
            const Logo(),
            const Spacer(),
            AnimatedOpacity(
              opacity: last ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: TextButton(
                onPressed: last ? null : () => setState(() => _welcome = true),
                child: const Text('Skip', style: TextStyle(color: Brand.muted, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _PageView(page: _pages[i]),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _pages.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: easeOutStrong,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(color: i == _index ? Brand.red : const Color(0xFFE2E3E8), borderRadius: BorderRadius.circular(9)),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Text(last ? 'Get started' : 'Next', key: ValueKey(last)),
              ),
            ),
          ),
        ),
      ]);

  Widget _welcomeView() => Padding(
        key: const ValueKey('welcome'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Spacer(),
          const Center(child: LogoMark(size: 72)),
          const SizedBox(height: 26),
          Text('Welcome to ${AppConfig.appName}', textAlign: TextAlign.center, style: Brand.head(28, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Create an account to save products, track orders and unlock wholesale prices. Or just look around first.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.muted, height: 1.5),
          ),
          const Spacer(),
          FilledButton(onPressed: () => _auth(const SignupScreen()), child: const Text('Create account')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => _auth(const LoginScreen()), child: const Text('I already have an account')),
          const SizedBox(height: 6),
          TextButton(
            onPressed: widget.onDone,
            child: const Text('Continue as guest', style: TextStyle(color: Brand.muted, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _PageView extends StatelessWidget {
  final _Page page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(children: [
        const Spacer(),
        // A stack of floating product photos on a tinted disc, like the site's hero.
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0xFFFFF1F3), Brand.redSoft]),
              ),
            ),
            Positioned(left: 6, top: 30, child: _floater(page.photos[1], 92, -0.12)),
            Positioned(right: 4, bottom: 34, child: _floater(page.photos[2], 96, 0.1)),
            _floater(page.photos[0], 150, -0.03),
            Positioned(
              right: 30,
              top: 22,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Brand.red, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x52E0182D), blurRadius: 18, offset: Offset(0, 8))]),
                child: Icon(page.icon, color: Colors.white, size: 26),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 36),
        Text(page.title, textAlign: TextAlign.center, style: Brand.head(28, weight: FontWeight.w800).copyWith(height: 1.1)),
        const SizedBox(height: 12),
        Text(page.text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, fontSize: 15, height: 1.5)),
        const Spacer(),
      ]),
    );
  }

  Widget _floater(String src, double size, double angle) => Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.1),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.22), boxShadow: Brand.shadow),
          child: NetImage(src, placeholder: const Icon(Icons.inventory_2_outlined, color: Brand.muted)),
        ),
      );
}
