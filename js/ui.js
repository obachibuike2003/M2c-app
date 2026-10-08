// Shared page chrome and helpers used by every page.

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

const ICONS = {
  search: '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
  cart: '<circle cx="9" cy="20" r="1.5"/><circle cx="18" cy="20" r="1.5"/><path d="M2 3h3l2.7 12.4a1 1 0 0 0 1 .8h9.1a1 1 0 0 0 1-.8L20.5 7H6.1"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  wallet: '<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v10a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-8a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16.5" cy="14" r="1"/>',
  home: '<path d="m3 11 9-8 9 8"/><path d="M5 10v10h14V10"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
  swap: '<path d="M7 4 3 8l4 4"/><path d="M3 8h14"/><path d="m17 12 4 4-4 4"/><path d="M21 16H7"/>',
  box: '<path d="m3 8 9-5 9 5v8l-9 5-9-5z"/><path d="m3 8 9 5 9-5"/><path d="M12 13v8"/>',
  truck: '<path d="M2 6h11v10H2z"/><path d="M13 9h5l3 3v4h-8z"/><circle cx="6.5" cy="17.5" r="1.8"/><circle cx="17" cy="17.5" r="1.8"/>',
  shield: '<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
  star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z" fill="currentColor"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  minus: '<path d="M5 12h14"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  trash: '<path d="M4 7h16"/><path d="M9 7V4h6v3"/><path d="M6 7l1 13h10l1-13"/>',
  check: '<path d="m5 12 5 5 9-10"/>',
  chevron: '<path d="m9 6 6 6-6 6"/>',
  arrowRight: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  arrowLeft: '<path d="M19 12H5M11 6l-6 6 6 6"/>',
  zap: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
  headset: '<path d="M4 14v-2a8 8 0 0 1 16 0v2"/><rect x="2.5" y="13" width="4" height="6" rx="1.5"/><rect x="17.5" y="13" width="4" height="6" rx="1.5"/><path d="M20 19a4 4 0 0 1-4 3h-3"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  logout: '<path d="M10 4H5v16h5"/><path d="M14 8l4 4-4 4"/><path d="M18 12H9"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9 7 7M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/>',
  phone: '<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>',
  monitor: '<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>',
  shirt: '<path d="M8 3 3 6l2 4 2-1v11h10V9l2 1 2-4-5-3a4 4 0 0 1-8 0z"/>',
  cup: '<path d="M5 8h12v5a6 6 0 0 1-12 0z"/><path d="M17 9h2a2 2 0 0 1 0 4h-2"/><path d="M4 21h14"/>',
  droplet: '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>',
  bag: '<path d="M5 8h14l1 13H4z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
  smile: '<circle cx="12" cy="12" r="9"/><path d="M8.5 14a4 4 0 0 0 7 0"/><path d="M9 9.5v.01M15 9.5v.01"/>'
};

function icon(name, size = 20, cls = '') {
  return `<svg class="ic ${cls}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ''}</svg>`;
}

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function money(amount, code = 'NGN') {
  const n = Number(amount) || 0;
  if (code === 'NGN') return '₦' + n.toLocaleString('en-NG', { maximumFractionDigits: 2 });
  if (code === 'CNY') return '¥' + n.toLocaleString('en-NG', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const dp = (Store.rates()[code] || { dp: 2 }).dp;
  return n.toLocaleString('en-NG', { maximumFractionDigits: dp }) + ' ' + code;
}

const toYuan = (naira) => naira / Store.rates().CNY.buy;
const categoryOf = (id) => CATEGORIES.find((c) => c.id === id) || CATEGORIES[0];
const discountOf = (p) => (p.oldPrice > p.price ? Math.round((1 - p.price / p.oldPrice) * 100) : 0);
const compact = (n) => (n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, '') + 'k' : String(n));
const reducedMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

