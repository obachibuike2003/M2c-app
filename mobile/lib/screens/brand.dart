import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../media.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shop.dart';

Color hexColor(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '').padLeft(6, '0')}', radix: 16));
String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  return (words.length > 1 ? words[0][0] + words[1][0] : words[0].substring(0, words[0].length.clamp(0, 2))).toUpperCase();
}

/// Build my brand, the website's brand.html: brand kit, preview, starter steps
/// and a profit calculator. Saved to the account, so the site shows it too.
class BrandScreen extends StatefulWidget {
  const BrandScreen({super.key});

  @override
  State<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends State<BrandScreen> {
  // Tagline ideas by type of business. {name} becomes the brand name.
  static const _taglines = {
    'fashion': ['Style that speaks for you', 'Look good, feel good, every day', 'Fresh fits at fair prices', 'Dress the part with {name}'],
    'phones': ['Original gadgets, honest prices', 'Stay connected, stay ahead', 'Your trusted phone plug', 'Tech you can count on'],
    'electronics': ['Power your home for less', 'Quality electronics, fair prices', 'Bright ideas, better living'],
    'beauty': ['Glow with confidence', 'Beauty that cares for you', 'Your skin, our passion', 'Look your best with {name}'],
    'soap': ['Clean you can trust', 'Made fresh, made right', 'Pure clean for every home', '{name}: cleaner, fresher, better'],
    'packaging': ['Packaging that protects your product', 'Built strong, made to last', 'Quality from the first layer'],
    'furniture': ['Comfort for every room', 'Build a home you love', 'Style that lasts for years'],
    'home': ['Everything your home needs', 'Making homes easier', 'Good things for good homes'],
    'supermarket': ['Everything you need, one stop', 'Fair prices, every day', 'Your neighbourhood favourite'],
    'sports': ['Play harder, play better', 'Gear up for greatness', 'Built for the game'],
    'cars': ['Drive your dream today', 'Quality cars, honest deals', 'Your trusted car plug'],
    'other': ['Quality you can trust', 'Good things, fair prices', 'Here for you, every time', '{name}: done right'],
  };
  static const _palettes = [
    ['#e0182d', '#111216'], ['#1d4ed8', '#ffc83d'], ['#0b7a43', '#f5f0e6'], ['#8b5cf6', '#111216'],
    ['#ec4899', '#2a2c33'], ['#f97316', '#1e293b'], ['#0f766e', '#fde68a'], ['#111216', '#d4af37'],
  ];
  static const _swatches = ['#e0182d', '#f97316', '#f5a50b', '#0b7a43', '#0f766e', '#1d4ed8', '#8b5cf6', '#ec4899', '#111216', '#ffffff', '#ffc83d', '#d4af37'];

  late final TextEditingController _name, _tagline;
  final _cost = TextEditingController(text: '5000');
  final _markup = TextEditingController(text: '40');
  final _pieces = TextEditingController(text: '50');
  String _logo = '', _c1 = '#e0182d', _c2 = '#111216';
  Map<String, dynamic> _steps = {};
  bool _showIdeas = false, _saving = false;
  int _style = 0;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user;
    final b = u?.brand ?? const {};
    _name = TextEditingController(text: (b['name'] ?? u?.business?['name'] ?? '') as String);
    _tagline = TextEditingController(text: (b['tagline'] ?? '') as String);
    _logo = (b['logo'] ?? '') as String;
    _c1 = (b['c1'] ?? _c1) as String;
    _c2 = (b['c2'] ?? _c2) as String;
    _steps = Map<String, dynamic>.from((b['steps'] as Map?) ?? const {});
  }

  @override
  void dispose() {
    for (final c in [_name, _tagline, _cost, _markup, _pieces]) {
      c.dispose();
    }
    super.dispose();
  }

