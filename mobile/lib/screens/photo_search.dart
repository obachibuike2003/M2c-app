import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// The camera button in the search bars: asks camera or gallery, then opens
/// the results. Matches the website's "search by photo".
Future<void> startPhotoSearch(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    sheetAnimationStyle: AnimationStyle(curve: easeDrawer, duration: const Duration(milliseconds: 340), reverseDuration: const Duration(milliseconds: 200)),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Search by photo', style: Brand.head(22)),
          const SizedBox(height: 4),
          const Text('Snap or pick a photo of an item and we\'ll find ones like it.', style: TextStyle(color: Brand.muted, height: 1.4)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _SourceTile(icon: Icons.photo_camera_outlined, label: 'Take a photo', onTap: () => Navigator.pop(sheet, ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: _SourceTile(icon: Icons.photo_library_outlined, label: 'From gallery', onTap: () => Navigator.pop(sheet, ImageSource.gallery))),
          ]),
        ]),
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  XFile? file;
  try {
    // Small is plenty for matching, and keeps the upload quick on mobile data.
    file = await ImagePicker().pickImage(source: source, maxWidth: 900, maxHeight: 900, imageQuality: 82);
  } catch (e) {
    debugPrint('photo search: pickImage failed: $e');
    if (context.mounted) showMessage(context, 'Couldn\'t open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.', error: true);
    return;
  }
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoResultsScreen(bytes: bytes, mime: file!.mimeType ?? 'image/jpeg')));
}

/// Round red camera button that sits at the end of a search bar.
class CameraSearchButton extends StatelessWidget {
  const CameraSearchButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Search by photo',
        child: Pressable(
          onTap: () => startPhotoSearch(context),
          scale: 0.9,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: Brand.redSoft, shape: BoxShape.circle),
            child: const Icon(Icons.photo_camera_outlined, color: Brand.red600, size: 20),
          ),
        ),
      );
}

/// Red round search button that sits after the camera, like the website's.
class SearchGoButton extends StatelessWidget {
  final VoidCallback onTap;
  const SearchGoButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Search',
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          scale: 0.9,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: Brand.red, shape: BoxShape.circle),
            child: const Icon(Icons.search_rounded, color: Colors.white, size: 21),
          ),
        ),
      );
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: Brand.bg, borderRadius: BorderRadius.circular(Brand.radius), border: Border.all(color: Brand.line)),
          child: Column(children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: Brand.redSoft, shape: BoxShape.circle),
              child: Icon(icon, color: Brand.red600, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      );
}

class PhotoResultsScreen extends StatefulWidget {
  final Uint8List bytes;
  final String mime;
  const PhotoResultsScreen({super.key, required this.bytes, required this.mime});

  @override
  State<PhotoResultsScreen> createState() => _PhotoResultsScreenState();
}

class _PhotoResultsScreenState extends State<PhotoResultsScreen> {
  late Future<({String? label, List<Product> products})> _search;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _search = s.searchByPhoto(widget.bytes, widget.mime).then((r) {
      if (r.label != null) s.noteSearch(r.label!);
      return r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Similar items'),
        actions: [
          IconButton(tooltip: 'Try another photo', icon: const Icon(Icons.photo_camera_outlined), onPressed: () => startPhotoSearch(context)),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder(
        future: _search,
        builder: (context, snap) {
          final done = snap.connectionState == ConnectionState.done;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            CardBox(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _ScanningPhoto(bytes: widget.bytes, scanning: !done),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: Column(
                      key: ValueKey(done),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: !done
                          ? [Text('Looking for matches', style: Brand.head(17)), const SizedBox(height: 4), const Text('Comparing your photo with every product...', style: TextStyle(color: Brand.muted, fontSize: 13))]
                          : snap.hasError
                              ? [Text('Search didn\'t work', style: Brand.head(17)), const SizedBox(height: 4), Text('${snap.error}', style: const TextStyle(color: Brand.muted, fontSize: 13))]
                              : [
                                  Text(snap.data!.label == null ? 'Your photo' : _cap(snap.data!.label!), style: Brand.head(17)),
                                  const SizedBox(height: 4),
                                  Text('${snap.data!.products.length} items that look like it', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                                ],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (!done)
              const _GridSkeleton()
            else if (snap.hasError)
              Center(child: FilledButton(onPressed: () => setState(() => _search = context.read<AppState>().searchByPhoto(widget.bytes, widget.mime)), child: const Text('Try again')))
            else if (snap.data!.products.isEmpty)
              const EmptyState(icon: Icons.image_search, title: 'No matches yet', text: 'Try a clearer photo with the item in the middle.')
            else ...[
              const SectionHead(kicker: 'Best matches', title: 'Looks like your photo'),
              ProductGrid(products: snap.data!.products),
            ],
          ]);
        },
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// The user's photo with a red scan line sweeping over it while we search.
class _ScanningPhoto extends StatefulWidget {
  final Uint8List bytes;
  final bool scanning;
  const _ScanningPhoto({required this.bytes, required this.scanning});

  @override
  State<_ScanningPhoto> createState() => _ScanningPhotoState();
}

class _ScanningPhotoState extends State<_ScanningPhoto> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_ScanningPhoto old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.scanning && !reduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 84.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          Image.memory(widget.bytes, fit: BoxFit.cover),
          if (widget.scanning)
            AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Align(
                alignment: Alignment(0, Curves.easeInOut.transform(_c.value) * 2 - 1),
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Brand.red,
                    boxShadow: [BoxShadow(color: Color(0x99E0182D), blurRadius: 10, spreadRadius: 2)],
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Grey placeholder cards while results load, so the layout doesn't jump.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Brand.radius), boxShadow: Brand.shadow),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AspectRatio(aspectRatio: 1, child: Container(decoration: BoxDecoration(color: const Color(0xFFF0F1F4), borderRadius: BorderRadius.circular(14)))),
                const SizedBox(height: 10),
                Container(height: 12, width: double.infinity, color: const Color(0xFFF0F1F4)),
                const SizedBox(height: 6),
                Container(height: 12, width: 70, color: const Color(0xFFF0F1F4)),
              ]),
            ),
        ],
      );
}
