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
  smile: '<circle cx="12" cy="12" r="9"/><path d="M8.5 14a4 4 0 0 0 7 0"/><path d="M9 9.5v.01M15 9.5v.01"/>',
  factory: '<path d="M3 21V10l6 4V10l6 4V5h4l2 16z"/><path d="M7 17h2M12 17h2"/>',
  flask: '<path d="M9 3h6M10 3v6L4.5 18.5A1.7 1.7 0 0 0 6 21h12a1.7 1.7 0 0 0 1.5-2.5L14 9V3"/><path d="M7.5 15h9"/>',
  cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5" rx=".5"/><path d="M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3M19 9h3M19 15h3"/>',
  sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
  sofa: '<path d="M5 11V8a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v3"/><path d="M3 13a2 2 0 0 1 4 0v2h10v-2a2 2 0 0 1 4 0v5H3z"/><path d="M5 18v2M19 18v2"/>',
  car: '<path d="M5 17h14v-4.5l-2-5A2 2 0 0 0 15.2 6H8.8A2 2 0 0 0 7 7.5l-2 5z"/><path d="M5 12.5h14"/><circle cx="8" cy="17" r="1.8"/><circle cx="16" cy="17" r="1.8"/>',
  heart: '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
  briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/><path d="M3 13h18"/>',
  chat: '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/>',
  bot: '<rect x="4" y="8" width="16" height="12" rx="3"/><path d="M12 4v4M9 13v1M15 13v1M9.5 17h5"/><circle cx="12" cy="3.5" r="1"/>',
  palette: '<path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.5-.8 1.5-1.5 0-1.2-1-1.6-1-2.6 0-.9.7-1.4 1.6-1.4H16a5 5 0 0 0 5-5c0-4.1-4-7.5-9-7.5z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="15" cy="7.5" r="1"/>',
  upload: '<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/>',
  play: '<circle cx="12" cy="12" r="9"/><path d="m10 8.5 5 3.5-5 3.5z" fill="currentColor"/>',
  camera: '<path d="M4 8h3l2-3h6l2 3h3a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z"/><circle cx="12" cy="13.5" r="3.5"/>',
  send: '<path d="M21 3 10 14"/><path d="m21 3-7 18-4-7-7-4z"/>',
  wand: '<path d="m4 20 11-11"/><path d="m13 7 2-2 4 4-2 2z"/><path d="M6 3v3M4.5 4.5h3M19 14v3M17.5 15.5h3"/>',
  whatsapp: '<path d="M20 11.5A8.5 8.5 0 0 1 7.6 19L3 20l1.1-4.4A8.5 8.5 0 1 1 20 11.5z"/><path d="M9 8.5c0 3.5 2.5 6.5 6.5 6.5l1-1.5-2-1-1 1c-1.2-.5-2.3-1.6-2.8-2.8l1-1-1-2z"/>',
  tag: '<path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9z"/><circle cx="7.5" cy="7.5" r="1.5"/>',
  bell: '<path d="M6 10a6 6 0 0 1 12 0c0 4 1.5 5.5 2 6H4c.5-.5 2-2 2-6z"/><path d="M10 19a2 2 0 0 0 4 0"/>',
  copy: '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1"/>',
  type: '<path d="M4 6h16"/><path d="M12 6v14"/>',
  image: '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="m21 16-5-5-4 4-2-2-6 6"/>',
  edit: '<path d="M4 20l4-1 11-11-3-3L5 16z"/><path d="M14 6l3 3"/>',
  layers: '<path d="m12 3 9 5-9 5-9-5z"/><path d="m3 13 9 5 9-5"/>',
  folder: '<path d="M3 7a1 1 0 0 1 1-1h5l2 2h9a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/>',
  store: '<path d="M3 9l1.5-5h15L21 9"/><path d="M4 9v10h16V9"/><path d="M9 19v-5h6v5"/>',
  book: '<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M5 17a3 3 0 0 1 3-3h11"/>'
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
const categories = () => Store.categories();
const categoryOf = (id) => categories().find((c) => c.id === id) || { id, name: 'Other', icon: 'box', hue: 220, img: '' };
// Category picture, or its icon when there is no picture.
const categoryArt = (c, size = 30) => (safeImage(c.img) ? `<img src="${esc(c.img)}" alt="" loading="lazy">` : icon(c.icon || 'box', size));
const discountOf = (p) => (p.oldPrice > p.price ? Math.round((1 - p.price / p.oldPrice) * 100) : 0);
// Branded, pre-made goods (name-brand electronics, vehicles) can't carry a buyer's own logo.
const UNBRANDABLE_NAME = /\b(apple|samsung|huawei|oppo|realme|vivo|lenovo|beats|amazon|nokia|xiaomi|tecno|infinix|sony|jbl|bose|hp|dell|asus|nike|adidas|puma|chrysler|dodge|toyota|honda|ford|hyundai|kia|mercedes|bmw|lexus|jeep|nissan)\b/i;
const isCustomizable = (p) => p.cat !== 'cars' && !UNBRANDABLE_NAME.test(p.name);

