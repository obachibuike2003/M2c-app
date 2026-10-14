// Data layer. Everything is kept in the browser's localStorage, so this is a demo:
// no real money moves and data stays on this device. Swap these functions for
// API calls when a backend is added.

const Store = (() => {
  const PREFIX = 'mp_';

  function read(key, fallback) {
    try {
      const raw = localStorage.getItem(PREFIX + key);
      return raw === null ? fallback : JSON.parse(raw);
    } catch (e) {
      return fallback;
    }
  }

  function write(key, value) {
    try {
      localStorage.setItem(PREFIX + key, JSON.stringify(value));
      return true;
    } catch (e) {
      return false;
    }
  }

  const uid = (p) => p + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  const round = (n, dp) => Math.round((n + Number.EPSILON) * 10 ** dp) / 10 ** dp;
  const floor = (n, dp) => Math.floor(n * 10 ** dp + 1e-9) / 10 ** dp;
  const dpOf = (code) => (code === 'NGN' ? 2 : (rates()[code] || { dp: 2 }).dp);
  const FULL = 'The browser storage is full. Try a smaller image.';

  function emptyBalances() {
    const b = { NGN: 0 };
    Object.keys(SEED_RATES).forEach((c) => { b[c] = 0; });
    return b;
  }

  // Older saved orders used a plain status; map them onto the tracker steps.
  const OLD_STATUS_STAGE = { Processing: 0, Shipped: 3, Delivered: 7 };

  function seed() {
    // A new seed catalogue replaces the stored one (older product ids and photos no longer exist).
    if (read('seedVersion') !== SEED_VERSION) {
      write('products', SEED_PRODUCTS);
      write('categories', SEED_CATEGORIES);
      write('seedVersion', SEED_VERSION);
    }
    if (!read('categories')) write('categories', SEED_CATEGORIES);
    if (!read('agents')) write('agents', SEED_AGENTS);
    if (!read('bulk')) write('bulk', SEED_BULK);
    if (!read('rates')) write('rates', SEED_RATES);
    if (!read('users')) {
      write('users', [{ id: 'u_admin', ...DEMO_ADMIN, balances: emptyBalances(), createdAt: Date.now() }]);
    }
    const list = read('orders', []);
    if (list.some((o) => o.stage === undefined)) {
      list.forEach((o) => {
        if (o.stage !== undefined) return;
        o.stage = OLD_STATUS_STAGE[o.status] ?? 0;
        o.tracking = [{ stage: o.stage, at: o.createdAt }];
        if (o.status !== 'Cancelled') o.status = TRACK_STAGES[o.stage].name;
      });
      write('orders', list);
    }
    const c = read('cart', []);
    if (c.some((l) => !l.key)) write('cart', c.map((l) => ({ key: l.id, ...l })));
  }

  function resetDemo() {
    Object.keys(localStorage)
      .filter((k) => k.startsWith(PREFIX))
      .forEach((k) => localStorage.removeItem(k));
    seed();
  }

  // Small flags for this browser only (for example: has the intro been shown).
  const flag = (key) => read('flag_' + key, false);
  const setFlag = (key, value = true) => write('flag_' + key, value);

  /* ---------- users ---------- */

  const users = () => read('users', []);
  const saveUsers = (list) => write('users', list);

  function currentUser() {
    const id = read('session', null);
    return id ? users().find((u) => u.id === id) || null : null;
  }

  function signup({ name, email, phone, whatsapp, password }) {
    email = String(email).trim().toLowerCase();
    const list = users();
    if (list.some((u) => u.email === email)) return { ok: false, error: 'An account with this email already exists.' };
    const user = {
      id: uid('u_'), name: String(name).trim(), email, phone: String(phone).trim(),
      whatsapp: String(whatsapp || phone).trim(), password,
      role: 'customer', mode: 'personal', balances: emptyBalances(), favs: [], createdAt: Date.now()
    };
    list.push(user);
    saveUsers(list);
    write('session', user.id);
    return { ok: true, user };
  }

  function login(email, password) {
    email = String(email).trim().toLowerCase();
    const user = users().find((u) => u.email === email && u.password === password);
    if (!user) return { ok: false, error: 'Wrong email or password.' };
    write('session', user.id);
    return { ok: true, user };
  }

  function logout() {
    try { localStorage.removeItem(PREFIX + 'session'); } catch (e) { /* ignore */ }
  }

  function updateUser(id, patch) {
    const list = users();
    const user = list.find((u) => u.id === id);
    if (!user) return null;
    Object.assign(user, patch);
    return saveUsers(list) ? user : null;
  }

  function adjustBalance(userId, code, delta) {
    const list = users();
    const user = list.find((u) => u.id === userId);
    if (!user) return false;
    user.balances[code] = round((user.balances[code] || 0) + delta, dpOf(code));
    saveUsers(list);
    return true;
  }

  /* ---------- personal / business mode ---------- */

  const mode = () => (currentUser() || {}).mode === 'business' ? 'business' : 'personal';
  const isBusiness = () => mode() === 'business';

  // Switching to business needs a business name and type; an agent is assigned the first time.
  function setMode(next, business) {
    const user = currentUser();
    if (!user) return { ok: false, error: 'Please sign in first.' };
    if (next === 'personal') {
      updateUser(user.id, { mode: 'personal' });
      return { ok: true };
    }
    const biz = business || user.business;
    if (!biz || !String(biz.name || '').trim()) return { ok: false, error: 'Enter your business name.' };
    if (!BUSINESS_TYPES.some((t) => t.id === biz.type)) return { ok: false, error: 'Pick your type of business.' };
    const patch = { mode: 'business', business: { name: String(biz.name).trim(), type: biz.type } };
    if (!user.agentId || !agent(user.agentId)) patch.agentId = pickAgent();
    updateUser(user.id, patch);
    if (patch.agentId) {
      const a = agent(patch.agentId);
      if (a) sendMessage(user.id, 'agent', `Hi ${user.name.split(' ')[0]}, I'm ${a.name}, your Easy2buy agent. I'll help you with bulk orders, custom branding and delivery. Ask me anything here.`);
    }
    return { ok: true };
  }

  const businessType = (id) => BUSINESS_TYPES.find((t) => t.id === id) || null;

  // Selfie for identity checks. The admin marks it verified or rejected.
  function submitVerification(selfie) {
    const user = currentUser();
    if (!user) return { ok: false, error: 'Please sign in first.' };
    return updateUser(user.id, { verify: { status: 'pending', selfie, at: Date.now() } })
      ? { ok: true } : { ok: false, error: FULL };
  }

  function setVerification(userId, status) {
    const user = users().find((u) => u.id === userId);
    if (!user || !user.verify) return false;
    // Drop the photo once it has been checked; it is not needed any more.
    updateUser(userId, { verify: { status, at: Date.now() } });
    return true;
  }

  function saveBrand(brand) {
    const user = currentUser();
    if (!user) return { ok: false, error: 'Please sign in first.' };
    return updateUser(user.id, { brand: { ...(user.brand || {}), ...brand } })
      ? { ok: true } : { ok: false, error: FULL };
  }

  /* ---------- favourites ---------- */

  function toggleFav(productId) {
    const user = currentUser();
    if (!user) return null;
    const favs = new Set(user.favs || []);
    const on = !favs.has(productId);
    if (on) favs.add(productId); else favs.delete(productId);
    updateUser(user.id, { favs: [...favs] });
    return on;
  }

  const isFav = (productId) => ((currentUser() || {}).favs || []).includes(productId);

  /* ---------- agents and chat ---------- */

  const agents = () => read('agents', []);
  const agent = (id) => agents().find((a) => a.id === id) || null;

  // The agent looking after the fewest business customers.
  function pickAgent() {
    const list = agents();
    if (!list.length) return null;
    const load = (a) => users().filter((u) => u.agentId === a.id).length;
    return list.reduce((best, a) => (load(a) < load(best) ? a : best)).id;
  }

  function saveAgent(data) {
    const list = agents();
    if (data.id) {
      const a = list.find((x) => x.id === data.id);
      if (!a) return { ok: false, error: 'Agent not found.' };
      Object.assign(a, data);
    } else {
      list.push({ ...data, id: uid('a_') });
    }
    return write('agents', list) ? { ok: true } : { ok: false, error: FULL };
  }

  // Customers of a removed agent move to whoever is least busy.
  function deleteAgent(id) {
    write('agents', agents().filter((a) => a.id !== id));
    const list = users();
    list.filter((u) => u.agentId === id).forEach((u) => { u.agentId = null; });
    saveUsers(list);
    list.filter((u) => u.agentId === null && u.mode === 'business').forEach((u) => updateUser(u.id, { agentId: pickAgent() }));
  }

  const messages = () => read('messages', []);
  const threadOf = (userId) => messages().filter((m) => m.userId === userId);

  function sendMessage(userId, from, text) {
    text = String(text || '').trim().slice(0, 1000);
    if (!text) return false;
    const list = messages();
    list.push({ id: uid('m_'), userId, from, text, at: Date.now(), seen: false });
    return write('messages', list);
  }

  // Marks the other side's messages in a thread as seen.
  function markSeen(userId, reader) {
    const list = messages();
    let changed = false;
    list.forEach((m) => {
      if (m.userId === userId && m.from !== reader && !m.seen) { m.seen = true; changed = true; }
    });
    if (changed) write('messages', list);
  }

  const unseenFor = (userId, reader) => threadOf(userId).filter((m) => m.from !== reader && !m.seen).length;

  /* ---------- transactions ---------- */

  const txns = () => read('txns', []);

  function addTxn(t) {
    const list = txns();
    const txn = { id: uid('t_'), status: 'completed', createdAt: Date.now(), ...t };
    list.unshift(txn);
    write('txns', list);
    return txn;
  }

  const userTxns = (userId) => txns().filter((t) => t.userId === userId);

  function fundWallet(amount) {
    const user = currentUser();
    amount = Number(amount);
    if (!user) return { ok: false, error: 'Please sign in first.' };
    if (!(amount >= 100)) return { ok: false, error: 'Enter at least ₦100.' };
    if (amount > 10000000) return { ok: false, error: 'The demo limit is ₦10,000,000 per top-up.' };
    adjustBalance(user.id, 'NGN', amount);
    addTxn({ userId: user.id, type: 'fund', desc: 'Wallet top-up (demo)', amount, currency: 'NGN' });
    return { ok: true };
  }

  // Send money out of the wallet: naira to a bank, yuan to Alipay/WeChat/bank, crypto to an address.
  // The amount is held straight away and waits for the admin to complete or reject it.
  function requestPayout(code, amount, destination) {
    const user = currentUser();
    amount = Number(amount);
    if (!user) return { ok: false, error: 'Please sign in first.' };
    if (!(amount > 0)) return { ok: false, error: 'Enter an amount.' };
    if (amount > (user.balances[code] || 0)) return { ok: false, error: `You do not have enough ${code}.` };
    if (!String(destination).trim()) return { ok: false, error: 'Enter where the money should go.' };
    adjustBalance(user.id, code, -amount);
    addTxn({
      userId: user.id, type: 'payout', desc: `Send to ${String(destination).trim()}`,
      amount: -amount, currency: code, status: 'processing'
    });
    return { ok: true };
  }

  function resolvePayout(txnId, approve) {
    const list = txns();
    const txn = list.find((t) => t.id === txnId);
    if (!txn || txn.type !== 'payout' || txn.status !== 'processing') return false;
    txn.status = approve ? 'completed' : 'rejected';
    write('txns', list);
    if (!approve) {
      adjustBalance(txn.userId, txn.currency, -txn.amount);
      addTxn({ userId: txn.userId, type: 'refund', desc: 'Rejected send-out returned', amount: -txn.amount, currency: txn.currency });
    }
    return true;
  }

  /* ---------- exchange ---------- */

  const rates = () => read('rates', SEED_RATES);

  function saveRates(next) {
    return write('rates', next);
  }

  // One side of every exchange is naira.
  function quote(from, to, amount) {
    const r = rates();
    amount = Number(amount) || 0;
    if (from === 'NGN' && r[to]) return floor(amount / r[to].buy, r[to].dp);
    if (to === 'NGN' && r[from]) return floor(amount * r[from].sell, 2);
    return 0;
  }

  function exchange(from, to, amount) {
    const user = currentUser();
    amount = Number(amount);
    if (!user) return { ok: false, error: 'Please sign in first.' };
    if (!(amount > 0)) return { ok: false, error: 'Enter an amount.' };
    if (amount > (user.balances[from] || 0)) return { ok: false, error: `You do not have enough ${from} in your wallet.` };
    const received = quote(from, to, amount);
    if (!(received > 0)) return { ok: false, error: 'That amount is too small to exchange.' };
    adjustBalance(user.id, from, -amount);
    adjustBalance(user.id, to, received);
    addTxn({ userId: user.id, type: 'exchange', desc: `Exchanged ${from} to ${to}`, amount: -amount, currency: from, gotAmount: received, gotCurrency: to });
    return { ok: true, received };
  }

  /* ---------- categories ---------- */

  const categories = () => read('categories', SEED_CATEGORIES);

  function saveCategory(data) {
    const list = categories();
    const name = String(data.name || '').trim();
    if (!name) return { ok: false, error: 'Enter a category name.' };
    if (list.some((c) => c.name.toLowerCase() === name.toLowerCase() && c.id !== data.id)) {
      return { ok: false, error: 'A category with this name already exists.' };
    }
    if (data.id) {
      const c = list.find((x) => x.id === data.id);
      if (!c) return { ok: false, error: 'Category not found.' };
      Object.assign(c, data, { name });
    } else {
      const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 24) || 'cat';
      const id = list.some((c) => c.id === slug) ? slug + '-' + Math.random().toString(36).slice(2, 5) : slug;
      list.push({ icon: 'box', hue: 200, img: '', ...data, name, id });
    }
    return write('categories', list) ? { ok: true } : { ok: false, error: FULL };
  }

  function deleteCategory(id) {
    const count = products().filter((p) => p.cat === id).length;
    if (count) return { ok: false, error: `Move or delete the ${count} product${count === 1 ? '' : 's'} in this category first.` };
    write('categories', categories().filter((c) => c.id !== id));
    return { ok: true };
  }

  /* ---------- products ---------- */

  const products = () => read('products', []);
  const product = (id) => products().find((p) => p.id === id) || null;

  function saveProduct(data) {
    const list = products();
    if (data.id) {
      const i = list.findIndex((p) => p.id === data.id);
      if (i === -1) return { ok: false, error: 'Product not found.' };
      list[i] = { ...list[i], ...data };
    } else {
      list.unshift({ rating: 0, sold: 0, ship: '7-15', ...data, id: uid('p_') });
    }
    return write('products', list) ? { ok: true } : { ok: false, error: FULL };
  }

  function deleteProduct(id) {
    write('products', products().filter((p) => p.id !== id));
    write('cart', cart().filter((c) => c.id !== id));
  }

  // Products scored for one user: their business type, favourites and past orders,
  // with best-sellers breaking ties. Used for "Recommended for you".
  function recommend(user, limit = 15) {
    const list = products().filter((p) => p.stock > 0);
    if (!user) return list.sort((a, b) => (b.sold || 0) - (a.sold || 0)).slice(0, limit);
    const weight = {};
    const add = (cat, w) => { weight[cat] = (weight[cat] || 0) + w; };
    const type = user.mode === 'business' && user.business ? businessType(user.business.type) : null;
    if (type) type.cats.forEach((c, i) => add(c, 6 - i * 1.5));
    const all = products();
    (user.favs || []).forEach((id) => { const p = all.find((x) => x.id === id); if (p) add(p.cat, 2); });
    userOrders(user.id).forEach((o) => o.items.forEach((it) => { const p = all.find((x) => x.id === it.id); if (p) add(p.cat, 1); }));
    const score = (p) => (weight[p.cat] || 0) + Math.log10((p.sold || 0) + 10) / 2;
    // Pick one at a time, making each extra item from the same category count a little less,
    // so the list mixes categories instead of filling up with one.
    const picked = [];
    const used = {};
    const pool = [...list];
    while (picked.length < limit && pool.length) {
      let best = 0;
      pool.forEach((p, i) => {
        if (score(p) - (used[p.cat] || 0) * 1.6 > score(pool[best]) - (used[pool[best].cat] || 0) * 1.6) best = i;
      });
      const [p] = pool.splice(best, 1);
      used[p.cat] = (used[p.cat] || 0) + 1;
      picked.push(p);
    }
    return picked;
  }

  /* ---------- bulk pricing ---------- */

  const bulk = () => read('bulk', SEED_BULK);
  const saveBulk = (rules) => write('bulk', rules);
  const bulkMin = (p) => Math.max(1, Number(p.bulkMin) || bulk().minQty);

  // Percent off for this many pieces of one item (business mode only).
  function bulkOff(qty) {
    return bulk().tiers
      .filter((t) => qty >= t.from)
      .reduce((best, t) => Math.max(best, t.off), 0);
  }

  function unitPrice(p, qty, m = mode()) {
    return m === 'business' ? Math.round(p.price * (1 - bulkOff(qty) / 100)) : p.price;
  }

  /* ---------- cart ---------- */
  // Each line: { key, id, qty, custom? }. Lines with a custom design get their own key,
  // so the same product can be in the cart plain and customised.

  const cart = () => read('cart', []);

  function addToCart(id, qty = 1, custom = null) {
    const p = product(id);
    if (!p || p.stock < 1) return { ok: false, error: 'This item is out of stock.' };
    const list = cart();
    const line = custom ? null : list.find((c) => c.key === id);
    const inCart = list.filter((c) => c.id === id).reduce((n, c) => n + c.qty, 0);
    if (inCart + qty > p.stock) return { ok: false, error: `Only ${p.stock} left in stock.` };
    if (line) line.qty += qty;
    else list.push({ key: custom ? uid(id + '~') : id, id, qty, ...(custom ? { custom } : {}) });
    return write('cart', list) ? { ok: true } : { ok: false, error: FULL };
  }

  function setCartQty(key, qty) {
    let list = cart();
    const line = list.find((c) => c.key === key);
    const p = line && product(line.id);
    if (qty < 1 || !p) list = list.filter((c) => c.key !== key);
    else {
      const others = list.filter((c) => c.id === line.id && c.key !== key).reduce((n, c) => n + c.qty, 0);
      line.qty = Math.min(qty, p.stock - others);
      if (line.custom) line.custom.qty = Math.min(line.custom.qty, line.qty);
    }
    write('cart', list);
  }

  const cartCount = () => cart().reduce((n, c) => n + c.qty, 0);

  // Cart lines joined with their products and priced for the current mode.
  // Lines whose product was deleted are dropped.
  function cartLines() {
    const all = products();
    const m = mode();
    return cart()
      .map((c) => {
        const p = all.find((x) => x.id === c.id);
        if (!p) return null;
        const unit = unitPrice(p, c.qty, m);
        const min = m === 'business' ? bulkMin(p) : 1;
        return { key: c.key, product: p, qty: c.qty, custom: c.custom || null, unit, total: unit * c.qty, min, short: c.qty < min };
      })
      .filter(Boolean);
  }

  function cartTotals() {
    const lines = cartLines();
    const subtotal = lines.reduce((n, l) => n + l.total, 0);
    const full = lines.reduce((n, l) => n + l.product.price * l.qty, 0);
    const shipping = subtotal === 0 || subtotal >= APP.freeShippingFrom ? 0 : APP.shippingFee;
    return { subtotal, bulkSaving: full - subtotal, shipping, total: subtotal + shipping };
  }

  /* ---------- orders ---------- */

  const orders = () => read('orders', []);
  const userOrders = (userId) => orders().filter((o) => o.userId === userId);
  const order = (id) => orders().find((o) => o.id === id) || null;

  function placeOrder({ address, pay }) {
    const user = currentUser();
    if (!user) return { ok: false, error: 'Please sign in first.' };
    const lines = cartLines();
    if (!lines.length) return { ok: false, error: 'Your cart is empty.' };
    const short = lines.find((l) => l.short);
    if (short) return { ok: false, error: `Business orders need at least ${short.min} of "${short.product.name}".` };
    const stockOf = {};
    lines.forEach((l) => { stockOf[l.product.id] = (stockOf[l.product.id] || 0) + l.qty; });
    const over = lines.find((l) => stockOf[l.product.id] > l.product.stock);
    if (over) return { ok: false, error: `Only ${over.product.stock} left of "${over.product.name}".` };
    const totals = cartTotals();
    if (pay === 'wallet' && user.balances.NGN < totals.total) {
      return { ok: false, error: 'Your naira wallet balance is not enough for this order.' };
    }

    const now = Date.now();
    const placed = {
      id: 'ORD-' + Math.random().toString(36).slice(2, 8).toUpperCase(),
      userId: user.id,
      mode: mode(),
      items: lines.map((l) => ({ id: l.product.id, name: l.product.name, price: l.unit, qty: l.qty, ...(l.custom ? { custom: l.custom } : {}) })),
      ...totals, address, pay,
      stage: 0, status: TRACK_STAGES[0].name, tracking: [{ stage: 0, at: now }], createdAt: now
    };

    const list = orders();
    list.unshift(placed);
    if (!write('orders', list)) return { ok: false, error: FULL };

    if (pay === 'wallet') {
      adjustBalance(user.id, 'NGN', -totals.total);
      addTxn({ userId: user.id, type: 'purchase', desc: `Order ${placed.id}`, amount: -totals.total, currency: 'NGN' });
    }

    const all = products();
    lines.forEach((l) => {
      const p = all.find((x) => x.id === l.product.id);
      p.stock -= l.qty;
      p.sold = (p.sold || 0) + l.qty;
    });
    write('products', all);
    write('cart', []);
    updateUser(user.id, { address });
    return { ok: true, order: placed };
  }

  // Moves an order to a tracker step and records when it happened.
  function setOrderStage(orderId, stage) {
    const list = orders();
    const o = list.find((x) => x.id === orderId);
    stage = Number(stage);
    if (!o || o.status === 'Cancelled' || !TRACK_STAGES[stage] || o.stage === stage) return false;
    o.stage = stage;
    o.status = TRACK_STAGES[stage].name;
    // Steps that were skipped over are stamped with the same time.
    o.tracking = (o.tracking || []).filter((t) => t.stage < stage);
    const from = o.tracking.length ? o.tracking[o.tracking.length - 1].stage + 1 : 0;
    for (let s = from; s <= stage; s++) o.tracking.push({ stage: s, at: Date.now() });
    return write('orders', list);
  }

  // Cancelling puts the stock back and refunds wallet payments.
  function cancelOrder(orderId) {
    const list = orders();
    const o = list.find((x) => x.id === orderId);
    if (!o || o.status === 'Cancelled') return false;
    const all = products();
    o.items.forEach((it) => {
      const p = all.find((x) => x.id === it.id);
      if (p) { p.stock += it.qty; p.sold = Math.max(0, (p.sold || 0) - it.qty); }
    });
    write('products', all);
    if (o.pay === 'wallet') {
      adjustBalance(o.userId, 'NGN', o.total);
      addTxn({ userId: o.userId, type: 'refund', desc: `Refund for ${o.id}`, amount: o.total, currency: 'NGN' });
    }
    o.status = 'Cancelled';
    o.cancelledAt = Date.now();
    return write('orders', list);
  }

  // Customers can cancel until the goods have been bought from the supplier.
  const canCancel = (o) => o.status !== 'Cancelled' && o.stage < 2;

  function cancelMyOrder(orderId) {
    const user = currentUser();
    const o = order(orderId);
    if (!user || !o || o.userId !== user.id || !canCancel(o)) return false;
    return cancelOrder(orderId);
  }

  seed();

  return {
    resetDemo, flag, setFlag, users, currentUser, signup, login, logout, updateUser,
    mode, isBusiness, setMode, businessType, submitVerification, setVerification, saveBrand,
    toggleFav, isFav,
    agents, agent, saveAgent, deleteAgent, pickAgent, messages, threadOf, sendMessage, markSeen, unseenFor,
    txns, userTxns, fundWallet, requestPayout, resolvePayout,
    rates, saveRates, quote, exchange,
    categories, saveCategory, deleteCategory,
    products, product, saveProduct, deleteProduct, recommend,
    bulk, saveBulk, bulkMin, bulkOff, unitPrice,
    cart, addToCart, setCartQty, cartCount, cartLines, cartTotals,
    orders, userOrders, order, placeOrder, setOrderStage, cancelOrder, canCancel, cancelMyOrder
  };
})();
