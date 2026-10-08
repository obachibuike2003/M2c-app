mountChrome('home');

(function () {
  const rates = Store.rates();
  const products = Store.products();

  /* ---------- small fills ---------- */
  $$('[data-free-from]').forEach((el) => { el.textContent = money(APP.freeShippingFrom); });
  $$('[data-arrow]').forEach((el) => { el.insertAdjacentHTML('beforeend', icon('arrowRight', 18)); });
  $('#slide-prev').innerHTML = icon('arrowLeft');
  $('#slide-next').innerHTML = icon('arrowRight');
  $('#deals-tag').insertAdjacentHTML('afterbegin', icon('zap', 14));
  $('#cats-all').insertAdjacentHTML('beforeend', icon('chevron', 16));
  $('#tile-rate').innerHTML = `¥1 = ${money(rates.CNY.buy)} today ${icon('arrowRight', 16)}`;
  const phones = products.filter((p) => p.cat === 'phones');
  $('#phones-from').textContent = phones.length ? money(Math.min(...phones.map((p) => p.price))) : 'China';

  /* ---------- hero slider ---------- */
  (function slider() {
    const root = $('#hero-slider');
    const slides = $$('.slide', root);
    const dots = $('#slider-dots');
    const DELAY = 6000;
    let index = 0;
    let timer;

    dots.innerHTML = slides.map((_, i) => `<button type="button" aria-label="Go to slide ${i + 1}"><span><i></i></span></button>`).join('');
    const dotButtons = $$('button', dots);

    function show(next) {
      index = (next + slides.length) % slides.length;
      slides.forEach((s, i) => {
        s.classList.toggle('is-active', i === index);
        s.setAttribute('aria-hidden', i !== index);
      });
      dotButtons.forEach((d, i) => d.setAttribute('aria-current', i === index));
      restart();
    }

    function restart() {
      clearInterval(timer);
      if (reducedMotion() || root.classList.contains('is-paused')) return;
      timer = setInterval(() => show(index + 1), DELAY);
    }

    const pause = (on) => { root.classList.toggle('is-paused', on); restart(); };
    root.addEventListener('mouseenter', () => pause(true));
    root.addEventListener('mouseleave', () => pause(false));
    root.addEventListener('focusin', () => pause(true));
    root.addEventListener('focusout', () => pause(false));

    $('#slide-prev').addEventListener('click', () => show(index - 1));
    $('#slide-next').addEventListener('click', () => show(index + 1));
    dotButtons.forEach((d, i) => d.addEventListener('click', () => show(i)));

    // swipe on touch screens
    let startX = null;
    root.addEventListener('touchstart', (e) => { startX = e.touches[0].clientX; }, { passive: true });
    root.addEventListener('touchend', (e) => {
      if (startX === null) return;
      const dx = e.changedTouches[0].clientX - startX;
      if (Math.abs(dx) > 50) show(index + (dx < 0 ? 1 : -1));
      startX = null;
    });

    show(0);
  })();

  /* ---------- quick converter ---------- */
  (function converter() {
    const box = $('#fx-mini');
    const codes = Object.keys(rates);
    box.innerHTML = `
      <h2>Quick convert</h2>
      <span class="small">See what your naira gets you</span>
      <div class="fx-mini-box">
        <label for="mini-amount">You pay</label>
        <div class="fx-mini-line">
          <input id="mini-amount" type="number" inputmode="decimal" min="0" step="any" value="100000">
          <span class="code">NGN</span>
        </div>
      </div>
      <div class="fx-mini-box">
        <span class="lbl">You receive</span>
        <div class="fx-mini-line">
          <output id="mini-out" for="mini-amount" aria-live="polite"></output>
          <select id="mini-asset" aria-label="Currency">${codes.map((c) => `<option value="${c}">${c}</option>`).join('')}</select>
        </div>
      </div>
      <a class="btn btn-primary btn-block mt-16" id="mini-go" href="exchange.html">Exchange now ${icon('arrowRight', 18, 'ic-arrow')}</a>`;

    const out = $('#mini-out');
    function update() {
      const code = $('#mini-asset').value;
      const dp = rates[code].dp;
      const value = Store.quote('NGN', code, $('#mini-amount').value);
      const symbol = code === 'CNY' ? '¥' : '';
      animateNumber(out, value, (n) => symbol + n.toLocaleString('en-NG', { minimumFractionDigits: Math.min(dp, 2), maximumFractionDigits: dp }), 500);
      $('#mini-go').href = 'exchange.html?asset=' + code;
    }
    box.addEventListener('input', update);
    update();
  })();

  /* ---------- perks, categories, rates ---------- */
  $('#perks').innerHTML = [
    ['truck', 'Shipped from China', `Free above ${money(APP.freeShippingFrom)}`],
    ['shield', 'Buyer protection', 'Refund to your wallet'],
    ['swap', 'Naira, RMB, crypto', 'One wallet for all'],
    ['headset', 'Real support', 'We answer every order']
  ].map(([ic, title, text], i) => `<li class="reveal" style="--i:${i}"><span class="perk-ic">${icon(ic, 22)}</span><div><b>${title}</b><span>${text}</span></div></li>`).join('');

  $('#cat-bubbles').innerHTML = CATEGORIES.map((c, i) => `
    <a class="cat-bubble reveal" href="products.html?cat=${c.id}" style="--i:${i}">
      <span class="bubble" style="--h:${c.hue}"><img src="${esc(c.img)}" alt="" loading="lazy"></span>
      ${esc(c.name)}
    </a>`).join('');

  $('#rate-tiles').innerHTML = ['CNY', 'USDT', 'BTC', 'ETH'].filter((c) => rates[c]).map((c) => `
    <a class="rate-tile" href="exchange.html?asset=${c}">
      <span class="coin-dot">${c}</span>
      <small>${esc(rates[c].name)}</small>
      <b>${money(rates[c].buy)}</b>
    </a>`).join('');

  /* ---------- flash deals ---------- */
  const deals = [...products].filter((p) => p.stock > 0).sort((a, b) => discountOf(b) - discountOf(a)).slice(0, 10);
  $('#deals').innerHTML = deals.map((p, i) => productCard(p, i, true)).join('');

  // Countdown runs to midnight; each box pops when its number changes.
  const countdown = $('#countdown');
  countdown.innerHTML = '<span class="lbl">Ends in</span><b data-u="h">00</b><i>:</i><b data-u="m">00</b><i>:</i><b data-u="s">00</b>';
  function tick() {
    const now = new Date();
    const end = new Date(now);
    end.setHours(24, 0, 0, 0);
    const s = Math.max(0, Math.floor((end - now) / 1000));
    const parts = { h: Math.floor(s / 3600), m: Math.floor((s % 3600) / 60), s: s % 60 };
    Object.entries(parts).forEach(([unit, n]) => {
      const el = $(`[data-u="${unit}"]`, countdown);
      const text = String(n).padStart(2, '0');
      if (el.textContent === text) return;
      el.textContent = text;
      el.classList.remove('tick');
      void el.offsetWidth;
      el.classList.add('tick');
    });
  }
  tick();
  setInterval(tick, 1000);

  /* ---------- recommended, with category chips ---------- */
  const PAGE = 15;
  const rec = { cat: '', shown: PAGE };
  const sorted = [...products].sort((a, b) => (b.sold || 0) - (a.sold || 0));

  function renderRecommended() {
    $('#rec-chips').innerHTML = [{ id: '', name: 'All' }, ...CATEGORIES].map((c) =>
      `<button type="button" class="chip${rec.cat === c.id ? ' is-on' : ''}" data-cat="${c.id}" aria-pressed="${rec.cat === c.id}">${esc(c.name)}</button>`).join('');
    const list = sorted.filter((p) => !rec.cat || p.cat === rec.cat);
    $('#recommended').innerHTML = list.length
      ? list.slice(0, rec.shown).map((p, i) => productCard(p, i)).join('')
      : '<p class="muted">No products yet. Add some from the admin panel.</p>';
    $('#rec-more').hidden = rec.shown >= list.length;
    observeReveals();
  }

  $('#rec-chips').addEventListener('click', (e) => {
    const chip = e.target.closest('[data-cat]');
    if (!chip) return;
    rec.cat = chip.dataset.cat;
    rec.shown = PAGE;
    renderRecommended();
  });
  $('#rec-more').addEventListener('click', () => { rec.shown += PAGE; renderRecommended(); });

  renderRecommended();
})();