  /// A simple logo: initials in a shape, in the brand colours. Each tap tries the next style.
  Future<void> _makeLogo() async {
    const size = 320.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final fill = Paint()..color = hexColor(_c1);
    final stroke = Paint()
      ..color = hexColor(_c2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    final shape = _style % 4;
    final Path path = switch (shape) {
      0 => Path()..addOval(const Rect.fromLTWH(6, 6, size - 12, size - 12)),
      1 => Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10, 10, size - 20, size - 20), const Radius.circular(70))),
      2 => Path()
        ..moveTo(size / 2, 8)
        ..lineTo(size - 8, size / 2)
        ..lineTo(size / 2, size - 8)
        ..lineTo(8, size / 2)
        ..close(),
      _ => Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10, 10, size - 20, size - 20), const Radius.circular(18))),
    };
    canvas.drawPath(path, fill);
    if (shape != 2) canvas.drawPath(path, stroke);
    final tp = TextPainter(
      text: TextSpan(text: initials(_name.text), style: Brand.head(shape == 2 ? 104 : 128, weight: FontWeight.w800, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2 + 4));
    final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    _style++;
    if (png != null && mounted) setState(() => _logo = 'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}');
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showMessage(context, 'Enter your brand name.', error: true);
    setState(() => _saving = true);
    _steps['kit'] = true;
    try {
      await context.read<AppState>().saveBrand({'name': _name.text.trim(), 'tagline': _tagline.text.trim(), 'logo': _logo, 'c1': _c1, 'c2': _c2, 'steps': _steps});
      if (mounted) showMessage(context, 'Brand kit saved. Your logo is ready for product customising.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStep(String id, bool on) async {
    setState(() => _steps[id] = on);
    try {
      await context.read<AppState>().saveBrand({'steps': _steps});
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final typeId = (s.user?.business?['type'] ?? 'other') as String;
    final typeName = (s.user?.business?['type'] == null) ? 'your business' : (const {
      'fashion': 'Fashion & clothing store', 'phones': 'Phone & gadget shop', 'electronics': 'Electronics shop', 'beauty': 'Beauty, salon & aesthetics',
      'soap': 'Soap, detergent & cosmetics making', 'packaging': 'Plastic & packaging production', 'furniture': 'Furniture & interior', 'home': 'Home & kitchen store',
      'supermarket': 'Supermarket & provisions', 'sports': 'Sports & fitness', 'cars': 'Car & bike dealer', 'other': 'Something else',
    }[typeId] ?? 'your business');
    final ideas = (_taglines[typeId] ?? _taglines['other']!).map((t) => t.replaceAll('{name}', _name.text.trim().isEmpty ? 'us' : _name.text.trim())).toList();
    final steps = [
      ('niche', 'Pick what you will sell', 'You chose: $typeName. You can change it on your account page.', null),
      ('kit', 'Make your brand kit', 'Name, logo, colours and tagline, on this page.', null),
      ('stock', 'Order your first stock', 'Start small, around the minimum, and see what sells.', 'shop'),
      ('brandgoods', 'Put your logo on your goods', 'Tap "Customise with your logo" on any product.', 'shop'),
      ('price', 'Set your selling prices', 'Use the calculator below so every sale makes a profit.', null),
      ('market', 'Tell people', 'Share your products on WhatsApp status, Instagram and with old customers.', null),
    ];

    num v(TextEditingController c) => (num.tryParse(c.text) ?? 0).clamp(0, 1e12);
    final cost = v(_cost);
    final price = (cost * (1 + v(_markup) / 100)).round();
    final pieces = v(_pieces) < 1 ? 1 : v(_pieces);

    return Scaffold(
      appBar: AppBar(title: const Text('Build my brand')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const PageHero(
          kicker: 'Build my brand',
          title: 'Build a business people remember',
          text: 'Make your brand kit here. Your logo is saved and used when you customise products.',
          photo: 'assets/banners/shopper.jpg',
        ),
        const SizedBox(height: 14),

        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Your brand kit', style: Brand.head(20)),
            const SizedBox(height: 14),
            TextField(controller: _name, maxLength: 40, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Brand name', counterText: '')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _tagline,
                  maxLength: 70,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Tagline', hintText: 'A short line about what you do', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(backgroundColor: Brand.redSoft, foregroundColor: Brand.red600, minimumSize: const Size(0, 48)),
                onPressed: () => setState(() => _showIdeas = true),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Suggest'),
              ),
            ]),
            if (_showIdeas)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in ideas) ActionChip(label: Text(t), onPressed: () => setState(() => _tagline.text = t)),
                ]),
              ),
            const SizedBox(height: 18),
            const Text('Colours', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _colourRow('Main', _c1, (c) => setState(() => _c1 = c)),
            const SizedBox(height: 8),
            _colourRow('Second', _c2, (c) => setState(() => _c2 = c)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final pal in _palettes)
                Semantics(
                  button: true,
                  label: 'Use ${pal[0]} and ${pal[1]}',
                  child: Pressable(
                    onTap: () => setState(() {
                      _c1 = pal[0];
                      _c2 = pal[1];
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _c1 == pal[0] && _c2 == pal[1] ? Brand.ink : Brand.line, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(pal[0], 20), const SizedBox(width: 3), _dot(pal[1], 20)]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            const Text('Logo', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  final img = await pickImageDataUrl(context);
                  if (img != null) setState(() => _logo = img);
                },
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Upload logo'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(backgroundColor: Brand.redSoft, foregroundColor: Brand.red600, minimumSize: const Size(0, 44)),
                onPressed: _makeLogo,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Make one for me'),
              ),
            ]),
            const SizedBox(height: 6),
            const Text('No logo yet? "Make one for me" creates a simple one from your name and colours. Tap again for a different style.',
                style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Save brand kit'),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Preview', style: Brand.head(20)),
            const SizedBox(height: 12),
            _BrandCard(name: _name.text, tagline: _tagline.text, logo: _logo, c1: _c1, c2: _c2, phone: s.user?.phone ?? ''),
            const SizedBox(height: 12),
            _BrandPost(name: _name.text, tagline: _tagline.text, logo: _logo, c1: _c1, c2: _c2),
          ]),
        ),
        const SizedBox(height: 14),

        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Starter steps', style: Brand.head(20)),
            const SizedBox(height: 4),
            const Text('Tick each one off as you go.', style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 8),
            for (final (id, title, text, go) in steps)
              CheckboxListTile(
                value: _steps[id] == true,
                onChanged: (on) => _toggleStep(id, on ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Brand.red,
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(text, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                secondary: go == null
                    ? null
                    : TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductListScreen())),
                        child: const Text('Go'),
                      ),
              ),
          ]),
        ),
        const SizedBox(height: 14),

        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profit calculator', style: Brand.head(20)),
            const SizedBox(height: 4),
            const Text('What should you sell at? Most small shops add 30% to 60%.', style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _numField(_cost, 'Your cost per piece (₦)')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_markup, 'Markup (%)')),
            ]),
            const SizedBox(height: 10),
            _numField(_pieces, 'Pieces you will sell'),
            const SizedBox(height: 12),
            _sum('Sell each at', money(price)),
            _sum('Profit per piece', money(price - cost)),
            const Divider(height: 18, color: Brand.line),
            Row(children: [
              Text('Profit on ${pieces.toInt()}', style: Brand.head(17)),
              const Spacer(),
              Text(money((price - cost) * pieces), style: Brand.head(22, weight: FontWeight.w800, color: Brand.green)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  Widget _sum(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Text(label, style: const TextStyle(color: Brand.muted)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );

  Widget _dot(String hex, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: hexColor(hex), shape: BoxShape.circle, border: Border.all(color: const Color(0x22000000))),
      );

  Widget _colourRow(String label, String current, ValueChanged<String> pick) => Row(children: [
        SizedBox(width: 62, child: Text(label, style: const TextStyle(color: Brand.muted, fontSize: 13))),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final hex in _swatches)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Semantics(
                    button: true,
                    selected: current.toLowerCase() == hex,
                    label: '$label colour $hex',
                    child: Pressable(
                      onTap: () => pick(hex),
                      scale: 0.9,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: current.toLowerCase() == hex ? Brand.ink : Colors.transparent, width: 2)),
                        child: _dot(hex, 26),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]);
}

Widget _logoOrInitials(String logo, String name, String c1, double size) => logo.isNotEmpty
    ? ClipRRect(borderRadius: BorderRadius.circular(size * 0.2), child: SizedBox(width: size, height: size, child: NetImage(logo, fit: BoxFit.contain, placeholder: const SizedBox())))
    : Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: hexColor(c1), shape: BoxShape.circle),
        child: Text(initials(name), style: Brand.head(size * 0.38, weight: FontWeight.w800, color: Colors.white)),
      );

