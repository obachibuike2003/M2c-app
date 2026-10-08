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

  function emptyBalances() {
    const b = { NGN: 0 };
    Object.keys(SEED_RATES).forEach((c) => { b[c] = 0; });
    return b;
  }

  function seed() {
    // A new seed catalogue replaces the stored one (older product ids and photos no longer exist).
    if (read('seedVersion') !== SEED_VERSION) {
      write('products', SEED_PRODUCTS);
      write('seedVersion', SEED_VERSION);
    }
    if (!read('rates')) write('rates', SEED_RATES);
    if (!read('users')) {
      write('users', [{ id: 'u_admin', ...DEMO_ADMIN, balances: emptyBalances(), createdAt: Date.now() }]);
    }
  }

  function resetDemo() {
    Object.keys(localStorage)
      .filter((k) => k.startsWith(PREFIX))
      .forEach((k) => localStorage.removeItem(k));
    seed();
  }

  /* ---------- users ---------- */

  const users = () => read('users', []);
  const saveUsers = (list) => write('users', list);

  function currentUser() {
    const id = read('session', null);
    return id ? users().find((u) => u.id === id) || null : null;
  }

  function signup({ name, email, phone, password }) {
    email = String(email).trim().toLowerCase();
    const list = users();
    if (list.some((u) => u.email === email)) return { ok: false, error: 'An account with this email already exists.' };
    const user = {
      id: uid('u_'), name: String(name).trim(), email, phone: String(phone).trim(), password,
      role: 'customer', balances: emptyBalances(), createdAt: Date.now()
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
    saveUsers(list);
    return user;
  }

  function adjustBalance(userId, code, delta) {
    const list = users();
    const user = list.find((u) => u.id === userId);
    if (!user) return false;
    user.balances[code] = round((user.balances[code] || 0) + delta, dpOf(code));
    saveUsers(list);
    return true;
  }

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
    return write('products', list)
      ? { ok: true }
      : { ok: false, error: 'Could not save. The browser storage is full, try a smaller image.' };
  }

  function deleteProduct(id) {
    write('products', products().filter((p) => p.id !== id));
    write('cart', cart().filter((c) => c.id !== id));
  }

  /* ---------- cart ---------- */

  const cart = () => read('cart', []);

  function addToCart(id, qty = 1) {
    const p = product(id);
    if (!p || p.stock < 1) return { ok: false, error: 'This item is out of stock.' };
    const list = cart();
    const line = list.find((c) => c.id === id);
    const want = (line ? line.qty : 0) + qty;
    if (want > p.stock) return { ok: false, error: `Only ${p.stock} left in stock.` };
    if (line) line.qty = want; else list.push({ id, qty });
    write('cart', list);
    return { ok: true };
  }

  function setCartQty(id, qty) {
    const p = product(id);
    let list = cart();
    if (qty < 1 || !p) list = list.filter((c) => c.id !== id);
    else list.forEach((c) => { if (c.id === id) c.qty = Math.min(qty, p.stock); });
    write('cart', list);
  }

  const cartCount = () => cart().reduce((n, c) => n + c.qty, 0);

  // Cart lines joined with their products; lines whose product was deleted are dropped.
  function cartLines() {
    const all = products();
    return cart()
      .map((c) => ({ product: all.find((p) => p.id === c.id), qty: c.qty }))
      .filter((l) => l.product);
  }

  function cartTotals() {
    const subtotal = cartLines().reduce((n, l) => n + l.product.price * l.qty, 0);
    const shipping = subtotal === 0 || subtotal >= APP.freeShippingFrom ? 0 : APP.shippingFee;
    return { subtotal, shipping, total: subtotal + shipping };
  }

  /* ---------- orders ---------- */

  const orders = () => read('orders', []);
  const userOrders = (userId) => orders().filter((o) => o.userId === userId);

  function placeOrder({ address, pay }) {
    const user = currentUser();
    if (!user) return { ok: false, error: 'Please sign in first.' };
    const lines = cartLines();
    if (!lines.length) return { ok: false, error: 'Your cart is empty.' };
    const short = lines.find((l) => l.qty > l.product.stock);
    if (short) return { ok: false, error: `Only ${short.product.stock} left of "${short.product.name}".` };
    const totals = cartTotals();
    if (pay === 'wallet' && user.balances.NGN < totals.total) {
      return { ok: false, error: 'Your naira wallet balance is not enough for this order.' };
    }

    const order = {
      id: 'ORD-' + Math.random().toString(36).slice(2, 8).toUpperCase(),
      userId: user.id,
      items: lines.map((l) => ({ id: l.product.id, name: l.product.name, price: l.product.price, qty: l.qty })),
      ...totals, address, pay, status: 'Processing', createdAt: Date.now()
    };

    if (pay === 'wallet') {
      adjustBalance(user.id, 'NGN', -totals.total);
      addTxn({ userId: user.id, type: 'purchase', desc: `Order ${order.id}`, amount: -totals.total, currency: 'NGN' });
    }

    const all = products();
    lines.forEach((l) => {
      const p = all.find((x) => x.id === l.product.id);
      p.stock -= l.qty;
      p.sold = (p.sold || 0) + l.qty;
    });
    write('products', all);

    const list = orders();
    list.unshift(order);
    write('orders', list);
    write('cart', []);
    updateUser(user.id, { address });
    return { ok: true, order };
  }

  // Cancelling puts the stock back and refunds wallet payments.
  function setOrderStatus(orderId, status) {
    const list = orders();
    const order = list.find((o) => o.id === orderId);
    if (!order || order.status === status || order.status === 'Cancelled') return false;
    if (status === 'Cancelled') {
      const all = products();
      order.items.forEach((it) => {
        const p = all.find((x) => x.id === it.id);
        if (p) { p.stock += it.qty; p.sold = Math.max(0, (p.sold || 0) - it.qty); }
      });
      write('products', all);
      if (order.pay === 'wallet') {
        adjustBalance(order.userId, 'NGN', order.total);
        addTxn({ userId: order.userId, type: 'refund', desc: `Refund for ${order.id}`, amount: order.total, currency: 'NGN' });
      }
    }
    order.status = status;
    write('orders', list);
    return true;
  }

  function cancelMyOrder(orderId) {
    const user = currentUser();
    const order = orders().find((o) => o.id === orderId);
    if (!user || !order || order.userId !== user.id || order.status !== 'Processing') return false;
    return setOrderStatus(orderId, 'Cancelled');
  }

  seed();

  return {
    resetDemo, users, currentUser, signup, login, logout, updateUser,
    txns, userTxns, fundWallet, requestPayout, resolvePayout,
    rates, saveRates, quote, exchange,
    products, product, saveProduct, deleteProduct,
    cart, addToCart, setCartQty, cartCount, cartLines, cartTotals,
    orders, userOrders, placeOrder, setOrderStatus, cancelMyOrder
  };
})();
