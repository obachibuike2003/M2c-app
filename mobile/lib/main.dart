import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'config.dart';
import 'screens/account.dart';
import 'screens/cart.dart';
import 'screens/exchange.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/shop.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const Easy2buyApp()));
}

class Easy2buyApp extends StatelessWidget {
  const Easy2buyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Launch(),
      );
}

/// Splash while the catalogue loads, the walkthrough on first launch, then the shop.
class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  static const _seenKey = 'onboarded';
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final started = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await context.read<AppState>().init();
    // Keep the splash up long enough to read, never longer than the load itself needs.
    final wait = const Duration(milliseconds: 900) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future.delayed(wait);
    if (mounted) setState(() => _onboarded = prefs.getBool(_seenKey) ?? false);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_onboarded) {
      null => const SplashScreen(),
      false => OnboardingScreen(onDone: _finishOnboarding),
      true => const Shell(),
    };
    return AnimatedSwitcher(
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 380),
      switchInCurve: easeOutStrong,
      child: KeyedSubtree(key: ValueKey(_onboarded), child: child),
    );
  }
}

/// The four tabs. Switching is instant (no animation): it happens all day long.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  // One navigator per tab, so each keeps its own back stack like native apps.
  final _keys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  void _go(int i) {
    if (i == _tab) {
      _keys[i].currentState?.popUntil((r) => r.isFirst); // tapping the open tab goes back to its start
    } else {
      setState(() => _tab = i);
    }
  }

  Widget _root(int i) => switch (i) {
        0 => HomeScreen(goToTab: _go),
        1 => const CategoriesScreen(),
        2 => const ExchangeScreen(),
        3 => const CartScreen(asTab: true),
        _ => const AccountScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = _keys[_tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // Not extendBody: pushed screens (product, checkout) keep their bottom buttons above the bar.
        body: IndexedStack(index: _tab, children: [
          for (var i = 0; i < 5; i++)
            Navigator(key: _keys[i], onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _root(i))),
        ]),
        bottomNavigationBar: _TabBar(index: _tab, onTap: _go),
      ),
    );
  }
}

/// Same five tabs and look as the website's bottom bar: outline icons, the
/// open tab in red, "Sign in" in place of "Account" until you log in.
class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _TabBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = context.select<AppState, int>((s) => s.cartCount);
    final signedIn = context.select<AppState, bool>((s) => s.user != null);
    final tabs = [
      (Icons.home_outlined, 'Home'),
      (Icons.grid_view_outlined, 'Shop'),
      (Icons.swap_horiz_rounded, 'Exchange'),
      (Icons.shopping_cart_outlined, 'Cart'),
      (Icons.person_outline_rounded, signedIn ? 'Account' : 'Sign in'),
    ];
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Brand.line),
          boxShadow: const [BoxShadow(color: Color(0x1A111216), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onTap(i),
                scale: 0.92,
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: tabs[i].$2,
                  excludeSemantics: true,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Badge(
                      isLabelVisible: i == 3 && count > 0,
                      label: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
                      backgroundColor: Brand.red,
                      offset: const Offset(8, -6),
                      child: Icon(tabs[i].$1, color: i == index ? Brand.red : Brand.text, size: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(tabs[i].$2,
                        style: TextStyle(fontSize: 12, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? Brand.red : Brand.text)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