function formatDate(ts) {
  return new Date(ts).toLocaleString('en-NG', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

// Only allow image sources that are safe to put in an <img>: our own assets, web links and uploads.
function safeImage(src) {
  return /^(assets\/|https?:\/\/|data:image\/)/i.test(src || '') ? src : '';
}

// Product picture, or a tinted placeholder with the category icon when there is no image yet.
function productThumb(p, iconSize = 56) {
  const img = safeImage(p.img);
  if (img) return `<img src="${esc(img)}" alt="${esc(p.name)}" loading="lazy">`;
  const cat = categoryOf(p.cat);
  return `<span class="thumb-ph" style="--h:${cat.hue}">${icon(cat.icon, iconSize)}</span>`;
}

// i staggers the scroll-reveal; deal adds the "claimed" bar used in flash deals.
function productCard(p, i = 0, deal = false) {
  const off = discountOf(p);
  const out = p.stock < 1;
  const href = `product.html?id=${encodeURIComponent(p.id)}`;
  const claimed = 35 + ((p.sold || 0) % 58);
  return `
    <article class="product reveal" style="--i:${i % 5}">
      <div class="thumb-wrap">
        <a class="thumb" href="${href}" tabindex="-1" aria-hidden="true">
          ${productThumb(p)}
          ${off ? `<span class="badge badge-off">-${off}%</span>` : ''}
        </a>
        <button class="add-fab" type="button" data-add="${esc(p.id)}" aria-label="${out ? 'Out of stock' : 'Add ' + esc(p.name) + ' to cart'}" ${out ? 'disabled' : ''}>${icon(out ? 'x' : 'plus', 20)}</button>
      </div>
      <div class="product-body">
        <a class="product-link" href="${href}"><h3 class="product-name">${esc(p.name)}</h3></a>
        <div class="price-row">
          <span class="price">${money(p.price)}</span>
          ${off ? `<span class="old-price">${money(p.oldPrice)}</span>` : ''}
        </div>
        ${deal ? `
          <div class="claimed">
            <div class="claimed-bar" style="--w:${claimed}%"><i></i></div>
            <span>${claimed}% claimed</span>
          </div>` : `
          <div class="product-meta">
            <span class="rating">${icon('star', 14)} ${p.rating ? p.rating.toFixed(1) : 'New'}</span>
            <span>${compact(p.sold || 0)} sold</span>
          </div>`}
      </div>
    </article>`;
}

function statusPill(status) {
  const tone = { Processing: 'amber', processing: 'amber', Shipped: 'blue', Delivered: 'green', completed: 'green', Cancelled: 'grey', rejected: 'grey' }[status] || 'grey';
  return `<span class="pill pill-${tone}">${esc(status)}</span>`;
}

function toast(message, tone = 'ok') {
  let wrap = $('.toast-wrap');
  if (!wrap) {
    wrap = document.createElement('div');
    wrap.className = 'toast-wrap';
    wrap.setAttribute('role', 'status');
    wrap.setAttribute('aria-live', 'polite');
    document.body.appendChild(wrap);
  }
  const el = document.createElement('div');
  el.className = 'toast toast-' + tone;
  el.innerHTML = icon(tone === 'error' ? 'x' : 'check', 22) + `<span>${esc(message)}</span>`;
  wrap.appendChild(el);
  setTimeout(() => el.remove(), 3200);
}

// Opens a modal built on the native <dialog>. Returns the element; it removes itself when closed.
function openDialog(title, bodyHtml) {
  const dlg = document.createElement('dialog');
  dlg.className = 'modal';
  dlg.innerHTML = `
    <div class="modal-head">
      <h2>${esc(title)}</h2>
      <button class="icon-btn" type="button" data-close aria-label="Close">${icon('x')}</button>
    </div>
    <div class="modal-body">${bodyHtml}</div>`;
  document.body.appendChild(dlg);
  dlg.addEventListener('click', (e) => {
    if (e.target === dlg || e.target.closest('[data-close]')) dlg.close();
  });
  dlg.addEventListener('close', () => dlg.remove());
  dlg.showModal();
  return dlg;
}

function showError(el, message) {
  el.textContent = message || '';
  el.hidden = !message;
}

function updateCartCount(bump = false) {
  const n = Store.cartCount();
  $$('[data-cart-count]').forEach((el) => {
    el.textContent = n;
    el.hidden = n === 0;
    if (bump) {
      el.classList.remove('bump');
      void el.offsetWidth; // restart the animation
      el.classList.add('bump');
    }
  });
}

// Fades and slides .reveal elements in as they scroll into view. Call again after rendering new ones.
let revealObserver;
function observeReveals(root = document) {
  const items = $$('.reveal:not(.in)', root);
  if (!('IntersectionObserver' in window) || reducedMotion()) {
    items.forEach((el) => el.classList.add('in'));
    return;
  }
  revealObserver = revealObserver || new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('in');
      revealObserver.unobserve(entry.target);
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });
  items.forEach((el) => revealObserver.observe(el));
}