/// A business card in the brand colours.
class _BrandCard extends StatelessWidget {
  final String name, tagline, logo, c1, c2, phone;
  const _BrandCard({required this.name, required this.tagline, required this.logo, required this.c1, required this.c2, required this.phone});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: hexColor(c1), width: 6)),
          boxShadow: Brand.shadow,
        ),
        child: Row(children: [
          _logoOrInitials(logo, name, c1, 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.trim().isEmpty ? 'Your brand' : name, style: Brand.head(18, color: hexColor(c2) == Colors.white ? Brand.ink : hexColor(c2))),
              Text(tagline.trim().isEmpty ? 'Your tagline here' : tagline, style: const TextStyle(color: Brand.muted, fontSize: 13)),
              if (phone.isNotEmpty) Text(phone, style: TextStyle(color: hexColor(c1), fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );
}

/// A WhatsApp-status style post in the brand colours.
class _BrandPost extends StatelessWidget {
  final String name, tagline, logo, c1, c2;
  const _BrandPost({required this.name, required this.tagline, required this.logo, required this.c1, required this.c2});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1.4,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [hexColor(c1), hexColor(c2)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New stock in!', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(tagline.trim().isEmpty ? 'Quality you can trust' : tagline, style: Brand.head(22, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.1)),
            const Spacer(),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: _logoOrInitials(logo, name, c1, 40),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('${name.trim()} · Order on WhatsApp', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
            ]),
          ]),
        ),
      );
}
