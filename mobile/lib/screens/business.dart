import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../media.dart';
import '../theme.dart';
import '../widgets.dart';
import 'assistant.dart';
import 'brand.dart';
import 'orders.dart';

/// The Business tab, shown in the middle of the bar for business buyers,
/// laid out like the website's business hub (business.html).
class BusinessScreen extends StatefulWidget {
  /// Jumps the shell to another tab (1 = Shop).
  final ValueChanged<int> goToTab;
  const BusinessScreen({super.key, required this.goToTab});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    if (u == null || !s.isBusiness) {
      return const Scaffold(body: EmptyState(icon: Icons.work_outline, title: 'Business buying', text: 'Switch to Business at the top of Home to open your hub.'));
    }
    final biz = u.business ?? const {};
    final name = '${biz['name'] ?? 'Your business'}';
    final type = AppConfig.businessTypes.where((t) => t.id == biz['type']).firstOrNull;
    final agent = AppConfig.agents.where((a) => a.id == u.raw['agentId']).firstOrNull;
    final first = u.firstName;

    void sendToAgent() {
      if (agent == null) return;
      final text = _message.text.trim();
      openLink(context, whatsappLink(agent.whatsapp, text.isEmpty ? 'Hi ${agent.name}, this is ${u.name} ($name) on ${AppConfig.appName}.' : text));
      _message.clear();
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
          PageHero(
            kicker: 'Business hub',
            title: name,
            text: '${type != null ? '${type.name} · ' : ''}Wholesale prices from ${AppConfig.bulkMinQty} pieces, your own agent, and your brand on the goods you buy.',
            photo: 'assets/banners/warehouse.jpg',
          ),
          const SizedBox(height: 14),
          TwoColumn(children: [
            ToolCard(
              icon: Icons.smart_toy_outlined,
              title: 'AI business assistant',
              text: 'Find products, work out prices and margins, get advice.',
              onTap: () => _push(const AssistantScreen()),
            ),
            ToolCard(
              icon: Icons.palette_outlined,
              title: 'Build my brand',
              text: 'Logo, colours and tagline, then put them on your goods.',
              onTap: () => _push(const BrandScreen()),
            ),
            ToolCard(
              icon: Icons.grid_view_rounded,
              title: 'Buy in bulk',
              text: 'Every product at wholesale price. Customise with your logo.',
              onTap: () => widget.goToTab(1),
            ),
            ToolCard(
              icon: Icons.local_shipping_outlined,
              title: 'Track my goods',
              text: 'From the factory in China to your door.',
              onTap: () => _push(const OrdersScreen()),
            ),
          ]),
          const SizedBox(height: 16),

          // Agent: the website keeps this chat in the browser, so the app sends it on WhatsApp, which reaches them.
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 24, backgroundColor: Brand.red, child: Text(agent?.name[0] ?? '?', style: Brand.head(20, color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(agent?.name ?? 'Your agent', style: Brand.head(19)),
                    Text(agent != null ? 'Your Eazy2buy agent' : 'An agent will be assigned soon', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  ]),
                ),
                if (agent != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: sendToAgent,
                    icon: const Icon(Icons.chat_outlined, size: 17, color: Color(0xFF1FA855)),
                    label: const Text('WhatsApp'),
                  ),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Brand.bg, borderRadius: BorderRadius.circular(14)),
                child: Text('Say hello, $first. Ask about prices, custom orders or delivery.', style: const TextStyle(color: Brand.muted, fontSize: 13.5)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    enabled: agent != null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendToAgent(),
                    decoration: InputDecoration(hintText: 'Message ${agent?.name ?? 'your agent'}', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send on WhatsApp',
                  style: IconButton.styleFrom(backgroundColor: Brand.red),
                  onPressed: agent == null ? null : sendToAgent,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your wholesale prices', style: Brand.head(19)),
              const SizedBox(height: 6),
              const Text('The more of one item you buy, the less you pay for each.', style: TextStyle(color: Brand.muted, fontSize: 13.5)),
              const SizedBox(height: 10),
              _tierRow('Minimum order', '${AppConfig.bulkMinQty} pieces', 'per item'),
              for (final t in AppConfig.bulkTiers) _tierRow('${t.from}+ pieces', '${t.off}% off', 'retail price'),
              const SizedBox(height: 8),
              const Text('Some big items, like cars, have a smaller minimum.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              const SizedBox(height: 14),
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
          if (s.recommended.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHead(kicker: 'For $name', title: 'Picked for your business', action: 'All products', onAction: () => widget.goToTab(1)),
            ProductGrid(products: s.recommended.take(10).toList()),
          ],
        ]),
      ),
    );
  }

  Widget _tierRow(String label, String value, String note) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.line))),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: Brand.text))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: Brand.head(16)),
            Text(note, style: const TextStyle(color: Brand.muted, fontSize: 11.5)),
          ]),
        ]),
      );
}