// Counts a number up or down to its new value.
function animateNumber(el, to, format, duration = 700) {
  const from = el._value || 0;
  el._value = to;
  cancelAnimationFrame(el._raf);
  if (reducedMotion() || from === to) {
    el.textContent = format(to);
    return;
  }
  const start = performance.now();
  const step = (now) => {
    const t = Math.min(1, (now - start) / duration);
    const eased = 1 - (1 - t) ** 3;
    el.textContent = format(from + (to - from) * eased);
    if (t < 1) el._raf = requestAnimationFrame(step);
    else el.textContent = format(to);
  };
  el._raf = requestAnimationFrame(step);
}

// Sends a copy of the product picture flying into the cart icon.
function flyToCart(img) {
  const target = $$('[data-cart-target]').find((el) => el.getBoundingClientRect().width > 0);
  if (!img || !target || !img.animate || reducedMotion()) return updateCartCount(true);
  const a = img.getBoundingClientRect();
  const b = target.getBoundingClientRect();
  const clone = img.cloneNode();
  clone.className = 'fly';
  clone.removeAttribute('loading');
  Object.assign(clone.style, { left: a.left + 'px', top: a.top + 'px', width: a.width + 'px', height: a.height + 'px' });
  document.body.appendChild(clone);
  const dx = b.left + b.width / 2 - (a.left + a.width / 2);
  const dy = b.top + b.height / 2 - (a.top + a.height / 2);
  clone.animate([
    { transform: 'translate(0, 0) scale(1)', opacity: 1 },
    { transform: `translate(${dx * 0.5}px, ${dy * 0.5 - 60}px) scale(.5)`, opacity: 0.95, offset: 0.55 },
    { transform: `translate(${dx}px, ${dy}px) scale(.08)`, opacity: 0.2 }
  ], { duration: 800, easing: 'cubic-bezier(.4, 0, .2, 1)' }).onfinish = () => {
    clone.remove();
    updateCartCount(true);
  };
}

// Sends signed-out visitors to the login page and brings them back afterwards.
function requireLogin() {
  const user = Store.currentUser();
  if (user) return user;
  const here = location.pathname.split('/').pop() + location.search;
  location.replace('login.html?next=' + encodeURIComponent(here));
  return null;
}

function logoHtml(extraClass = '') {
  return `<a class="logo ${extraClass}" href="index.html"><span class="logo-mark" aria-hidden="true">${esc(APP.name.charAt(0))}</span>${esc(APP.name)}</a>`;
}

