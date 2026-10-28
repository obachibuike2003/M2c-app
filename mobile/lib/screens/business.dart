import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'orders.dart';

/// The Business tab, shown in place of Exchange for business buyers, like the
/// website's business hub: tools, your agent, wholesale tiers and picks.
class BusinessScreen extends StatelessWidget {
  /// Jumps the shell to another tab (1 = Shop).
  final ValueChanged<int> goToTab;
  const BusinessScreen({super.key, required this.goToTab});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    if (u == null || !s.isBusiness) {
      return const Scaffold(body: EmptyState(icon: Icons.work_outline, title: 'Business buying', text: 'Switch to Business on your Account tab to see your hub.'));
    }
    final biz = u.business ?? const {};
    final type = AppConfig.businessTypes.where((t) => t.id == biz['type']).firstOrNull;
    final agentId = u.raw['agentId'] as String?;
    final agent = AppConfig.agents.where((a) => a.id == agentId).firstOrNull;
    final picks = s.recommended.take(10).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Business'), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        // Header card, the site's warehouse banner.
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(children: [
            Positioned.fill(child: NetImage('assets/banners/warehouse.jpg', fit: BoxFit.cover, placeholder: const ColoredBox(color: Brand.ink))),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xEB111216), Color(0x80111216)])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BUSINESS HUB', style: TextStyle(color: Color(0xFFFF8A95), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text('${biz['name'] ?? 'Your business'}', style: Brand.head(26, weight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  '${type != null ? '${type.name} · ' : ''}Wholesale prices from ${AppConfig.bulkMinQty} pieces, your own agent, and your brand on the goods you buy.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            _Tool(icon: Icons.smart_toy_outlined, title: 'AI business assistant', text: 'Prices, margins and advice.', onTap: () => _openSite(context, 'assistant.html')),
            _Tool(icon: Icons.palette_outlined, title: 'Build my brand', text: 'Logo, colours and tagline.', onTap: () => _openSite(context, 'brand.html')),
            _Tool(icon: Icons.grid_view_rounded, title: 'Buy in bulk', text: 'Everything at wholesale.', onTap: () => goToTab(1)),
            _Tool(
              icon: Icons.local_shipping_outlined,
              title: 'Track my goods',
              text: 'From China to your door.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersScreen())),
            ),
          ],
        ),
        const SizedBox(height: 14),
        CardBox(
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: Brand.red, child: Text(agent?.name[0] ?? '?', style: Brand.head(20, color: Colors.white))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(agent?.name ?? 'Your agent', style: Brand.head(17)),
                Text(agent != null ? 'Your Easy2buy agent' : 'An agent will be assigned soon', style: const TextStyle(color: Brand.muted, fontSize: 13)),
              ]),
            ),
            if (agent != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA855), minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => _open(context, Uri.https('wa.me', '/${agent.whatsapp}', {
                  'text': 'Hi ${agent.name}, this is ${u.name} (${biz['name'] ?? ''}) on ${AppConfig.appName}.',
                })),
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('WhatsApp'),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your wholesale prices', style: Brand.head(18)),
            const SizedBox(height: 4),
            const Text('The more of one item you buy, the less you pay for each.', style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              _Tier(top: 'Minimum', big: '${AppConfig.bulkMinQty}', small: 'pieces per item'),
              for (final t in AppConfig.bulkTiers) ...[const SizedBox(width: 8), _Tier(top: '${t.from}+ pieces', big: '${t.off}%', small: 'off retail')],
            ]),
            const SizedBox(height: 10),
            const Text('Some big items, like cars, have a smaller minimum.', style: TextStyle(color: Brand.muted, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    await s.setPersonal();
                    if (context.mounted) showMessage(context, 'You are buying for yourself');
                  } catch (e) {
                    if (context.mounted) showMessage(context, e.toString(), error: true);
                  }
                },
                child: const Text('Switch to personal buying'),
              ),
            ),
          ]),
        ),
        if (picks.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionHead(kicker: 'For ${biz['name'] ?? 'you'}', title: 'Picked for your business', action: 'All', onAction: () => goToTab(1)),
          ProductGrid(products: picks),
        ],
      ]),
    );
  }

  static void _openSite(BuildContext context, String page) => _open(context, Uri.parse('${AppConfig.siteBase}/$page'));

  static Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) showMessage(context, 'Couldn\'t open that link.', error: true);
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;
  const _Tool({required this.icon, required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: CardBox(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Brand.blueSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Brand.blue, size: 22),
            ),
            const Spacer(),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12)),
          ]),
        ),
      );
}

class _Tier extends StatelessWidget {
  final String top, big, small;
  const _Tier({required this.top, required this.big, required this.small});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: Brand.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.line)),
          child: Column(children: [
            Text(top, style: const TextStyle(color: Brand.muted, fontSize: 11), textAlign: TextAlign.center),
            Text(big, style: Brand.head(20, color: Brand.blue)),
            Text(small, style: const TextStyle(color: Brand.muted, fontSize: 10.5), textAlign: TextAlign.center),
          ]),
        ),
      );
}