// "You may also like": rank by shared words in the name (same brand/kind of item) before
// falling back to same category, so a Beats earphone surfaces other earphones first,
// not just whatever else lives in the broad "Electronics" category.
function relatedTo(p, all, limit = 5) {
  // Generic model-name filler words (Plus, Pro, GT...) match across totally unrelated
  // products, so they're excluded rather than treated as a real similarity signal.
  const STOP = new Set(['plus', 'pro', 'max', 'mini', 'lite', 'series', 'touring', 'sxt', 'gt', 'edition', 'note', 'the', 'and', 'with', 'for']);
  const words = (s) => new Set(String(s).toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length > 2 && !STOP.has(w)));
  const base = words(p.name);
  return all
    .filter((x) => x.id !== p.id)
    .map((x) => ({ x, shared: [...words(x.name)].filter((w) => base.has(w)).length, sameCat: x.cat === p.cat }))
    .filter((e) => e.shared > 0 || e.sameCat)
    .sort((a, b) => (b.shared * 3 + b.sameCat) - (a.shared * 3 + a.sameCat) || (b.x.sold || 0) - (a.x.sold || 0))
    .slice(0, limit)
    .map((e) => e.x);
}
const compact = (n) => (n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, '') + 'k' : String(n));

// The most common strong colour in a logo image, ignoring white, black and see-through pixels.
// Used to match a product's tint to an uploaded logo in the customiser.
function logoColour(img) {
  const c = document.createElement('canvas');
  c.width = c.height = 40;
  const x = c.getContext('2d');
  x.drawImage(img, 0, 0, 40, 40);
  const data = x.getImageData(0, 0, 40, 40).data;
  const buckets = {};
  for (let i = 0; i < data.length; i += 4) {
    const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    if (a < 128 || max - min < 40 || max < 50) continue;
    const key = [r, g, b].map((v) => Math.round(v / 32) * 32).join(',');
    buckets[key] = (buckets[key] || 0) + 1;
  }
  const best = Object.entries(buckets).sort((a, b) => b[1] - a[1])[0];
  if (!best) return '#111216';
  return '#' + best[0].split(',').map((v) => Math.min(255, Number(v)).toString(16).padStart(2, '0')).join('');
}
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
// In business mode the card shows the bulk price at the minimum order.
function productCard(p, i = 0, deal = false) {
  const off = discountOf(p);
  const href = `product.html?id=${encodeURIComponent(p.id)}`;
  const claimed = 35 + ((p.sold || 0) % 58);
  const biz = Store.isBusiness();
  const min = biz ? Store.bulkMin(p) : 1;
  const out = p.stock < min;
  const fav = Store.isFav(p.id);
  const unit = Store.unitPrice(p, min);
  return `
    <article class="product reveal" style="--i:${i % 5}">
      <div class="thumb-wrap">
        <a class="thumb" href="${href}" tabindex="-1" aria-hidden="true">
          ${productThumb(p)}
          ${p.condition === 'used' ? '<span class="badge badge-used">Used</span>' : ''}
        </a>
        <button class="fav-btn" type="button" data-fav="${esc(p.id)}" aria-pressed="${fav}" aria-label="Save ${esc(p.name)}">${icon('heart', 18)}</button>
        ${biz && isCustomizable(p) ? `<button class="customize-fab" type="button" data-customize="${esc(p.id)}" aria-label="Customize ${esc(p.name)} with your brand" title="Customize with your brand">${icon('plus', 20)}</button>` : ''}
        <button class="add-fab" type="button" data-add="${esc(p.id)}" aria-label="${out ? 'Out of stock' : `Add ${biz ? min + ' of ' : ''}${esc(p.name)} to cart`}" ${out ? 'disabled' : ''}>${icon(out ? 'x' : 'plus', 20)}</button>
      </div>
      <div class="product-body">
        <a class="product-link" href="${href}"><h3 class="product-name">${esc(p.name)}</h3></a>
        <div class="price-row">
          <span class="price">${money(unit)}</span>
          ${biz ? `<span class="min-note">${p.stock < min ? 'Not enough for bulk' : `each · min. ${min}`}</span>` : off ? `<span class="old-price">${money(p.oldPrice)}</span>` : ''}
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
  const tone = {
    Processing: 'amber', processing: 'amber', 'Order placed': 'amber', Confirmed: 'amber', pending: 'amber',
    Delivered: 'green', completed: 'green', verified: 'green', Cancelled: 'grey', rejected: 'grey'
  }[status] || (TRACK_STAGES.some((s) => s.name === status) ? 'blue' : 'grey');
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

// For business-only pages: signed-in business users get through, others see a prompt to switch.
function requireBusiness(root) {
  const user = requireLogin();
  if (!user) return null;
  if (user.mode === 'business') return user;
  root.innerHTML = `
    <div class="card empty">
      ${icon('briefcase', 40)}
      <h1>For business owners</h1>
      <p>Switch to business buying to get wholesale prices, your own agent, custom branding and the AI business assistant. It's free.</p>
      <button type="button" class="btn btn-primary" data-switch-mode="business">Switch to business</button>
    </div>`;
  return null;
}

// Reads an image file and shrinks it so it fits in browser storage. Returns a data URL.
function readImage(file, maxSide = 600, type = 'image/jpeg', quality = 0.82) {
  return new Promise((resolve, reject) => {
    if (!file || !/^image\//.test(file.type)) return reject(new Error('Pick an image file (JPG, PNG or WebP).'));
    if (file.size > 8 * 1024 * 1024) return reject(new Error('That image is over 8 MB. Pick a smaller one.'));
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('Could not read that file.'));
    reader.onload = () => {
      // GIFs are kept as they are so they still move.
      if (file.type === 'image/gif') {
        return file.size > 900 * 1024 ? reject(new Error('GIFs must be under 900 KB in this demo.')) : resolve(String(reader.result));
      }
      const img = new Image();
      img.onerror = () => reject(new Error('Could not open that image.'));
      img.onload = () => {
        const scale = Math.min(1, maxSide / Math.max(img.width, img.height));
        const canvas = document.createElement('canvas');
        canvas.width = Math.round(img.width * scale);
        canvas.height = Math.round(img.height * scale);
        canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL(type, quality));
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}

const waLink = (number, text = '') => `https://wa.me/${String(number || '').replace(/\D/g, '')}${text ? '?text=' + encodeURIComponent(text) : ''}`;

// Asks for business details (when missing) and switches the signed-in user's mode.
function switchMode(next) {
  const user = Store.currentUser();
  if (!user) {
    location.href = 'login.html?next=' + encodeURIComponent(location.pathname.split('/').pop() + location.search);
    return;
  }
  const done = (res) => {
    if (!res.ok) return toast(res.error, 'error');
    toast(next === 'business' ? 'You are now buying as a business' : 'You are now buying for yourself');
    setTimeout(() => location.reload(), 500);
  };
  if (next === 'personal' || (user.business && user.business.name)) return done(Store.setMode(next));

  const dlg = openDialog('Buy as a business', `
    <p class="muted">Get wholesale prices (from ${Store.bulk().minQty} pieces), your own agent, custom branding and the AI business assistant. Free to use.</p>
    <form id="biz-form" class="mt-16" novalidate>
      <label class="field"><span>Business name</span><input name="name" required maxlength="80" autocomplete="organization"></label>
      <label class="field"><span>Type of business</span>
        <select name="type" required>
          <option value="">Choose one</option>
          ${BUSINESS_TYPES.map((t) => `<option value="${t.id}">${esc(t.name)}</option>`).join('')}
        </select>
        <small class="hint">We use this to show you the right products.</small>
      </label>
      <p class="form-error" role="alert" hidden></p>
      <div class="form-actions"><button class="btn btn-primary" type="submit">Switch to business</button><button class="btn btn-outline" type="button" data-close>Not now</button></div>
    </form>`);
  $('#biz-form', dlg).addEventListener('submit', (e) => {
    e.preventDefault();
    const d = Object.fromEntries(new FormData(e.target));
    const res = Store.setMode('business', d);
    if (!res.ok) return showError($('.form-error', dlg), res.error);
    dlg.close();
    done(res);
  });
}

// First visit: a short intro to what the app does.
function showcase() {
  if (Store.flag('showcase')) return;
  const slides = [
    ['bag', 'Shop China, pay in naira', 'Phones, fashion, furniture, cars and more, bought straight from China and delivered to your door.'],
    ['briefcase', 'Buying for your business?', `Switch to business for wholesale prices from ${Store.bulk().minQty} pieces, your own agent, and your logo on the goods.`],
    ['truck', 'Track every step', 'Follow your order from the factory to your door, and pay from one naira wallet.']
  ];
  let i = 0;
  const dlg = document.createElement('dialog');
  dlg.className = 'modal showcase';
  document.body.appendChild(dlg);
  const close = () => { Store.setFlag('showcase'); dlg.close(); };
  function render() {
    const [ic, title, text] = slides[i];
    const last = i === slides.length - 1;
    dlg.innerHTML = `
      <div class="showcase-art">${icon(ic, 54)}</div>
      <div class="modal-body">
        <span class="kicker">Welcome to ${esc(APP.name)}</span>
        <h2>${title}</h2>
        <p class="muted mt-12">${text}</p>
        <div class="showcase-dots" aria-hidden="true">${slides.map((_, n) => `<i${n === i ? ' class="on"' : ''}></i>`).join('')}</div>
        <div class="form-actions">
          ${last
            ? `<a class="btn btn-primary" href="login.html" data-go>${Store.currentUser() ? 'Start shopping' : 'Create account'}</a><button class="btn btn-outline" type="button" data-skip>Just browse</button>`
            : `<button class="btn btn-primary" type="button" data-next>Next ${icon('arrowRight', 18)}</button><button class="btn btn-outline" type="button" data-skip>Skip</button>`}
        </div>
      </div>`;
  }
  dlg.addEventListener('click', (e) => {
    if (e.target.closest('[data-next]')) { i++; render(); }
    if (e.target.closest('[data-skip]')) close();
    if (e.target.closest('[data-go]')) Store.setFlag('showcase');
  });
  dlg.addEventListener('cancel', () => Store.setFlag('showcase'));
  dlg.addEventListener('close', () => dlg.remove());
  render();
  dlg.showModal();
}

function logoHtml(extraClass = '') {
  return `<a class="logo ${extraClass}" href="index.html"><span class="logo-mark" aria-hidden="true">${esc(APP.name.charAt(0))}</span>${esc(APP.name)}</a>`;
}

function mountChrome(active) {
  document.title = `${document.title} | ${APP.name}`;
  const user = Store.currentUser();
  const biz = user && user.mode === 'business';
  const rates = Store.rates();
  const q = new URLSearchParams(location.search).get('q') || '';
  const urlCat = new URLSearchParams(location.search).get('cat') || '';
  const searchCat = active === 'shop' && categories().some((c) => c.id === urlCat) ? urlCat : '';
  const unseen = biz ? Store.unseenFor(user.id, 'user') : 0;
  const link = (href, ic, label, key, mobile = false, extra = '') =>
    `<a href="${href}" class="hdr-link${mobile ? ' hide-s' : ' hide-m'}${active === key ? ' is-active' : ''}"${active === key ? ' aria-current="page"' : ''}>${icon(ic, 22)}<span>${label}</span>${extra}</a>`;

  const tickerItems = [
    `<span class="ticker-item">${icon('truck', 16)} Free delivery above <b>${money(APP.freeShippingFrom)}</b></span>`,
    `<span class="ticker-item">${icon('briefcase', 16)} Business buyers: wholesale from <b>${Store.bulk().minQty} pieces</b></span>`,
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
    <header class="hdr${biz ? ' is-biz' : ''}" id="site-header">
      <div class="container hdr-row">
        ${logoHtml()}
        <div class="mode-switch" role="group" aria-label="Buying as">
          <button type="button" data-switch-mode="personal" aria-pressed="${!biz}">Personal</button>
          <button type="button" data-switch-mode="business" aria-pressed="${!!biz}">Business</button>
        </div>
        ${active === 'home' || active === 'shop' ? `
        <form class="search" action="products.html" role="search">
          ${searchCat ? `<input type="hidden" name="cat" value="${esc(searchCat)}">` : ''}
          <input type="search" name="q" value="${esc(q)}" placeholder="${searchCat ? `Search in ${esc(categoryOf(searchCat).name)}` : 'Search phones, cars, raw materials'}" aria-label="Search products">
          <label class="search-photo" aria-label="Search by photo">
            ${icon('camera', 20)}
            <input type="file" accept="image/*" data-photo-search hidden>
          </label>
          <button type="submit" aria-label="Search">${icon('search')}</button>
        </form>` : ''}
        <nav class="hdr-actions" aria-label="Main">
          ${biz ? link('business.html', 'briefcase', 'Business', 'business', false, unseen ? `<b class="count">${unseen}</b>` : '') : link('exchange.html', 'swap', 'Exchange', 'exchange')}
          ${link('orders.html', 'box', 'Orders', 'orders')}
          ${user && user.role === 'admin' ? link('admin.html', 'settings', 'Admin', 'admin') : ''}
          ${user
            ? link('account.html', 'user', esc(user.name.split(' ')[0]), 'account', true)
            : link('login.html', 'user', 'Sign in', 'login', true)}
          <a href="cart.html" class="hdr-link hide-s${active === 'cart' ? ' is-active' : ''}" data-cart-target>
            ${icon('cart', 22)}<span>Cart</span><b class="count" data-cart-count hidden>0</b>
          </a>
        </nav>
      </div>
    </header>`;

  const tab = (href, ic, label, key, extra = '', attrs = '') =>
    `<a href="${href}" class="${active === key ? 'is-active' : ''}"${active === key ? ' aria-current="page"' : ''} ${attrs}>${icon(ic, 22)}<span>${label}</span>${extra}</a>`;

  $('#site-footer').innerHTML = `
    <footer class="ftr">
      <div class="container ftr-grid">
        <div>
          ${logoHtml('logo-light')}
          <p>${esc(APP.tagline)} Goods sourced from China for you and your business, plus naira exchange for yuan and crypto in one wallet.</p>
        </div>
        <div>
          <h3>Shop</h3>
          <a href="products.html">All products</a>
          <a href="categories.html">All categories</a>
          <a href="products.html?condition=used">Used products</a>
          <a href="orders.html">Track my orders</a>
        </div>
        <div>
          <h3>Business</h3>
          <a href="business.html">Business hub</a>
          <a href="assistant.html">AI assistant</a>
          <a href="brand.html">Build my brand</a>
        </div>
        <div>
          <h3>Help</h3>
          <a href="exchange.html">Exchange</a>
          <a href="wallet.html">Wallet</a>
          <a href="support.html">Customer service</a>
        </div>
      </div>
      <div class="container ftr-note">Demo build: payments, balances and exchange rates are simulated and stored only in this browser.</div>
    </footer>
    <nav class="bottom-nav" aria-label="Quick">
      ${tab('index.html', 'home', 'Home', 'home')}
      ${tab('products.html', 'grid', 'Shop', 'shop')}
      ${biz
        ? tab('business.html', 'briefcase', 'Business', 'business', unseen ? `<b class="count">${unseen}</b>` : '')
        : tab('exchange.html', 'swap', 'Exchange', 'exchange')}
      ${tab('cart.html', 'cart', 'Cart', 'cart', '<b class="count" data-cart-count hidden>0</b>', 'data-cart-target')}
      ${tab(user ? 'account.html' : 'login.html', 'user', user ? 'Account' : 'Sign in', user ? 'account' : 'login')}
    </nav>`;

  updateCartCount();

  // Header gets a shadow once the page scrolls under it.
  const header = $('#site-header');
  const onScroll = () => header.classList.toggle('is-stuck', scrollY > 40);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  document.addEventListener('click', (e) => {
    // Personal / business switch, anywhere on the page.
    const sw = e.target.closest('[data-switch-mode]');
    if (sw) {
      if (sw.getAttribute('aria-pressed') !== 'true') switchMode(sw.dataset.switchMode);
      return;
    }

    // Save / unsave a product.
    const fav = e.target.closest('[data-fav]');
    if (fav) {
      const on = Store.toggleFav(fav.dataset.fav);
      if (on === null) return toast('Sign in to save products', 'error');
      $$(`[data-fav="${CSS.escape(fav.dataset.fav)}"]`).forEach((b) => b.setAttribute('aria-pressed', on));
      return toast(on ? 'Saved to your favourites' : 'Removed from favourites');
    }

    const customize = e.target.closest('[data-customize]');
    if (customize) {
      location.href = `studio.html?id=${encodeURIComponent(customize.dataset.customize)}`;
      return;
    }

    // Any "Add to cart" button on any page. Business buyers add the minimum bulk amount.
    const btn = e.target.closest('[data-add]');
    if (!btn) return;
    const p = Store.product(btn.dataset.add);
    const qty = p && Store.isBusiness() ? Store.bulkMin(p) : 1;
    const res = Store.addToCart(btn.dataset.add, qty);
    if (!res.ok) return toast(res.error, 'error');
    toast(qty > 1 ? `Added ${qty} to cart` : 'Added to cart');
    const card = btn.closest('.product');
    flyToCart(card && $('.thumb img', card));
  });

  document.addEventListener('change', (e) => {
    // Photo search: snap or upload a product photo to find similar items.
    const input = e.target.closest('[data-photo-search]');
    if (!input || !input.files[0]) return;
    toast('Looking for products like that photo...');
    location.href = 'products.html?visual=1';
  });

  // Page scripts render right after this runs (once Store.ready has the data),
  // so wire up reveals on the next tick, after they've drawn.
  setTimeout(() => observeReveals());
}

// A save that didn't reach the server (see Store's sync()).
window.addEventListener('store:sync-error', (e) => {
  toast(`Not saved to the server: ${e.detail}`, 'error');
});
