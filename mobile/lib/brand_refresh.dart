import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'theme.dart';
import 'widgets.dart';

/// Pull-to-refresh in the style of the 1688 app: pulling the page down
/// uncovers a red header with a curved bottom edge, the white bag logo and
/// "Pull / Release to refresh". While loading, the header stays open and the
/// logo pulses; then the page slides back up.
///
/// [builder] gets `hold`, the height of empty space to put at the top of the
/// list (right under any pinned bar) so the header stays open while loading.
/// [top] is where that space starts on screen, i.e. the pinned bar's height.
/// The list must use bouncing physics so it can be pulled past its top on
/// Android as well: `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`.
class BrandRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final double top;
  final Widget Function(BuildContext context, double hold) builder;
  const BrandRefresh({super.key, required this.onRefresh, required this.builder, this.top = 0});

  @override
  State<BrandRefresh> createState() => _BrandRefreshState();
}

enum _Phase { idle, pulling, armed, refreshing, done }

class _BrandRefreshState extends State<BrandRefresh> with TickerProviderStateMixin {
  static const _trigger = 80.0; // pull this far, then let go, to refresh
  static const _holdHeight = 88.0; // how much header stays open while loading

  double _over = 0; // how far the list is pulled past its top
  bool _dragging = false;
  _Phase _phase = _Phase.idle;

  late final _close = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void dispose() {
    _close.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Spacer height at the top of the list that keeps the header open while
  /// loading, even after the bounce has carried the list back to the top.
  double get _hold => switch (_phase) {
        _Phase.refreshing => math.max(0, _holdHeight - _over),
        _Phase.done => (1 - _close.value) * math.max(0, _holdHeight - _over),
        _ => 0,
      };

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false; // ignore sideways rows
    final over = math.max(0.0, n.metrics.minScrollExtent - n.metrics.pixels);

    if (n is ScrollStartNotification && n.dragDetails != null) _dragging = true;
    final released = _dragging && (n is ScrollEndNotification || (n is ScrollUpdateNotification && n.dragDetails == null));
    if (released) _dragging = false;

    var phase = _phase;
    if (phase == _Phase.idle || phase == _Phase.pulling || phase == _Phase.armed) {
      if (released && phase == _Phase.armed) {
        _start();
        phase = _Phase.refreshing;
      } else if (_dragging) {
        final armed = over >= _trigger;
        if (armed && phase != _Phase.armed) HapticFeedback.mediumImpact();
        phase = armed ? _Phase.armed : (over > 0 ? _Phase.pulling : _Phase.idle);
      } else if (over == 0) {
        phase = _Phase.idle;
      }
    }
    if (over != _over || phase != _phase) setState(() { _over = over; _phase = phase; });
    return false;
  }

  Future<void> _start() async {
    if (!reduceMotion(context)) _pulse.repeat(reverse: true);
    final started = DateTime.now();
    try {
      await widget.onRefresh();
    } finally {
      // Long enough to read the header, even when the reload is instant.
      final wait = const Duration(milliseconds: 900) - DateTime.now().difference(started);
      if (wait > Duration.zero) await Future.delayed(wait);
      if (mounted) {
        _pulse.stop();
        setState(() => _phase = _Phase.done);
        await Future.delayed(const Duration(milliseconds: 350)); // show "Up to date"
        if (mounted) {
          await _close.animateTo(1, curve: easeDrawer);
          if (mounted) setState(() { _phase = _Phase.idle; _close.value = 0; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _close,
      builder: (context, _) {
        final hold = _hold;
        final open = _over + hold; // how much header is showing
        // The header is drawn over the list, but only in the gap the pull opens up.
        return Stack(children: [
          NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.builder(context, hold)),
          Positioned(top: widget.top, left: 0, right: 0, height: open, child: IgnorePointer(child: _Header(open: open, phase: _phase, pulse: _pulse, trigger: _trigger))),
        ]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  final double open, trigger;
  final _Phase phase;
  final Animation<double> pulse;
  const _Header({required this.open, required this.phase, required this.pulse, required this.trigger});

  @override
  Widget build(BuildContext context) {
    if (open <= 0.5) return const SizedBox.shrink();
    final progress = (open / trigger).clamp(0.0, 1.0);
    final curve = math.min(30.0, open * 0.22); // depth of the curved bottom edge
    final label = switch (phase) {
      _Phase.armed => 'Release to refresh',
      _Phase.refreshing => 'Refreshing…',
      _Phase.done => 'Up to date',
      _ => 'Pull to refresh',
    };

    return ClipPath(
      clipper: _CurvedBottom(curve),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF2D44), Brand.red]),
        ),
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: curve * 0.55 + 8,
            child: Opacity(
              opacity: Curves.easeOut.transform(((progress - 0.25) / 0.75).clamp(0.0, 1.0)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * progress,
                      child: Image.asset('assets/logo_mark_white.png', height: 34, filterQuality: FilterQuality.medium),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(AppConfig.appName, style: Brand.head(26, weight: FontWeight.w800, color: Colors.white).copyWith(letterSpacing: -0.5)),
                ]),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(label, key: ValueKey(label), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Straight sides, with the bottom edge bowing down in the middle.
class _CurvedBottom extends CustomClipper<Path> {
  final double depth;
  const _CurvedBottom(this.depth);

  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height - depth)
    ..quadraticBezierTo(s.width / 2, s.height + depth, 0, s.height - depth)
    ..close();

  @override
  bool shouldReclip(_CurvedBottom old) => old.depth != depth;
}