function mountChrome(active) {
  document.title = `${document.title} | ${APP.name}`;
  const user = Store.currentUser();
  const rates = Store.rates();
  const q = new URLSearchParams(location.search).get('q') || '';
  const link = (href, ic, label, key, mobile = false) =>
    `<a href="${href}" class="hdr-link${mobile ? '' : ' hide-m'}${active === key ? ' is-active' : ''}"${active === key ? ' aria-current="page"' : ''}>${icon(ic, 22)}<span>${label}</span></a>`;

  const tickerItems = [
    `<span class="ticker-item">${icon('truck', 16)} Free delivery above <b>${money(APP.freeShippingFrom)}</b></span>`,
    ...Object.keys(rates).map((c) => `<span class="ticker-item">1 ${c} <b>${money(rates[c].buy)}</b></span>`),
    `<span class="ticker-item">${icon('shield', 16)} Buyer protection on every order</span>`
  ].join('');

  $('#site-header').outerHTML = `
    <div class="ticker" aria-label="Rates and offers">
      <div class="ticker-track">
        <div class="ticker-group">${tickerItems}</div>
        <div class="ticker-group" aria-hidden="true">${tickerItems}</div>
      </div>
    </div>
    <header class="hdr" id="site-header">
      <div class="container hdr-row">
        ${logoHtml()}
        <form class="search" action="products.html" role="search">
          <input type="search" name="q" value="${esc(q)}" placeholder="Search phones, fashion, gadgets" aria-label="Search products">
          <button type="submit" aria-label="Search">${icon('search')}</button>
        </form>
        <nav class="hdr-actions" aria-label="Main">
          ${link('exchange.html', 'swap', 'Exchange', 'exchange')}
          ${link('wallet.html', 'wallet', 'Wallet', 'wallet')}
          ${link('orders.html', 'box', 'Orders', 'orders')}
          ${user && user.role === 'admin' ? link('admin.html', 'settings', 'Admin', 'admin') : ''}
          ${user
            ? link('wallet.html', 'user', esc(user.name.split(' ')[0]), 'account', true)
            : link('login.html', 'user', 'Sign in', 'login', true)}
          <a href="cart.html" class="hdr-link${active === 'cart' ? ' is-active' : ''}" data-cart-target>
            ${icon('cart', 22)}<span>Cart</span><b class="count" data-cart-count hidden>0</b>
          </a>
        </nav>
      </div>
      <nav class="cat-strip" aria-label="Categories">
        <div class="container cat-strip-in">
          <a href="products.html">All products</a>
          ${CATEGORIES.map((c) => `<a href="products.html?cat=${c.id}">${esc(c.name)}</a>`).join('')}
        </div>
      </nav>
    </header>`;

  const tab = (href, ic, label, key, extra = '', attrs = '') =>
    `<a href="${href}" class="${active === key ? 'is-active' : ''}"${active === key ? ' aria-current="page"' : ''} ${attrs}>${icon(ic, 22)}<span>${label}</span>${extra}</a>`;

  $('#site-footer').innerHTML = `
    <footer class="ftr">
      <div class="container ftr-grid">
        <div>
          ${logoHtml('logo-light')}
          <p>${esc(APP.tagline)} Goods sourced from China, plus naira exchange for yuan and crypto in one wallet.</p>
        </div>
        <div>
          <h3>Shop</h3>
          <a href="products.html">All products</a>
          <a href="cart.html">Cart</a>
          <a href="orders.html">My orders</a>
        </div>
        <div>
          <h3>Exchange</h3>
          <a href="exchange.html?asset=CNY">Naira to RMB</a>
          <a href="exchange.html?asset=USDT">Naira to USDT</a>
          <a href="wallet.html">Wallet</a>
        </div>
        <div>
          <h3>Help</h3>
          <a href="mailto:${esc(APP.supportEmail)}">${esc(APP.supportEmail)}</a>
          <a href="login.html">Sign in</a>
        </div>
      </div>
      <div class="container ftr-note">Demo build: payments, balances and exchange rates are simulated and stored only in this browser.</div>
    </footer>
    <nav class="bottom-nav" aria-label="Quick">
      ${tab('index.html', 'home', 'Home', 'home')}
      ${tab('products.html', 'grid', 'Shop', 'shop')}
      ${tab('exchange.html', 'swap', 'Exchange', 'exchange')}
      ${tab('cart.html', 'cart', 'Cart', 'cart', '<b class="count" data-cart-count hidden>0</b>', 'data-cart-target')}
      ${tab(user ? 'wallet.html' : 'login.html', 'user', user ? 'Wallet' : 'Sign in', user ? 'wallet' : 'login')}
    </nav>`;

  updateCartCount();

  // Header gets a shadow once the page scrolls under it.
  const header = $('#site-header');
  const onScroll = () => header.classList.toggle('is-stuck', scrollY > 40);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // Any "Add to cart" button on any page.
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-add]');
    if (!btn) return;
    const res = Store.addToCart(btn.dataset.add, 1);
    if (!res.ok) return toast(res.error, 'error');
    toast('Added to cart');
    const card = btn.closest('.product');
    flyToCart(card && $('.thumb img', card));
  });

  // Page scripts render after this runs, so wait for them before wiring up reveals.
  document.addEventListener('DOMContentLoaded', () => observeReveals());
}
