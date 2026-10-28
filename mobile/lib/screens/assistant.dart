import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../app_state.dart';
import '../config.dart';
import '../media.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'brand.dart';
import 'business.dart';
import 'exchange.dart';
import 'orders.dart';
import 'product.dart';
import 'shop.dart';

/// Where an answer's buttons lead. `human` opens WhatsApp with a real person.
enum _Go { brand, agent, orders, products, used, exchange, human }

class _Msg {
  final bool me;
  final String text;
  final List<Product> products;
  final List<(String, _Go)> actions;
  const _Msg(this.me, this.text, {this.products = const [], this.actions = const []});
}

/// The business assistant (the website's assistant.html), or customer care
/// with [support]. Answers come from OpenAI through the backend when it's
/// switched on, and from the built-in answers (js/assistant.js) otherwise.
/// Customer care hands complex issues to a person on WhatsApp.
class AssistantScreen extends StatefulWidget {
  final bool support;
  const AssistantScreen({super.key, this.support = false});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _businessSuggestions = ['What should I stock first?', 'How much for 50 power banks?', 'How do I price my goods?', 'Where is my order?', 'Ideas to get more customers', 'Find caustic soda'];
  static const _supportSuggestions = ['Where is my order?', 'How long does delivery take?', 'How does pay on delivery work?', 'My item arrived damaged', 'How do I switch to business buying?'];

