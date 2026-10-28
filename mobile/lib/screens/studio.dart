import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../app_state.dart';
import '../media.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'brand.dart';
import 'cart.dart';

/// AiStudio, the website's studio.html: put your logo on a product, pick a
/// colour, then order that many customised pieces. The design rides along
/// with the order to the factory.
class StudioScreen extends StatefulWidget {
  final String productId;
  const StudioScreen({super.key, required this.productId});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  static const _tints = ['', '#e0182d', '#1d4ed8', '#0b7a43', '#111216', '#f5a50b', '#8b5cf6', '#ec4899'];

  final _canvasKey = GlobalKey();
  final _prompt = TextEditingController();
  final _notes = TextEditingController();
  late final TextEditingController _pieces;
  String _logo = '', _saved = '', _tint = '';
  double _x = 0.5, _y = 0.5, _size = 0.3, _rot = 0;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _saved = (s.user?.brand['logo'] ?? '') as String;
    _logo = _saved;
    final p = s.product(widget.productId);
    _pieces = TextEditingController(text: '${p?.businessMin ?? 10}');
  }

  @override
  void dispose() {
    _prompt.dispose();
    _notes.dispose();
    _pieces.dispose();
    super.dispose();
  }

  void _placeDefault() => setState(() {
        _x = 0.5;
        _y = 0.48;
        _size = 0.28;
        _rot = 0;
      });

  Future<void> _upload() async {
    final img = await pickImageDataUrl(context);
    if (img != null) setState(() { _logo = img; _error = null; });
  }

  /// Centre the logo at a sensible size and colour the product to match it.
  Future<void> _auto() async {
    if (_logo.isEmpty) return setState(() => _error = 'Upload your logo first, or use the one from your brand kit.');
    _placeDefault();
    final c = await _logoColour(_logo);
    if (!mounted) return;
    setState(() { _tint = c ?? ''; _error = null; });
    showMessage(context, 'Logo placed and colour matched');
  }

  /// The logo's main colour: the average of its strongly coloured pixels.
  static Future<String?> _logoColour(String dataUrl) async {
    try {
      final bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 48, targetHeight: 48);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData();
      if (data == null) return null;
      var r = 0, g = 0, b = 0, n = 0;
      for (var i = 0; i < data.lengthInBytes; i += 4) {
        final pr = data.getUint8(i), pg = data.getUint8(i + 1), pb = data.getUint8(i + 2), pa = data.getUint8(i + 3);
        final hi = math.max(pr, math.max(pg, pb)), lo = math.min(pr, math.min(pg, pb));
        if (pa < 128 || hi - lo < 50) continue; // skip see-through, white, grey and black
        r += pr; g += pg; b += pb; n++;
      }
      if (n == 0) return null;
      return colorHex(Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n));
    } catch (_) {
      return null;
    }
  }

  Future<void> _generate(Product p) async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) return setState(() => _error = 'Describe what you want before generating.');
    setState(() { _generating = true; _error = null; });
    try {
      final res = await context.read<AppState>().api.request('POST', '/api/design/generate',
          body: {'prompt': prompt, 'productName': p.name}, timeout: const Duration(seconds: 90)) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _logo = res['image'] as String);
      _placeDefault();
      showMessage(context, 'Design generated. Drag it into place.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message.contains('OPENAI_API_KEY') ? 'AI design isn\'t switched on yet. Try the colour variants or upload your own logo.' : e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// A small picture of the design, so the order shows what was asked for.
  Future<String> _snapshot() async {
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 320 / boundary.size.width);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      return png == null ? '' : 'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}';
    } catch (_) {
      return ''; // a photo the browser won't let us read; the order keeps the logo and notes
    }
  }

  Future<void> _addToCart(AppState s, Product p) async {
    final min = p.businessMin;
    final pieces = int.tryParse(_pieces.text.trim()) ?? 0;
    final notes = _notes.text.trim();
    if (_logo.isEmpty && notes.isEmpty && _tint.isEmpty) return setState(() => _error = 'Upload a logo, pick a colour or write what you want.');
    if (pieces < min || pieces > p.stock) return setState(() => _error = 'Enter between $min and ${p.stock} pieces.');
    final preview = await _snapshot();
    final err = s.addToCart(p, pieces, custom: {'logo': _logo, 'preview': preview, 'tint': _tint, 'pieces': pieces, 'notes': notes});
    if (!mounted) return;
    if (err != null) return setState(() => _error = err);
    if (_logo.isNotEmpty && _logo != _saved) s.saveBrand({'logo': _logo}).catchError((_) {});
    showMessage(context, 'Added $pieces customised to cart');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.product(widget.productId);
    if (p == null) return _blocked('Product not found', 'It may have been removed.');
    if (!s.isBusiness) return _blocked('For business buyers', 'Switch to Business to put your logo on products.');
    if (!isCustomizable(p)) return _blocked('Can\'t be customised', '${p.name} already carries its own brand, so your logo can\'t go on it.');
    if (p.stock < p.businessMin) return _blocked('Not enough stock', '${p.name} doesn\'t have enough left for a business order right now.');

    return Scaffold(
      appBar: AppBar(title: Text('AiStudio', style: Brand.head(22, weight: FontWeight.w800, color: Brand.red))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Text('Customize your ${p.name}', style: Brand.head(24).copyWith(height: 1.15)),
        const SizedBox(height: 12),
        CardBox(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Project: ${p.name}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            AspectRatio(aspectRatio: 1, child: _canvas(p)),
            const SizedBox(height: 10),
            Text(_logo.isEmpty ? 'Use Upload below to place your logo.' : 'Drag the logo to move it.', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _tool(Icons.upload_rounded, 'Upload', _upload),
          _tool(Icons.workspace_premium_outlined, 'Brand logo', _saved.isEmpty
              ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrandScreen()))
              : () => setState(() => _logo = _saved)),
          _tool(Icons.auto_fix_high, 'Auto design', _auto),
          _tool(Icons.center_focus_strong_outlined, 'Centre', _placeDefault),
          _tool(Icons.layers_clear_outlined, 'Remove', () => setState(() => _logo = '')),
        ]),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('AI Customization', style: Brand.head(19)),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Describe your design... e.g. Modern mountain sunset logo, forest vibes, minimalist, vibrant gradient'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _generating ? null : () => _generate(p),
              icon: _generating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high, size: 18),
              label: Text(_generating ? 'Generating…' : 'Generate'),
            ),
            const SizedBox(height: 14),
            const Text('Or pick a quick colour variant', style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in _tints)
                Semantics(
                  button: true,
                  selected: _tint == c,
                  label: c.isEmpty ? 'Original colour' : 'Colour $c',
                  child: Pressable(
                    onTap: () => setState(() => _tint = c),
                    scale: 0.9,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.isEmpty ? Colors.white : hexColor(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: _tint == c ? Brand.ink : Brand.line, width: _tint == c ? 2.5 : 1),
                      ),
                      child: c.isEmpty ? const Icon(Icons.close, size: 16, color: Brand.muted) : null,
                    ),
                  ),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Logo size', style: TextStyle(fontWeight: FontWeight.w700)),
            Slider(value: _size, min: 0.08, max: 0.8, activeColor: Brand.red, onChanged: _logo.isEmpty ? null : (v) => setState(() => _size = v)),
            const Text('Turn logo', style: TextStyle(fontWeight: FontWeight.w700)),
            Slider(value: _rot, min: -180, max: 180, activeColor: Brand.red, onChanged: _logo.isEmpty ? null : (v) => setState(() => _rot = v)),
            Text(_saved.isNotEmpty ? 'Using the logo from your brand kit. Upload to change it.' : 'A PNG with a clear background looks best.',
                style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Order details', style: Brand.head(19)),
            const SizedBox(height: 12),
            TextField(
              controller: _pieces,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'How many pieces to customise', helperText: 'Minimum order for this product is ${p.businessMin}.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLength: 400,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes for the factory', hintText: 'For example: print the logo on the front, gold colour, our phone number under it'),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Brand.red600, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => _addToCart(s, p), icon: const Icon(Icons.shopping_cart_outlined, size: 19), label: const Text('Add to cart')),
          ]),
        ),
      ]),
    );
  }

  Widget _canvas(Product p) => LayoutBuilder(builder: (context, box) {
        final side = box.maxWidth;
        final logoW = side * _size;
        // White behind the photo inside the filter: see-through areas would otherwise take the full tint colour.
        Widget photo = ColoredBox(
          color: Colors.white,
          child: Padding(padding: EdgeInsets.all(side * 0.05), child: NetImage(p.photos.isEmpty ? '' : p.photos.first, placeholder: const ColoredBox(color: Color(0xFFECEEF3)))),
        );
        if (_tint.isNotEmpty) photo = ColorFiltered(colorFilter: _tintFilter(hexColor(_tint)), child: photo);
        return RepaintBoundary(
          key: _canvasKey,
          child: GestureDetector(
            onPanStart: _logo.isEmpty ? null : (d) => _moveTo(d.localPosition, side),
            onPanUpdate: _logo.isEmpty ? null : (d) => _moveTo(d.localPosition, side),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: Colors.white,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: photo),
                  if (_logo.isNotEmpty)
                    Positioned(
                      left: _x * side - logoW / 2,
                      top: _y * side - logoW / 2,
                      width: logoW,
                      height: logoW,
                      child: Transform.rotate(angle: _rot * math.pi / 180, child: NetImage(_logo, placeholder: const SizedBox())),
                    ),
                ]),
              ),
            ),
          ),
        );
      });

  /// Recolours a photo: it becomes greyscale, then the darker a pixel, the more
  /// of the tint it takes, so white stays white (as on the website) and the
  /// item itself changes colour. A plain matrix, so every device draws it the same.
  static ColorFilter _tintFilter(Color tint) {
    const strength = 0.9;
    List<double> row(double c) {
      final b = c * strength; // what pure black turns into, 0..1
      final k = 1 - b; // how much of the brightness passes through
      return [0.2126 * k, 0.7152 * k, 0.0722 * k, 0, b * 255];
    }

    return ColorFilter.matrix([...row(tint.r), ...row(tint.g), ...row(tint.b), 0, 0, 0, 1, 0]);
  }

  void _moveTo(Offset at, double side) => setState(() {
        _x = (at.dx / side).clamp(0.0, 1.0);
        _y = (at.dy / side).clamp(0.0, 1.0);
      });

  Widget _tool(IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: Brand.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40E0182D), blurRadius: 12, offset: Offset(0, 5))]),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _blocked(String title, String text) => Scaffold(
        appBar: AppBar(title: Text('AiStudio', style: Brand.head(22, weight: FontWeight.w800, color: Brand.red))),
        body: EmptyState(icon: Icons.inventory_2_outlined, title: title, text: text, action: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back'))),
      );
}
