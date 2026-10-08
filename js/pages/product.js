mountChrome('shop');

(function () {
  const root = $('#pdp-root');
  const p = Store.product(new URLSearchParams(location.search).get('id'));

  if (!p) {
    root.innerHTML = `<div class="card empty">${icon('box', 40)}<h1>Product not found</h1><p>It may have been removed.</p><a class="btn btn-primary" href="products.html">Browse products</a></div>`;
    return;
  }

  document.title = `${p.name} | ${APP.name}`;
  const cat = categoryOf(p.cat);
  const off = discountOf(p);
  const out = p.stock < 1;
  const photos = [...new Set([...(p.imgs || []), p.img].map(safeImage).filter(Boolean))].slice(0, 5);
  let qty = 1;

  root.innerHTML = `
    <p class="small muted"><a href="index.html">Home</a> / <a href="products.html?cat=${cat.id}">${esc(cat.name)}</a></p>
    <div class="pdp mt-12">
      <div class="gallery">
        <div class="pdp-media" id="pdp-media">
          ${photos.length ? `<img id="pdp-img" src="${esc(photos[0])}" alt="${esc(p.name)}">` : productThumb(p, 120)}
          ${off ? `<span class="badge badge-off">-${off}%</span>` : ''}
        </div>
        ${photos.length > 1 ? `
          <div class="gallery-thumbs">
            ${photos.map((src, i) => `<button type="button" data-photo="${esc(src)}" aria-pressed="${i === 0}" aria-label="Photo ${i + 1}"><img src="${esc(src)}" alt=""></button>`).join('')}
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
          ${out ? '<span class="pill pill-grey">Out of stock</span>' : `<span class="pill pill-green">${p.stock} in stock</span>`}
        </div>
        <div class="price-box">
          <div class="row">
            <span class="pdp-price">${money(p.price)}</span>
            ${off ? `<span class="old-price">${money(p.oldPrice)}</span><span class="pill pill-green">Save ${off}%</span>` : ''}
          </div>
          <p class="small muted">About ${money(toYuan(p.price), 'CNY')} at today's rate</p>
        </div>
        <div class="row">
          <span class="label" id="qty-label" style="margin:0">Quantity</span>
          <div class="qty" role="group" aria-labelledby="qty-label">
            <button type="button" id="qty-minus" aria-label="Decrease quantity">${icon('minus', 18)}</button>
            <output id="qty-value" aria-live="polite">1</output>
            <button type="button" id="qty-plus" aria-label="Increase quantity">${icon('plus', 18)}</button>
          </div>
        </div>
        <div class="row pdp-actions">
          <button class="btn btn-outline" id="add-btn" type="button" ${out ? 'disabled' : ''}>${icon('cart', 18)} Add to cart</button>
          <button class="btn btn-primary" id="buy-btn" type="button" ${out ? 'disabled' : ''}>Buy now ${icon('arrowRight', 18, 'ic-arrow')}</button>
        </div>
        <ul class="facts">
          <li>${icon('truck', 18)}<span>Ships from China, arrives in about ${esc(p.ship || '7-15')} days</span></li>
          <li>${icon('check', 18)}<span>Free delivery on orders above ${money(APP.freeShippingFrom)}</span></li>
          <li>${icon('shield', 18)}<span>Pay with your naira wallet or on delivery</span></li>
        </ul>
        <div>
          <h2>About this item</h2>
          <p class="mt-12">${esc(p.desc)}</p>
        </div>
      </div>
    </div>`;

  /* gallery: switch photo, and zoom towards the pointer on hover */
  const media = $('#pdp-media');
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
    media.addEventListener('mousemove', (e) => {
      const r = media.getBoundingClientRect();
      mainImg.style.transformOrigin = `${((e.clientX - r.left) / r.width) * 100}% ${((e.clientY - r.top) / r.height) * 100}%`;
      media.classList.add('is-zoomed');
    });
    media.addEventListener('mouseleave', () => media.classList.remove('is-zoomed'));
  }

  const setQty = (n) => {
    qty = Math.max(1, Math.min(n, Math.max(1, p.stock)));
    $('#qty-value').textContent = qty;
  };
  $('#qty-minus').addEventListener('click', () => setQty(qty - 1));
  $('#qty-plus').addEventListener('click', () => setQty(qty + 1));

  function add() {
    const res = Store.addToCart(p.id, qty);
    if (!res.ok) toast(res.error, 'error');
    return res.ok;
  }
  $('#add-btn').addEventListener('click', () => {
    if (!add()) return;
    toast('Added to cart');
    flyToCart(mainImg);
  });
  $('#buy-btn').addEventListener('click', () => { if (add()) location.href = 'checkout.html'; });

  const related = Store.products().filter((x) => x.cat === p.cat && x.id !== p.id).slice(0, 5);
  if (related.length) {
    $('#related').innerHTML = related.map((x, i) => productCard(x, i)).join('');
    $('#related-section').hidden = false;
  }
})();