  /// Set once the server says AI is off, so we stop asking it.
  bool _aiOff = false;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <_Msg>[];
  bool _typing = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String text) async {
    text = text.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _history.add(_Msg(true, text));
      _typing = true;
    });
    _toBottom();
    final results = await Future.wait([_reply(text), Future.delayed(const Duration(milliseconds: 450))]);
    if (!mounted) return;
    setState(() {
      _history.add(results.first as _Msg);
      _typing = false;
    });
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: easeOutStrong);
      });

  void _go(_Go where) {
    final Widget screen = switch (where) {
      _Go.brand => const BrandScreen(),
      _Go.agent => BusinessScreen(goToTab: (_) => Navigator.of(context).pop()),
      _Go.orders => const OrdersScreen(),
      _Go.products => const ProductListScreen(),
      _Go.used => const ProductListScreen(condition: 'used'),
      _Go.exchange => const ExchangeScreen(),
      _Go.human => const SizedBox(),
    };
    if (where == _Go.human) return _talkToPerson();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// WhatsApp a real person: a business buyer's own agent, or Easy2buy support.
  void _talkToPerson() {
    final s = context.read<AppState>();
    final u = s.user;
    final agent = s.isBusiness ? AppConfig.agents.where((a) => a.id == u?.raw['agentId']).firstOrNull : null;
    // Hand over what was said, so they don't have to start again.
    final asked = _history.where((m) => m.me).map((m) => m.text).toList();
    final summary = asked.isEmpty ? '' : ' I asked: "${asked.last}"';
    final who = u == null ? '' : ' This is ${u.name}${u.business?['name'] != null ? ' (${u.business!['name']})' : ''}.';
    final link = agent != null
        ? whatsappLink(agent.whatsapp, 'Hi ${agent.name},$who$summary')
        : whatsappLink(supportWhatsappDigits, 'Hi ${AppConfig.appName},$who$summary');
    openLink(context, link);
  }

  /// OpenAI through the backend. Null means "use the built-in answers".
  Future<_Msg?> _aiReply() async {
    final s = context.read<AppState>();
    if (_aiOff || s.user == null) return null;
    final messages = [
      for (final m in _history) {'role': m.me ? 'user' : 'assistant', 'content': m.text},
    ];
    try {
      final res = await s.api.request('POST', '/api/assistant/chat',
          body: {'mode': widget.support ? 'support' : 'business', 'messages': messages}, timeout: const Duration(seconds: 50)) as Map<String, dynamic>;
      final products = [for (final id in (res['products'] as List? ?? const [])) ?s.product('$id')];
      final handoff = res['handoff'] == true;
      return _Msg(false, '${res['reply']}', products: products, actions: [if (handoff) ('Talk to a person', _Go.human)]);
    } on ApiException catch (e) {
      if (e.code == 'ai_off' || e.status == 401) {
        _aiOff = true;
        return null;
      }
      return _Msg(false, e.message, actions: const [('Talk to a person', _Go.human)]);
    }
  }

  // ---------------------------------------------------------------- the brain

  static const _stop = {
    'a', 'an', 'the', 'i', 'me', 'my', 'we', 'our', 'you', 'your', 'for', 'of', 'to', 'in', 'on', 'and', 'or', 'is', 'are', 'be', 'can', 'do', 'does',
    'how', 'what', 'which', 'where', 'who', 'want', 'need', 'looking', 'find', 'show', 'get', 'buy', 'sell', 'some', 'any', 'with', 'please', 'pls', 'abeg',
    'about', 'have', 'has', 'it', 'this', 'that', 'there', 'their', 'them', 'from', 'at', 'by', 'per', 'pieces', 'piece', 'pcs', 'units', 'unit', 'much',
    'many', 'cost', 'price', 'prices',
  };

  static bool _has(String text, List<String> keys) => keys.any(text.contains);

  List<Product> _search(AppState s, String text, [int limit = 4]) {
    final terms = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.length > 1 && !_stop.contains(w)).toList();
    if (terms.isEmpty) return [];
    String stem(String t) => t.replaceFirst(RegExp(r'(es|s)$'), '');
    final scored = <(Product, int)>[];
    for (final p in s.products) {
      final name = p.name.toLowerCase(), cat = (s.category(p.cat)?.name ?? '').toLowerCase(), desc = p.desc.toLowerCase();
      final score = terms.fold<int>(0, (n, t) => n + (name.contains(stem(t)) ? 3 : 0) + (cat.contains(stem(t)) ? 2 : 0) + (desc.contains(stem(t)) ? 1 : 0));
      if (score > 0) scored.add((p, score));
    }
    scored.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : b.$1.sold.compareTo(a.$1.sold));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  Future<_Msg> _reply(String raw) async {
    final ai = await _aiReply();
    if (ai != null) return ai;
    if (!mounted) return const _Msg(false, '');
    return widget.support ? _supportReply(raw) : _localReply(raw);
  }

  /// Built-in customer care when AI is off: simple answers, and a person for anything serious.
  Future<_Msg> _supportReply(String raw) async {
    final text = raw.toLowerCase();
    const human = [('Talk to a person', _Go.human)];
    if (_has(text, ['refund', 'damaged', 'broken', 'missing', 'wrong item', 'not what i ordered', 'complain', 'cancel', 'scam', 'money', 'charged', 'paid twice'])) {
      return const _Msg(false, 'Sorry about that. This needs one of our team, so I\'m passing you to a person. Tap below and send your order number.', actions: human);
    }
    if (_has(text, ['delivery', 'how long', 'arrive', 'shipping'])) {
      return _Msg(false, 'Small goods usually arrive in 7 to 15 days, bulk raw materials and furniture in 20 to 40 days, and cars in 45 to 60 days. Delivery is free from ${money(AppConfig.freeShippingFrom)}.',
          actions: const [('Track my orders', _Go.orders)]);
    }
    if (_has(text, ['pay on delivery', 'payment', 'pay'])) {
      return const _Msg(false, 'You pay when your goods arrive. Every order has buyer protection: if it doesn\'t arrive or doesn\'t match, the money goes back to your wallet.');
    }
    if (_has(text, ['business', 'wholesale', 'bulk'])) {
      return _Msg(false, 'Tap Business at the top of Home. You\'ll get wholesale prices from ${AppConfig.bulkMinQty} pieces, your own agent and your logo on the goods. It\'s free.');
    }
    if (_has(text, ['my order', 'track', 'where is', 'status'])) return _localReply(raw);
    return const _Msg(false, 'I can help with orders, delivery, payment and your account. For anything else, a person on our team will sort it out.', actions: human);
  }

  Future<_Msg> _localReply(String raw) async {
    final s = context.read<AppState>();
    final text = raw.toLowerCase().trim();
    final first = s.user?.firstName ?? 'there';

    if (RegExp(r'^(hi|hello|hey|good (morning|afternoon|evening)|how far|sup)\b').hasMatch(text) && text.split(' ').length <= 4) {
      return _Msg(false, 'Hello $first! I can find products, work out bulk prices, check your orders and give business tips. What are you working on?');
    }

    if (_has(text, ['my order', 'track', 'where is', 'status of', 'delivered yet'])) {
      try {
        final open = (await s.myOrders()).where((o) => o.status != 'Cancelled').toList();
        if (open.isEmpty) return const _Msg(false, 'You have no open orders yet. When you buy something, I can tell you exactly where it is.');
        final o = open.first;
        return _Msg(false, 'Your latest order ${o.id} is at "${o.status}".${open.length > 1 ? ' You have ${open.length} open orders.' : ''}', actions: const [('Open tracker', _Go.orders)]);
      } catch (_) {
        return const _Msg(false, 'I couldn\'t reach your orders just now. Try again in a moment.', actions: [('My orders', _Go.orders)]);
      }
    }

    // "How much for 50 chargers", "price of 20 power banks"
    final qtyMatch = RegExp(r'(\d[\d,]*)\s*(pieces|pcs|units|cartons|bags|drums)?\s*(of\s+)?([a-z].*)').firstMatch(text);
    if (qtyMatch != null && _has(text, ['how much', 'price', 'cost', 'quote', 'total'])) {
      final qty = int.tryParse(qtyMatch.group(1)!.replaceAll(',', '')) ?? 0;
      final found = _search(s, qtyMatch.group(4)!, 1);
      if (found.isNotEmpty && qty > 0) {
        final p = found.first;
        final min = p.businessMin;
        final off = s.bulkOff(qty);
        final unit = (p.price * (1 - off / 100)).round();
        final sell = (unit * 1.4).round();
        return _Msg(
          false,
          '$qty × ${p.name}: ${money(unit)} each, ${money(unit * qty)} in total${unit < p.price ? ' ($off% off retail)' : ''}.'
          '${qty < min ? ' Note: the business minimum for this item is $min.' : ''}'
          '${qty > p.stock ? ' We have ${p.stock} in stock right now.' : ''}'
          ' If you sell at about ${money(sell)} each, you make roughly ${money((sell - unit) * (qty < p.stock ? qty : p.stock))}.',
          products: [p],
        );
      }
    }

    if (_has(text, ['what should i sell', 'what to sell', 'what should i stock', 'recommend', 'best sell', 'trending', 'what sells', 'ideas'])) {
      final type = AppConfig.businessTypes.where((t) => t.id == s.user?.business?['type']).firstOrNull;
      return _Msg(false, 'Based on ${type != null ? 'your ${type.name.toLowerCase()}' : 'your business'}, what you have saved and what sells fastest, these are good places to start:',
          products: s.recommended.take(4).toList());
    }

    for (final tip in _tips()) {
      if (_has(text, tip.keys)) return _Msg(false, tip.text, actions: tip.actions);
    }

    final found = _search(s, text);
    if (found.isNotEmpty) return _Msg(false, 'Here\'s what I found. Prices shown are your wholesale prices.', products: found);

    return const _Msg(
      false,
      'I\'m not sure about that one yet. Try asking me to find a product ("find power banks"), price an order ("how much for 50 chargers"), check your order, or for tips on pricing, marketing or branding. For anything else, your agent can help.',
      actions: [('Chat with my agent', _Go.agent)],
    );
  }

  List<({List<String> keys, String text, List<(String, _Go)> actions})> _tips() {
    final tiers = AppConfig.bulkTiers.map((t) => '${t.from}+ pieces: ${t.off}% off').join(', ');
    return [
      (
        keys: ['margin', 'profit', 'markup', 'how much should i sell', 'selling price', 'price my', 'pricing'],
        text: 'A simple rule: add your landing cost (product + delivery) and add 30% to 60% on top. Fast-moving items like chargers can take a smaller markup because they sell quickly; branded or custom items can take more. Check what others sell for on WhatsApp and Jumia, then price just under the big names. The profit calculator on Build my brand does the sums for you.',
        actions: [('Open profit calculator', _Go.brand)],
      ),
      (
        keys: ['market', 'advert', 'promote', 'customers', 'instagram', 'tiktok', 'facebook', 'whatsapp status', 'more sales', 'sell more'],
        text: 'What works best for small shops in Nigeria:\n1. Post your products on WhatsApp status every day, with the price.\n2. Short videos on TikTok and Instagram Reels showing the product in use.\n3. Ask happy customers to send a photo or voice note you can share.\n4. Offer a small discount for buying 2 or more.\n5. Put your logo on your goods so people remember where they bought it.',
        actions: [],
      ),
      (
        keys: ['brand', 'logo', 'name my', 'business name', 'tagline'],
        text: 'A strong brand is a short name people can say easily, one or two colours you use everywhere, and a logo that still looks good small. Build my brand can make a simple logo from your name, suggest taglines, and save it so you can print it on the products you buy.',
        actions: [('Build my brand', _Go.brand)],
      ),
      (
        keys: ['start', 'begin', 'capital', 'small money', 'new business', 'beginner', 'how do i start'],
        text: 'Start small and learn fast: pick one product type you understand, order around the minimum (${AppConfig.bulkMinQty} pieces), sell them, then reorder what moved fastest. Keep your first stock money separate from your personal money, and reinvest the profit for the first few rounds. Your agent can help you choose what to stock first.',
        actions: [('Chat with my agent', _Go.agent)],
      ),
      (
        keys: ['customs', 'clearing', 'duty', 'shipping', 'how long', 'delivery time', 'port', 'arrive'],
        text: 'We handle shipping and customs clearing for you. Small goods usually arrive in 7 to 15 days, bulk raw materials and furniture in 20 to 40 days, and cars in 45 to 60 days. You can follow every step, from the factory to your door, on the order tracker.',
        actions: [('Track my goods', _Go.orders)],
      ),
      (
        keys: ['customis', 'customiz', 'print', 'my logo on', 'branding on', 'packaging'],
        text: 'Open any product, tap "Customise with your logo", upload your logo (or use the one in your brand kit), place it, pick a colour and say how many pieces to brand. The design goes with your order to the factory.',
        actions: [('Browse products', _Go.products)],
      ),
      (
        keys: ['used', 'tokunbo', 'second hand', 'fairly used'],
        text: 'Used (Tokunbo) items are inspected before they ship, and each one is marked "Used" on its page.',
        actions: [('See products', _Go.used)],
      ),
      (
        keys: ['rmb', 'yuan', 'usdt', 'crypto', 'exchange', 'pay supplier', 'alipay', 'wechat'],
        text: 'You can change naira to yuan (RMB), USDT and other crypto in your wallet, then send it to Alipay, WeChat, a bank or a crypto address. Handy for paying your own suppliers in China.',
        actions: [('Open exchange', _Go.exchange)],
      ),
      (
        keys: ['wholesale', 'bulk', 'discount', 'minimum', 'moq'],
        text: 'As a business buyer the minimum is ${AppConfig.bulkMinQty} pieces of each item (fewer for big items like cars). Discounts: $tiers. The price on every product already shows your wholesale price.',
        actions: [],
      ),
      (
        keys: ['agent', 'human', 'person', 'talk to someone', 'call'],
        text: 'Your agent is a real person on our team. Message them from the business hub; it opens WhatsApp.',
        actions: [('Chat with my agent', _Go.agent)],
      ),
    ];
  }

  // ---------------------------------------------------------------- screen

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final bizName = s.user?.business?['name'] ?? 'your business';
    final first = s.user?.firstName ?? 'there';
    final intro = widget.support
        ? _Msg(false, 'Hi $first! I\'m ${AppConfig.appName} customer care. Ask me about an order, delivery, payment or your account. If it needs a person, I\'ll pass you to one.',
            actions: const [('Talk to a person', _Go.human)])
        : _Msg(false,
            'Hi $first! I\'m your ${AppConfig.appName} business assistant. Ask me to find products, work out bulk prices and profit, check your orders, or for tips on pricing, marketing and branding.');
    final suggestions = widget.support ? _supportSuggestions : _businessSuggestions;
    final all = [intro, ..._history];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Brand.redSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(widget.support ? Icons.support_agent : Icons.smart_toy_outlined, color: Brand.red600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.support ? 'Customer care' : 'Business assistant'),
              Text(widget.support ? 'Answers in seconds, a person when you need one.' : 'Helps $bizName find products, price orders and grow.',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w400)),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: all.length + (_typing ? 1 : 0),
            itemBuilder: (_, i) => i == all.length ? const _Typing() : FadeIn(child: _Bubble(msg: all[i], onGo: _go)),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final q in suggestions)
              Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(q), onPressed: () => _ask(q))),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  decoration: InputDecoration(hintText: widget.support ? 'How can we help?' : 'Ask anything about your business', counterText: '', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                style: IconButton.styleFrom(backgroundColor: Brand.red, minimumSize: const Size(46, 46)),
                onPressed: () => _ask(_input.text),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final ValueChanged<_Go> onGo;
  const _Bubble({required this.msg, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Align(
      alignment: msg.me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: msg.me ? Brand.red : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.me ? 18 : 4),
            bottomRight: Radius.circular(msg.me ? 4 : 18),
          ),
          boxShadow: msg.me ? null : Brand.shadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg.text, style: TextStyle(color: msg.me ? Colors.white : Brand.text, height: 1.45)),
          for (final p in msg.products)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Pressable(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productId: p.id))),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Brand.bg, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    SizedBox(width: 44, height: 44, child: NetImage(p.img, placeholder: CategoryBubble(category: s.category(p.cat), size: 40, showPhoto: false))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${money(s.unitPrice(p, p.businessMin))} each · min. ${p.businessMin}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: Brand.muted),
                  ]),
                ),
              ),
            ),
          if (msg.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                for (final (label, go) in msg.actions)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(backgroundColor: Brand.redSoft, foregroundColor: Brand.red600, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: () => onGo(go),
                    child: Text(label),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: Brand.shadow),
          child: const SizedBox(width: 34, height: 10, child: LinearProgressIndicator(color: Brand.red, backgroundColor: Brand.redSoft)),
        ),
      );
}
