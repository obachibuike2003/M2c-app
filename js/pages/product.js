mountChrome('shop');

(function () {
  const root = $('#pdp-root');
  const p = Store.product(new URLSearchParams(location.search).get('id'));

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
          ${off && !biz ? `<span class="badge badge-off">-${off}%</span>` : ''}
          <button class="fav-btn fav-lg" type="button" data-fav="${esc(p.id)}" aria-pressed="${Store.isFav(p.id)}" aria-label="Save ${esc(p.name)}">${icon('heart', 22)}</button>
        </div>
        ${media.length > 1 ? `
          <div class="gallery-thumbs">
            ${media.map((m, i) => `<button type="button" data-photo="${esc(m.src)}" aria-pressed="${i === 0}" aria-label="${m.gif ? 'Moving view' : 'Photo ' + (i + 1)}"${m.gif ? ' class="is-gif"' : ''}><img src="${esc(m.src)}" alt="">${m.gif ? `<span>${icon('play', 22)}</span>` : ''}</button>`).join('')}
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

        ${biz ? `
          <button class="btn btn-soft btn-block" id="custom-btn" type="button" ${out ? 'disabled' : ''}>${icon('wand', 18)} Customise with your logo</button>` : ''}
        <div class="row pdp-actions">
          <button class="btn btn-outline" id="add-btn" type="button" ${out ? 'disabled' : ''}>${icon('cart', 18)} Add to cart</button>
          <button class="btn btn-primary" id="buy-btn" type="button" ${out ? 'disabled' : ''}>Buy now ${icon('arrowRight', 18, 'ic-arrow')}</button>
        </div>
        <ul class="facts">
          <li>${icon('truck', 18)}<span>Ships from China, arrives in about ${esc(p.ship || '7-15')} days. <a href="orders.html">Track every step</a>.</span></li>
          <li>${icon('check', 18)}<span>Free delivery on orders above ${money(APP.freeShippingFrom)}</span></li>
          <li>${icon('shield', 18)}<span>Pay with your naira wallet or on delivery</span></li>
          ${biz ? `<li>${icon('chat', 18)}<span>Questions? <a href="business.html#agent">Ask your agent</a> about this product.</span></li>` : ''}
        </ul>
        <div>
          <h2>About this item</h2>
          <p class="mt-12">${esc(p.desc)}</p>
        </div>
      </div>
    </div>`;

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
  if (biz) $('#custom-btn').addEventListener('click', () => customiser());

  /* ---------- logo customiser ---------- */
  // The buyer places their logo on the product photo, picks a colour and says how many
  // pieces to brand. The preview and logo travel with the order so the team can produce it.
  function customiser() {
    const saved = (user.brand || {}).logo || '';
    const design = { logo: saved, x: 0.5, y: 0.5, size: 0.3, rot: 0, tint: '', pieces: qty, notes: '' };
    const dlg = openDialog('Customise your order', `
      <div class="custom-grid">
        <div>
          <canvas id="cz-canvas" width="480" height="480" class="cz-canvas" aria-label="Preview of your design. Drag the logo to move it."></canvas>
          <p class="small muted mt-12">Drag the logo to move it.</p>
        </div>
        <form id="cz-form" novalidate>
          <div class="field">
            <span>Your logo</span>
            <div class="row">
              <label class="btn btn-outline btn-sm file-btn">${icon('upload', 16)} Upload logo<input type="file" name="logo" accept="image/png,image/jpeg,image/webp"></label>
              <button type="button" class="btn btn-soft btn-sm" id="cz-auto">${icon('wand', 16)} Auto design</button>
            </div>
            <small class="hint">${saved ? 'Using the logo from your brand kit. Upload to change it.' : 'A PNG with a clear background looks best.'}</small>
          </div>
          <label class="field"><span>Logo size</span><input type="range" name="size" min="0.08" max="0.8" step="0.01" value="${design.size}"></label>
          <label class="field"><span>Turn logo</span><input type="range" name="rot" min="-180" max="180" step="1" value="0"></label>
          <div class="field">
            <span>Product colour</span>
            <div class="swatches" id="cz-swatches">
              ${['', '#e0182d', '#1d4ed8', '#0b7a43', '#111216', '#f5a50b', '#8b5cf6', '#ec4899'].map((c) => `<button type="button" data-tint="${c}" aria-pressed="${c === ''}" aria-label="${c ? 'Colour ' + c : 'Original colour'}" style="--c:${c || '#fff'}">${c ? '' : icon('x', 14)}</button>`).join('')}
              <input type="color" name="tintCustom" aria-label="Any colour" value="#e0182d">
            </div>
          </div>
          <label class="field"><span>How many pieces to customise</span><input type="number" name="pieces" min="1" max="${qty}" value="${qty}" inputmode="numeric"><small class="hint">You are buying ${qty}. The rest come plain.</small></label>
          <label class="field"><span>Notes for the factory</span><textarea name="notes" maxlength="400" placeholder="For example: print the logo on the front, gold colour, our phone number under it"></textarea></label>
          <p class="form-error" role="alert" hidden></p>
          <div class="form-actions"><button class="btn btn-primary" type="submit">${icon('cart', 18)} Add ${qty} to cart</button><button class="btn btn-outline" type="button" data-close>Cancel</button></div>
        </form>
      </div>`);
    dlg.classList.add('modal-wide');

    const canvas = $('#cz-canvas', dlg);
    const ctx = canvas.getContext('2d');
    const form = $('#cz-form', dlg);
    const error = $('.form-error', form);
    const productImg = new Image();
    const logoImg = new Image();
    productImg.crossOrigin = 'anonymous';
    productImg.onload = draw;
    logoImg.onload = draw;
    if (media.length) productImg.src = photos[0] || media[0].src;
    if (design.logo) logoImg.src = design.logo;

    function draw() {
      const S = canvas.width;
      ctx.fillStyle = '#fff';
      ctx.fillRect(0, 0, S, S);
      if (productImg.complete && productImg.naturalWidth) {
        const k = Math.min(S / productImg.naturalWidth, S / productImg.naturalHeight) * 0.9;
        const w = productImg.naturalWidth * k;
        const h = productImg.naturalHeight * k;
        ctx.drawImage(productImg, (S - w) / 2, (S - h) / 2, w, h);
        if (design.tint) {
          // "color" keeps the light and shade of the photo but swaps its colour; white stays white.
          ctx.globalCompositeOperation = 'color';
          ctx.fillStyle = design.tint;
          ctx.fillRect(0, 0, S, S);
          ctx.globalCompositeOperation = 'source-over';
        }
      } else {
        ctx.fillStyle = '#eceef3';
        ctx.fillRect(S * 0.15, S * 0.15, S * 0.7, S * 0.7);
      }
      if (design.logo && logoImg.complete && logoImg.naturalWidth) {
        const w = S * design.size;
        const h = w * (logoImg.naturalHeight / logoImg.naturalWidth);
        ctx.save();
        ctx.translate(design.x * S, design.y * S);
        ctx.rotate((design.rot * Math.PI) / 180);
        ctx.drawImage(logoImg, -w / 2, -h / 2, w, h);
        ctx.restore();
      }
    }
    draw();

    // drag the logo around
    let dragging = false;
    const toCanvas = (e) => {
      const r = canvas.getBoundingClientRect();
      return { x: Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)), y: Math.min(1, Math.max(0, (e.clientY - r.top) / r.height)) };
    };
    canvas.addEventListener('pointerdown', (e) => { if (!design.logo) return; dragging = true; canvas.setPointerCapture(e.pointerId); Object.assign(design, toCanvas(e)); draw(); });
    canvas.addEventListener('pointermove', (e) => { if (!dragging) return; Object.assign(design, toCanvas(e)); draw(); });
    canvas.addEventListener('pointerup', () => { dragging = false; });

    form.elements.logo.addEventListener('change', async (e) => {
      try {
        design.logo = await readImage(e.target.files[0], 320, 'image/png');
        logoImg.src = design.logo;
        showError(error, '');
      } catch (err) {
        showError(error, err.message);
      }
    });
    form.elements.size.addEventListener('input', (e) => { design.size = Number(e.target.value); draw(); });
    form.elements.rot.addEventListener('input', (e) => { design.rot = Number(e.target.value); draw(); });

    function setTint(c) {
      design.tint = c;
      $$('[data-tint]', dlg).forEach((b) => b.setAttribute('aria-pressed', b.dataset.tint === c));
      draw();
    }
    $('#cz-swatches', dlg).addEventListener('click', (e) => { const b = e.target.closest('[data-tint]'); if (b) setTint(b.dataset.tint); });
    form.elements.tintCustom.addEventListener('input', (e) => setTint(e.target.value));

    // Auto design: centre the logo at a sensible size and colour the product to match the logo.
    $('#cz-auto', dlg).addEventListener('click', () => {
      if (!design.logo) return showError(error, 'Upload your logo first.');
      Object.assign(design, { x: 0.5, y: 0.48, size: 0.28, rot: 0 });
      form.elements.size.value = design.size;
      form.elements.rot.value = 0;
      setTint(logoColour(logoImg));
      toast('Logo placed and colour matched');
    });

    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const pieces = Math.floor(Number(form.elements.pieces.value));
      const notes = form.elements.notes.value.trim();
      if (!design.logo && !notes && !design.tint) return showError(error, 'Upload a logo, pick a colour or write what you want.');
      if (!(pieces >= 1 && pieces <= qty)) return showError(error, `Enter between 1 and ${qty} pieces.`);
      let preview = '';
      try {
        const small = document.createElement('canvas');
        small.width = small.height = 320;
        small.getContext('2d').drawImage(canvas, 0, 0, 320, 320);
        preview = small.toDataURL('image/jpeg', 0.8);
      } catch (err) { /* a photo from another site cannot be exported; the order keeps the logo and notes */ }
      const custom = { logo: design.logo, preview, tint: design.tint, pieces, notes };
      if (!add(custom)) return;
      if (design.logo && design.logo !== saved) Store.saveBrand({ logo: design.logo });
      dlg.close();
      toast(`Added ${qty} customised to cart`);
      updateCartCount(true);
    });
  }

  // The most common strong colour in the logo, ignoring white, black and see-through pixels.
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

  const related = Store.products().filter((x) => x.cat === p.cat && x.id !== p.id).slice(0, 5);
  if (related.length) {
    $('#related').innerHTML = related.map((x, i) => productCard(x, i)).join('');
    $('#related-section').hidden = false;
  }
})();
