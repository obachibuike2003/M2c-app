import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'photo_search.dart';

/// "All categories", the long list the site links to from the home page.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final counts = <String, int>{};
    for (final p in s.products) {
      counts[p.cat] = (counts[p.cat] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: () => openSearch(context))],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: s.categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CategoryRow(
              leading: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: Brand.ink, shape: BoxShape.circle),
                child: const Icon(Icons.grid_view_rounded, color: Colors.white),
              ),
              title: 'All products',
              subtitle: '${s.products.length} products',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductListScreen())),
            );
          }
          final c = s.categories[i - 1];
          return FadeIn(
            delay: Duration(milliseconds: 30 * (i % 10)),
            child: _CategoryRow(
              leading: CategoryBubble(category: c, size: 52),
              title: c.name,
              subtitle: '${counts[c.id] ?? 0} products',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(categoryId: c.id))),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Widget leading;
  final String title, subtitle;
  final VoidCallback onTap;
  const _CategoryRow({required this.leading, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Brand.head(16)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Brand.muted, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Brand.muted),
          ]),
        ),
      );
}

void openSearch(BuildContext context, {String? categoryId}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(categoryId: categoryId, searching: true)));

enum _Sort { popular, low, high, discount, rating }

const _sortLabels = {
  _Sort.popular: 'Most popular', _Sort.low: 'Price: low to high', _Sort.high: 'Price: high to low',
  _Sort.discount: 'Biggest discount', _Sort.rating: 'Top rated',
};

/// A category's products (or everything), with subcategory chips, condition,
/// sort and search, matching the website's listing page.
class ProductListScreen extends StatefulWidget {
  final String? categoryId;
  final bool searching;

  /// Start filtered to 'new' or 'used' items.
  final String condition;
  const ProductListScreen({super.key, this.categoryId, this.searching = false, this.condition = ''});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _sub;
  late String _condition = widget.condition;
  _Sort _sort = _Sort.popular;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cat = widget.categoryId == null ? null : s.category(widget.categoryId!);
    final inCat = s.products.where((p) => widget.categoryId == null || p.cat == widget.categoryId).toList();
    final subs = <String>{for (final p in inCat) if (p.sub != null) p.sub!}.toList();

    final q = _query.trim().toLowerCase();
    final list = inCat.where((p) {
      if (_sub != null && p.sub != _sub) return false;
      if (_condition.isNotEmpty && p.condition != _condition) return false;
      if (q.isNotEmpty && !'${p.name} ${p.desc} ${s.category(p.cat)?.name ?? ''}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList()
      ..sort(switch (_sort) {
        _Sort.popular => (a, b) => b.sold.compareTo(a.sold),
        _Sort.low => (a, b) => a.price.compareTo(b.price),
        _Sort.high => (a, b) => b.price.compareTo(a.price),
        _Sort.discount => (a, b) => b.discount.compareTo(a.discount),
        _Sort.rating => (a, b) => b.rating.compareTo(a.rating),
      });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: widget.searching ? 0 : null,
        title: widget.searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: cat == null ? 'Search phones, cars, raw materials' : 'Search in ${cat.name}',
                  filled: true,
                  fillColor: const Color(0xFFF0F1F4),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const CameraSearchButton(),
                      const SizedBox(width: 6),
                      // Typing already filters live; this just closes the keyboard to show results.
                      SearchGoButton(onTap: () => FocusScope.of(context).unfocus()),
                    ]),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Brand.red, width: 1.5)),
                ),
              )
            : Text(cat?.name ?? 'All products'),
        actions: [
          if (!widget.searching) IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: () => openSearch(context, categoryId: widget.categoryId)),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [for (final e in _sortLabels.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), children: [
              if (subs.length > 1) ...[
                _chip('All', _sub == null, () => setState(() => _sub = null)),
                for (final sub in subs) _chip(sub, _sub == sub, () => setState(() => _sub = _sub == sub ? null : sub)),
                const VerticalDivider(width: 18, indent: 8, endIndent: 8, color: Brand.line),
              ],
              _chip('Brand new', _condition == 'new', () => setState(() => _condition = _condition == 'new' ? '' : 'new')),
              _chip('Used', _condition == 'used', () => setState(() => _condition = _condition == 'used' ? '' : 'used')),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Text(
              '${list.length} product${list.length == 1 ? '' : 's'} · ${_sortLabels[_sort]}${s.isBusiness ? ' · wholesale prices, per piece' : ''}',
              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
            ),
          ),
        ),
        if (list.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(icon: Icons.search_off_rounded, title: 'Nothing matches', text: 'Try a different search, subcategory or condition.'),
          )
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), sliver: SliverToBoxAdapter(child: ProductGrid(products: list))),
      ]),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: on, showCheckmark: false, onSelected: (_) => onTap()),
      );
}

/// Product list for a fixed set, e.g. "Recommended for you" in full.
class FixedListScreen extends StatelessWidget {
  final String title;
  final List<Product> products;
  const FixedListScreen({super.key, required this.title, required this.products});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(16), children: [ProductGrid(products: products)]),
      );
}
