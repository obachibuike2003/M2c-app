// The business assistant's and customer care's brain.
// Signed-in people get answers from OpenAI through the backend (POST /api/assistant/chat).
// If the backend has no AI key, it answers from the product catalogue, the user's orders and
// built-in tips. Customer care hands anything serious to a person on WhatsApp.

const Assistant = (() => {
  const STOP = new Set('a an the i me my we our you your for of to in on and or is are be can do does how what which where who want need looking find show get buy sell some any with please pls abeg about have has it this that there their them from at by per pieces piece pcs units unit much many cost price prices'.split(' '));

  const words = (s) => String(s).toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((w) => w.length > 1 && !STOP.has(w));
  const has = (text, list) => list.some((k) => text.includes(k));

  // Products whose name, category or description match the words in the message.
  function search(text, limit = 4) {
    const terms = words(text);
    if (!terms.length) return [];
    return Store.products()
      .map((p) => {
        const name = p.name.toLowerCase();
        const cat = categoryOf(p.cat).name.toLowerCase();
        const desc = (p.desc || '').toLowerCase();
        const stem = (t) => t.replace(/(es|s)$/, '');
        const score = terms.reduce((n, t) => n + (name.includes(stem(t)) ? 3 : 0) + (cat.includes(stem(t)) ? 2 : 0) + (desc.includes(stem(t)) ? 1 : 0), 0);
        return { p, score };
      })
      .filter((x) => x.score > 0)
      .sort((a, b) => b.score - a.score || (b.p.sold || 0) - (a.p.sold || 0))
      .slice(0, limit)
      .map((x) => x.p);
  }

  const TIPS = [
    {
      keys: ['margin', 'profit', 'markup', 'how much should i sell', 'selling price', 'price my', 'pricing'],
      text: 'A simple rule: add your landing cost (product + delivery) and add 30% to 60% on top. Fast-moving items like chargers can take a smaller markup because they sell quickly; branded or custom items can take more. Check what others sell for on WhatsApp and Jumia, then price just under the big names. The profit calculator on Build my brand does the sums for you.',
      actions: [['Open profit calculator', 'brand.html#calc']]
    },
    {
      keys: ['market', 'advert', 'promote', 'customers', 'instagram', 'tiktok', 'facebook', 'whatsapp status', 'more sales', 'sell more'],
      text: 'What works best for small shops in Nigeria:\n1. Post your products on WhatsApp status every day, with the price.\n2. Short videos on TikTok and Instagram Reels showing the product in use.\n3. Ask happy customers to send a photo or voice note you can share.\n4. Offer a small discount for buying 2 or more.\n5. Put your logo on your goods so people remember where they bought it.'
    },
    {
      keys: ['brand', 'logo', 'name my', 'business name', 'tagline'],
      text: 'A strong brand is a short name people can say easily, one or two colours you use everywhere, and a logo that still looks good small. Build my brand can make a simple logo from your name, suggest taglines, and save it so you can print it on the products you buy.',
      actions: [['Build my brand', 'brand.html']]
    },
    {
      keys: ['start', 'begin', 'capital', 'small money', 'new business', 'beginner', 'how do i start'],
      text: 'Start small and learn fast: pick one product type you understand, order around the minimum (10 pieces), sell them, then reorder what moved fastest. Keep your first stock money separate from your personal money, and reinvest the profit for the first few rounds. Your agent can help you choose what to stock first.',
      actions: [['Chat with my agent', 'business.html#agent']]
    },
    {
      keys: ['customs', 'clearing', 'duty', 'shipping', 'how long', 'delivery time', 'port', 'arrive'],
      text: 'We handle shipping and customs clearing for you. Small goods usually arrive in 7 to 15 days, bulk raw materials and furniture in 20 to 40 days, and cars in 45 to 60 days. You can follow every step, from the factory to your door, on the order tracker.',
      actions: [['Track my goods', 'orders.html']]
    },
    {
      keys: ['customis', 'customiz', 'print', 'my logo on', 'branding on', 'packaging'],
      text: 'Open any product, tap "Customise with your logo", upload your logo (or use the one in your brand kit), place it, pick a colour and say how many pieces to brand. The design goes with your order to the factory.',
      actions: [['Browse products', 'products.html']]
    },
    {
      keys: ['used', 'tokunbo', 'second hand', 'fairly used'],
      text: 'Used (Tokunbo) items are inspected before they ship, and each one is marked "Used" on its page.',
      actions: [['See used products', 'products.html?condition=used']]
    },
    {
      keys: ['rmb', 'yuan', 'usdt', 'crypto', 'exchange', 'pay supplier', 'alipay', 'wechat'],
      text: 'You can change naira to yuan (RMB), USDT and other crypto in your wallet, then send it to Alipay, WeChat, a bank or a crypto address. Handy for paying your own suppliers in China.',
      actions: [['Open exchange', 'exchange.html']]
    },
    {
      keys: ['wholesale', 'bulk', 'discount', 'minimum', 'moq'],
      text: () => {
        const r = Store.bulk();
        const tiers = r.tiers.filter((t) => t.off > 0).map((t) => `${t.from}+ pieces: ${t.off}% off`).join(', ');
        return `As a business buyer the minimum is ${r.minQty} pieces of each item (fewer for big items like cars). ${tiers ? 'Discounts: ' + tiers + '.' : ''} The price on every product already shows your wholesale price.`;
      }
    },
    {
      keys: ['agent', 'human', 'person', 'talk to someone', 'call'],
      text: 'Your agent is a real person on our team. Chat with them in the business hub or on WhatsApp.',
      actions: [['Chat with my agent', 'business.html#agent']]
    }
  ];

  function localReply(raw) {
    const text = String(raw).toLowerCase().trim();
    const user = Store.currentUser();
    const first = user.name.split(' ')[0];

    if (/^(hi|hello|hey|good (morning|afternoon|evening)|how far|sup)\b/.test(text) && text.split(' ').length <= 4) {
      return { text: `Hello ${first}! I can find products, work out bulk prices, check your orders and give business tips. What are you working on?` };
    }

    // Order status
    if (has(text, ['my order', 'track', 'where is', 'status of', 'delivered yet'])) {
      const list = Store.userOrders(user.id).filter((o) => o.status !== 'Cancelled');
      if (!list.length) return { text: 'You have no open orders yet. When you buy something, I can tell you exactly where it is.' };
      const o = list[0];
      return {
        text: `Your latest order ${o.id} is at "${o.status}": ${TRACK_STAGES[o.stage].text}${list.length > 1 ? ` You have ${list.length} open orders.` : ''}`,
        actions: [['Open tracker', 'track.html?id=' + encodeURIComponent(o.id)]]
      };
    }

    // "How much for 50 chargers", "price of 20 power banks"
    const qtyMatch = text.match(/(\d[\d,]*)\s*(pieces|pcs|units|cartons|bags|drums)?\s*(of\s+)?([a-z].*)/);
    if (qtyMatch && has(text, ['how much', 'price', 'cost', 'quote', 'total'])) {
      const qty = Number(qtyMatch[1].replace(/,/g, ''));
      const [p] = search(qtyMatch[4], 1);
      if (p && qty > 0) {
        const min = Store.bulkMin(p);
        const unit = Store.unitPrice(p, qty, 'business');
        const sell = Math.round(unit * 1.4);
        return {
          text: `${qty} × ${p.name}: ${money(unit)} each, ${money(unit * qty)} in total${unit < p.price ? ` (${Store.bulkOff(qty)}% off retail)` : ''}.${qty < min ? ` Note: the business minimum for this item is ${min}.` : ''}${qty > p.stock ? ` We have ${p.stock} in stock right now.` : ''} If you sell at about ${money(sell)} each, you make roughly ${money((sell - unit) * Math.min(qty, p.stock))}.`,
          products: [p.id]
        };
      }
    }

    // What to stock
    if (has(text, ['what should i sell', 'what to sell', 'what should i stock', 'recommend', 'best sell', 'trending', 'what sells', 'ideas'])) {
      const recs = Store.recommend(user, 4);
      const type = user.business ? Store.businessType(user.business.type) : null;
      return { text: `Based on ${type ? 'your ' + type.name.toLowerCase() : 'your business'}, what you have saved and what sells fastest, these are good places to start:`, products: recs.map((p) => p.id) };
    }

    const tip = TIPS.find((t) => has(text, t.keys));
    if (tip) return { text: typeof tip.text === 'function' ? tip.text() : tip.text, actions: tip.actions };

    const found = search(text);
    if (found.length) return { text: `Here's what I found. Prices shown are your wholesale prices.`, products: found.map((p) => p.id) };

    return {
      text: "I'm not sure about that one yet. Try asking me to find a product (\"find power banks\"), price an order (\"how much for 50 chargers\"), check your order, or for tips on pricing, marketing or branding. For anything else, your agent can help.",
      actions: [['Chat with my agent', 'business.html#agent']]
    };
  }

  // A real person on WhatsApp: a business buyer's own agent, or Eazy2buy support.
  function humanLink(lastQuestion) {
    const user = Store.currentUser();
    const a = user && user.mode === 'business' && user.agentId ? Store.agent(user.agentId) : null;
    const who = user ? ` This is ${user.name}${user.business ? ` (${user.business.name})` : ''}.` : '';
    const asked = lastQuestion ? ` I asked: "${lastQuestion}"` : '';
    return a ? waLink(a.whatsapp, `Hi ${a.name},${who}${asked}`) : waLink(APP.supportWhatsapp, `Hi ${APP.name},${who}${asked}`);
  }

  function supportReply(raw, lastQuestion) {
    const text = String(raw).toLowerCase();
    const human = [['Talk to a person', humanLink(lastQuestion)]];
    if (has(text, ['refund', 'damaged', 'broken', 'missing', 'wrong item', 'not what i ordered', 'complain', 'cancel', 'scam', 'money', 'charged', 'paid twice'])) {
      return { text: "Sorry about that. This needs one of our team, so I'm passing you to a person. Tap below and send your order number.", actions: human };
    }
    if (has(text, ['delivery', 'how long', 'arrive', 'shipping'])) {
      return { text: `Small goods usually arrive in 7 to 15 days, bulk raw materials and furniture in 20 to 40 days, and cars in 45 to 60 days. Delivery is free from ${money(APP.freeShippingFrom)}.`, actions: [['Track my orders', 'orders.html']] };
    }
    if (has(text, ['business', 'wholesale', 'bulk'])) {
      return { text: `Choose Business at the top of the page. You get wholesale prices from ${Store.bulk().minQty} pieces, your own agent and your logo on the goods. It's free.` };
    }
    if (has(text, ['my order', 'track', 'where is', 'status'])) return localReply(raw);
    return { text: 'I can help with orders, delivery, payment and your account. For anything else, a person on our team will sort it out.', actions: human };
  }

  let aiOff = false;

  // mode: 'business' (the assistant page) or 'support' (customer care).
  async function reply(text, history, mode = 'business') {
    if (!aiOff && Store.currentUser()) {
      try {
        const data = await Store.api('POST', '/api/assistant/chat', { mode, messages: [...history, { role: 'user', content: text }] });
        return {
          text: String(data.reply || ''),
          products: data.products || [],
          actions: data.handoff ? [['Talk to a person', humanLink(text)]] : []
        };
      } catch (e) {
        if (e.code === 'ai_off' || e.status === 401) aiOff = true; // use the built-in answers from now on
        else return { text: e.message, actions: [['Talk to a person', humanLink(text)]] };
      }
    }
    return mode === 'support' ? supportReply(text, text) : localReply(text);
  }

  // Fresh tagline ideas from the AI, or null when it's off.
  async function taglines(name) {
    if (aiOff || !Store.currentUser()) return null;
    try {
      const data = await Store.api('POST', '/api/assistant/chat', { mode: 'brand', name });
      return (data.taglines || []).length ? data.taglines : null;
    } catch (e) {
      if (e.code === 'ai_off') aiOff = true;
      return null;
    }
  }

  return { reply, taglines };
})();
