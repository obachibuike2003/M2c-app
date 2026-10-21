mountChrome('shop', { hideCategories: true });
document.body.classList.add('product-detail-page');

(function () {
  const root = $('#pdp-root');
  const pageParams = new URLSearchParams(location.search);
  const p = Store.product(pageParams.get('id'));

  if (!p) {
    root.innerHTML = `<div class="card empty">${icon('box', 40)}<h1>Product not found</h1><p>It may have been removed.</p><a class="btn btn-primary" href="products.html">Browse products</a></div>`;
    return;
  }

  document.title = `${p.name} | ${APP.name}`;
  const user = Store.currentUser();
  const biz = Store.isBusiness();
  const cat = categoryOf(p.cat);
  const off = discountOf(p);
  const min = biz ? Store.bulkMin(p) : 1;
  const out = p.stock < min;
  const photos = [...new Set([...(p.imgs || []), p.img].map(safeImage).filter(Boolean))].slice(0, 5);
  const gif = safeImage(p.gif);
  const tiers = Store.bulk().tiers.filter((t) => t.off > 0).sort((a, b) => a.from - b.from);
  let qty = min;

  const media = [...(gif ? [{ src: gif, gif: true }] : []), ...photos.map((src) => ({ src }))];

  // Wholesale price steps, as shown to business buyers (and as a teaser to personal ones).
  const tierRows = () => {
    const steps = [{ from: min, off: Store.bulkOff(min) }, ...tiers.filter((t) => t.from > min)];
    return steps.map((t) => `
      <li data-from="${t.from}"><span>${t.from}+ pieces</span><b>${money(Math.round(p.price * (1 - t.off / 100)))}</b><small>${t.off ? `${t.off}% off` : 'each'}</small></li>`).join('');
  };

  root.innerHTML = `
    <p class="small muted"><a href="index.html">Home</a> / <a href="products.html?cat=${encodeURIComponent(cat.id)}">${esc(cat.name)}</a></p>
    <div class="pdp mt-12">
      <div class="gallery">
        <div class="pdp-media" id="pdp-media">
          ${media.length ? `<img id="pdp-img" src="${esc(media[0].src)}" alt="${esc(p.name)}">` : productThumb(p, 120)}
          <button class="fav-btn fav-lg" type="button" data-fav="${esc(p.id)}" aria-pressed="${Store.isFav(p.id)}" aria-label="Save ${esc(p.name)}">${icon('heart', 22)}</button>
        </div>
        ${media.length > 1 || (biz && isCustomizable(p)) ? `
          <div class="gallery-thumbs">
            ${media.map((m, i) => `<button type="button" data-photo="${esc(m.src)}" aria-pressed="${i === 0}" aria-label="${m.gif ? 'Moving view' : 'Photo ' + (i + 1)}"${m.gif ? ' class="is-gif"' : ''}><img src="${esc(m.src)}" alt="">${m.gif ? `<span>${icon('play', 22)}</span>` : ''}</button>`).join('')}
            ${biz && isCustomizable(p) && !out ? `<a class="gallery-customize" href="studio.html?id=${encodeURIComponent(p.id)}" aria-label="Customize ${esc(p.name)} with your brand" title="Customize with your brand">${icon('plus', 24)}</a>` : ''}
          </div>` : ''}
      </div>

      <div class="card pdp-info stack">
        <div>
          <span class="kicker">${esc(cat.name)}</span>
          <h1>${esc(p.name)}</h1>
        </div>
        <div class="row small muted">
          <span class="rating">${icon('star', 16)} ${p.rating ? p.rating.toFixed(1) : 'New'}</span>
          <span>${compact(p.sold || 0)} sold</span>
          <span class="pill ${p.condition === 'used' ? 'pill-amber' : 'pill-blue'}">${p.condition === 'used' ? 'Used' : 'Brand new'}</span>
          ${p.stock < 1 ? '<span class="pill pill-grey">Out of stock</span>' : `<span class="pill pill-green">${p.stock} in stock</span>`}
        </div>

        ${biz ? `
          <div class="price-box">
            <span class="small muted">Wholesale price per piece</span>
            <div class="row"><span class="pdp-price" id="unit-price">${money(Store.unitPrice(p, qty))}</span><span class="pill pill-blue">Min. order ${min}</span></div>
            <ul class="tiers" id="tiers">${tierRows()}</ul>
            <p class="small muted">Retail price ${money(p.price)} · about ${money(toYuan(Store.unitPrice(p, qty)), 'CNY')} each</p>
          </div>` : `
          <div class="price-box">
            <div class="row">
              <span class="pdp-price">${money(p.price)}</span>
              ${off ? `<span class="old-price">${money(p.oldPrice)}</span><span class="pill pill-green">Save ${off}%</span>` : ''}
            </div>
            <p class="small muted">About ${money(toYuan(p.price), 'CNY')} at today's rate</p>
          </div>
          ${tiers.length && p.stock >= Store.bulkMin(p) ? `
            <div class="biz-teaser">
              ${icon('briefcase', 20)}
              <p><b>Buying for your business?</b> Get it for ${money(Math.round(p.price * (1 - tiers[tiers.length - 1].off / 100)))} each when you buy ${tiers[tiers.length - 1].from} or more.</p>
              <button type="button" class="btn btn-soft btn-sm" data-switch-mode="business">Buy as business</button>
            </div>` : ''}`}

        <div class="row">
          <label class="label" for="qty-input" style="margin:0">Quantity</label>
          <div class="qty" role="group" aria-label="Quantity">
            <button type="button" id="qty-minus" aria-label="Decrease quantity">${icon('minus', 18)}</button>
            <input id="qty-input" type="number" inputmode="numeric" min="${min}" max="${p.stock}" value="${qty}" aria-label="Quantity">
            <button type="button" id="qty-plus" aria-label="Increase quantity">${icon('plus', 18)}</button>
          </div>
          ${biz ? `<span class="small muted">Total <b class="num" id="line-total">${money(Store.unitPrice(p, qty) * qty)}</b></span>` : ''}
        </div>
        ${biz && out && p.stock > 0 ? `<p class="notice">Only ${p.stock} left, which is below the business minimum of ${min}. Switch to personal to buy what's left.</p>` : ''}

        <div class="row pdp-actions">
          <button class="btn btn-outline" id="add-btn" type="button" ${out ? 'disabled' : ''}>${icon('cart', 18)} Add to cart</button>
          <button class="btn btn-primary" id="buy-btn" type="button" ${out ? 'disabled' : ''}>Buy now ${icon('arrowRight', 18, 'ic-arrow')}</button>
        </div>
        <div>
          <h2>About this item</h2>
          <p class="mt-12">${esc(p.desc)}</p>
        </div>
        <ul class="facts">
          <li>${icon('truck', 18)}<span>Ships from China, arrives in about ${esc(p.ship || '7-15')} days. <a href="orders.html">Track every step</a>.</span></li>
          <li>${icon('check', 18)}<span>Free delivery on orders above ${money(APP.freeShippingFrom)}</span></li>
          <li>${icon('shield', 18)}<span>Pay with your naira wallet or on delivery</span></li>
          ${biz ? `<li>${icon('chat', 18)}<span>Questions? <a href="business.html#agent">Ask your agent</a> about this product.</span></li>` : ''}
        </ul>
      </div>
    </div>

    <section class="card section" id="reviews-section" aria-labelledby="reviews-h">
      <div class="row spread">
        <h2 id="reviews-h">Reviews</h2>
        <button type="button" class="btn btn-outline btn-sm" id="review-btn">${icon('star', 16)} Write a review</button>
      </div>
      <div id="reviews-list" class="mt-12"></div>
    </section>`;

  /* gallery: switch photo, and zoom towards the pointer on hover */
  const mediaBox = $('#pdp-media');
  const mainImg = $('#pdp-img');
  root.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-photo]');
    if (!btn || !mainImg) return;
    $$('[data-photo]', root).forEach((b) => b.setAttribute('aria-pressed', b === btn));
    mainImg.style.opacity = 0;
    setTimeout(() => {
      mainImg.src = btn.dataset.photo;
      mainImg.style.opacity = 1;
    }, 150);
  });
  if (mainImg && matchMedia('(hover: hover)').matches) {
    mediaBox.addEventListener('mousemove', (e) => {
      const r = mediaBox.getBoundingClientRect();
      mainImg.style.transformOrigin = `${((e.clientX - r.left) / r.width) * 100}% ${((e.clientY - r.top) / r.height) * 100}%`;
      mediaBox.classList.add('is-zoomed');
    });
    mediaBox.addEventListener('mouseleave', () => mediaBox.classList.remove('is-zoomed'));
  }

  /* quantity */
  const input = $('#qty-input');
  function setQty(n) {
    qty = Math.max(min, Math.min(Math.floor(Number(n) || min), Math.max(min, p.stock)));
    input.value = qty;
    if (!biz) return;
    const unit = Store.unitPrice(p, qty);
    $('#unit-price').textContent = money(unit);
    $('#line-total').textContent = money(unit * qty);
    const steps = $$('#tiers li');
    const current = steps.filter((li) => qty >= Number(li.dataset.from)).pop();
    steps.forEach((li) => li.classList.toggle('is-on', li === current));
  }
  $('#qty-minus').addEventListener('click', () => setQty(qty - 1));
  $('#qty-plus').addEventListener('click', () => setQty(qty + 1));
  input.addEventListener('change', () => setQty(input.value));
  setQty(qty);

  function add(custom) {
    const res = Store.addToCart(p.id, qty, custom);
    if (!res.ok) toast(res.error, 'error');
    return res.ok;
  }
  $('#add-btn').addEventListener('click', () => {
    if (!add()) return;
    toast(qty > 1 ? `Added ${qty} to cart` : 'Added to cart');
    flyToCart(mainImg);
  });
  $('#buy-btn').addEventListener('click', () => { if (add()) location.href = 'checkout.html'; });

  /* ---------- reviews ---------- */
  function renderReviews() {
    const list = Store.reviews(p.id);
    $('#reviews-list').innerHTML = list.length
      ? list.map((r) => `
        <div class="review">
          <div class="row spread"><b>${esc(r.userName)}</b><span class="rating">${icon('star', 14)} ${r.rating}</span></div>
          <p class="small muted mt-12">${formatDate(r.at)}</p>
          ${r.text ? `<p class="mt-12">${esc(r.text)}</p>` : ''}
        </div>`).join('')
      : '<p class="muted">No reviews yet. Be the first to review this product.</p>';
  }
  renderReviews();

  $('#review-btn').addEventListener('click', () => {
    if (!user) { toast('Sign in to write a review', 'error'); location.href = 'login.html'; return; }
    let stars = 0;
    const dlg = openDialog(`Review ${p.name}`, `
      <form id="review-form" novalidate>
        <div class="field">
          <span>Your rating</span>
          <div class="star-pick" id="star-pick" role="radiogroup" aria-label="Rating">
            ${[1, 2, 3, 4, 5].map((n) => `<button type="button" data-star="${n}" aria-label="${n} star${n > 1 ? 's' : ''}" aria-pressed="false">${icon('star', 24)}</button>`).join('')}
          </div>
        </div>
        <label class="field mt-12"><span>Your review (optional)</span><textarea name="text" rows="3" maxlength="500" placeholder="What did you think?"></textarea></label>
        <div class="row mt-16"><button class="btn btn-primary" type="submit">Post review</button></div>
      </form>`);
    const pick = $('#star-pick', dlg);
    pick.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-star]');
      if (!btn) return;
      stars = Number(btn.dataset.star);
      $$('[data-star]', pick).forEach((b) => b.setAttribute('aria-pressed', String(Number(b.dataset.star) <= stars)));
    });
    $('#review-form', dlg).addEventListener('submit', (e) => {
      e.preventDefault();
      const res = Store.addReview(p.id, { rating: stars, text: new FormData(e.target).get('text') });
      if (!res.ok) return toast(res.error, 'error');
      dlg.close();
      toast('Thanks for your review');
      renderReviews();
    });
  });

  const related = relatedTo(p, Store.products());
  if (related.length) {
    $('#related').innerHTML = related.map((x, i) => productCard(x, i)).join('');
    $('#related-section').hidden = false;
  }
})();
