(function () {
  const root = $('#studio-root');
  const user = requireBusiness(root);
  if (!user) return;

  const p = Store.product(new URLSearchParams(location.search).get('id'));
  if (!p) {
    root.innerHTML = `<main id="main" class="container"><div class="card empty">${icon('box', 40)}<h1>Product not found</h1><p>It may have been removed.</p><a class="btn btn-primary" href="products.html">Browse products</a></div></main>`;
    return;
  }
  if (!isCustomizable(p)) {
    root.innerHTML = `<main id="main" class="container"><div class="card empty">${icon('tag', 40)}<h1>Can't be customised</h1><p>${esc(p.name)} already carries its own brand, so your logo can't go on it.</p><a class="btn btn-primary" href="product.html?id=${esc(p.id)}">Back to product</a></div></main>`;
    return;
  }
  const min = Store.bulkMin(p);
  if (p.stock < min) {
    root.innerHTML = `<main id="main" class="container"><div class="card empty">${icon('box', 40)}<h1>Not enough stock</h1><p>${esc(p.name)} doesn't have enough left for a business order right now.</p><a class="btn btn-primary" href="product.html?id=${esc(p.id)}">Back to product</a></div></main>`;
    return;
  }

  document.title = `AiStudio – ${p.name}`;
  const photos = [...new Set([p.img, ...(p.imgs || [])].map(safeImage).filter(Boolean))];
  const saved = (user.brand || {}).logo || '';
  const design = { logo: saved, x: 0.5, y: 0.5, size: 0.3, rot: 0, tint: '' };
  const TINTS = ['', '#e0182d', '#1d4ed8', '#0b7a43', '#111216', '#f5a50b', '#8b5cf6', '#ec4899'];

  root.innerHTML = `
    <header class="studio-hdr">
      <div class="container studio-hdr-row">
        <a class="studio-wordmark" href="product.html?id=${esc(p.id)}">AiStudio</a>
        <div class="row" style="gap:4px">
          <a class="icon-btn" href="account.html" aria-label="Account">${icon('user', 20)}</a>
          <button type="button" class="icon-btn" id="studio-bell" aria-label="Notifications">${icon('bell', 20)}</button>
        </div>
      </div>
    </header>

    <main id="main" class="container studio-main">
      <p class="small muted mt-16"><a href="product.html?id=${esc(p.id)}">${icon('arrowLeft', 14)} Back to product</a></p>
      <h1 class="mt-12">Customize your ${esc(p.name)}</h1>

      <div class="card mt-16">
        <div class="row spread small muted">
          <span>Project: ${esc(p.name)}</span>
          <button type="button" class="icon-btn" id="cz-copy" aria-label="Copy project link">${icon('copy', 16)}</button>
        </div>
        <div class="studio-canvas-wrap mt-12">
          <canvas id="cz-canvas" width="480" height="480" class="cz-canvas" aria-label="Preview of your design. Drag the logo to move it."></canvas>
          <div class="cz-select" id="cz-select" hidden aria-hidden="true"><i></i><i></i><i></i><i></i></div>
        </div>
        <p class="small muted mt-12" id="cz-hint">${design.logo ? 'Drag the logo to move it.' : 'Use Uploads below to place your logo.'}</p>
      </div>

      <div class="studio-toolbar mt-16" role="toolbar" aria-label="Design tools">
        <button type="button" class="studio-tool" data-stub="Add Element">${icon('plus', 20)}<span>Add Element</span></button>
        <button type="button" class="studio-tool" data-stub="Text">${icon('type', 20)}<span>Text</span></button>
        <label class="studio-tool file-btn">${icon('upload', 20)}<span>Uploads</span><input type="file" id="cz-upload" accept="image/png,image/jpeg,image/webp" hidden></label>
        <button type="button" class="studio-tool" data-stub="Photos">${icon('image', 20)}<span>Photos</span></button>
        <button type="button" class="studio-tool" data-stub="Draw">${icon('edit', 20)}<span>Draw</span></button>
        <button type="button" class="studio-tool" data-stub="Layers">${icon('layers', 20)}<span>Layers</span></button>
      </div>

      <section class="card mt-16">
        <h2>AI Customization</h2>
        <form id="ai-form" class="mt-12" novalidate>
          <label class="field"><span class="visually-hidden">Describe your design</span>
            <textarea id="ai-prompt" rows="2" placeholder="Describe your design... e.g. Modern mountain sunset logo, forest vibes, minimalist, vibrant gradient"></textarea>
          </label>
          <button type="submit" class="btn btn-primary btn-block mt-12">${icon('wand', 16)} Generate</button>
        </form>
        <p class="small muted mt-16">${AI_DESIGN_ENDPOINT ? 'Or skip the prompt and pick a quick colour variant' : "Quick colour variants, while AI generation isn't connected yet"}</p>
        <div class="swatches mt-12" id="cz-swatches">
          ${TINTS.map((c) => `<button type="button" data-tint="${c}" aria-pressed="${c === ''}" aria-label="${c ? 'Colour ' + c : 'Original colour'}" style="--c:${c || '#fff'}">${c ? '' : icon('x', 14)}</button>`).join('')}
          <input type="color" id="cz-custom-tint" aria-label="Any colour" value="#e0182d">
        </div>
      </section>

      <section class="card mt-16">
        <h2 class="visually-hidden">Logo placement</h2>
        <label class="field"><span>Logo size</span><input type="range" id="cz-size" min="0.08" max="0.8" step="0.01" value="${design.size}"></label>
        <label class="field mt-12"><span>Turn logo</span><input type="range" id="cz-rot" min="-180" max="180" step="1" value="0"></label>
        <p class="hint">${saved ? 'Using the logo from your brand kit. Upload to change it.' : 'A PNG with a clear background looks best.'}</p>
        <button type="button" class="btn btn-soft btn-sm" id="cz-auto">${icon('wand', 16)} Auto design: centre logo &amp; match colour</button>
        <p class="form-error" id="cz-error" role="alert" hidden></p>
      </section>

      <section class="card mt-16">
        <h2>Order details</h2>
        <form id="order-form" class="mt-12" novalidate>
          <label class="field"><span>How many pieces to customise</span><input type="number" name="pieces" min="${min}" max="${p.stock}" value="${min}" inputmode="numeric"><small class="hint">Minimum order for this product is ${min}.</small></label>
          <label class="field mt-12"><span>Notes for the factory</span><textarea name="notes" maxlength="400" placeholder="For example: print the logo on the front, gold colour, our phone number under it"></textarea></label>
          <p class="form-error" id="order-error" role="alert" hidden></p>
          <button class="btn btn-primary btn-block mt-16" type="submit">${icon('cart', 18)} Add to cart</button>
        </form>
      </section>
    </main>

    <nav class="studio-nav" aria-label="AiStudio">
      <a href="index.html">${icon('home', 20)}<span>Home</span></a>
      <button type="button" data-stub="Projects">${icon('folder', 20)}<span>Projects</span></button>
      <button type="button" data-stub="Market">${icon('store', 20)}<span>Market</span></button>
      <button type="button" data-stub="Library">${icon('book', 20)}<span>Library</span></button>
      <a href="account.html">${icon('user', 20)}<span>Account</span></a>
    </nav>`;

  /* ---------- canvas: product photo, tint, draggable logo ---------- */
  const canvas = $('#cz-canvas');
  const ctx = canvas.getContext('2d');
  const select = $('#cz-select');
  const productImg = new Image();
  const logoImg = new Image();
  productImg.crossOrigin = 'anonymous';
  productImg.onload = draw;
  logoImg.onload = draw;
  if (photos.length) productImg.src = photos[0];
  if (design.logo) logoImg.src = design.logo;

  function positionSelect() {
    if (!design.logo || !logoImg.complete || !logoImg.naturalWidth) { select.hidden = true; return; }
    const r = canvas.getBoundingClientRect();
    const w = r.width * design.size;
    const h = w * (logoImg.naturalHeight / logoImg.naturalWidth);
    select.hidden = false;
    select.style.left = `${design.x * r.width - w / 2}px`;
    select.style.top = `${design.y * r.height - h / 2}px`;
    select.style.width = `${w}px`;
    select.style.height = `${h}px`;
  }

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
    positionSelect();
  }
  draw();
  addEventListener('resize', positionSelect);

  let dragging = false;
  const toCanvas = (e) => {
    const r = canvas.getBoundingClientRect();
    return { x: Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)), y: Math.min(1, Math.max(0, (e.clientY - r.top) / r.height)) };
  };
  canvas.addEventListener('pointerdown', (e) => { if (!design.logo) return; dragging = true; canvas.setPointerCapture(e.pointerId); Object.assign(design, toCanvas(e)); draw(); });
  canvas.addEventListener('pointermove', (e) => { if (!dragging) return; Object.assign(design, toCanvas(e)); draw(); });
  canvas.addEventListener('pointerup', () => { dragging = false; });

  const czError = $('#cz-error');
  $('#cz-upload').addEventListener('change', async (e) => {
    try {
      design.logo = await readImage(e.target.files[0], 320, 'image/png');
      logoImg.src = design.logo;
      $('#cz-hint').textContent = 'Drag the logo to move it.';
      showError(czError, '');
    } catch (err) {
      showError(czError, err.message);
    }
  });
  $('#cz-size').addEventListener('input', (e) => { design.size = Number(e.target.value); draw(); });
  $('#cz-rot').addEventListener('input', (e) => { design.rot = Number(e.target.value); draw(); });

  function setTint(c) {
    design.tint = c;
    $$('[data-tint]').forEach((b) => b.setAttribute('aria-pressed', b.dataset.tint === c));
    draw();
  }
  $('#cz-swatches').addEventListener('click', (e) => { const b = e.target.closest('[data-tint]'); if (b) setTint(b.dataset.tint); });
  $('#cz-custom-tint').addEventListener('input', (e) => setTint(e.target.value));

  // Auto design: centre the logo at a sensible size and colour the product to match the logo.
  $('#cz-auto').addEventListener('click', () => {
    if (!design.logo) return showError(czError, 'Upload your logo first, from the Uploads tool.');
    Object.assign(design, { x: 0.5, y: 0.48, size: 0.28, rot: 0 });
    $('#cz-size').value = design.size;
    $('#cz-rot').value = 0;
    setTint(logoColour(logoImg));
    toast('Logo placed and colour matched');
  });

  /* ---------- toolbar / nav items with no feature behind them yet ---------- */
  $$('[data-stub]').forEach((btn) => btn.addEventListener('click', () => toast(`${btn.dataset.stub} is coming soon`)));
  $('#studio-bell').addEventListener('click', () => toast('No notifications yet'));
  $('#cz-copy').addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(location.href);
      toast('Project link copied');
    } catch (err) {
      toast('Could not copy the link', 'error');
    }
  });

  /* ---------- AI generation ---------- */
  // Backs onto backend/app.py's POST /api/design/generate (OpenAI). While
  // AI_DESIGN_ENDPOINT (js/config.js) is empty, this just explains that it
  // isn't connected rather than failing silently.
  $('#ai-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const prompt = $('#ai-prompt').value.trim();
    if (!prompt) return showError(czError, 'Describe what you want before generating.');

    if (!AI_DESIGN_ENDPOINT) {
      toast('AI design generation is not connected yet. Try the colour variants or upload your own logo.');
      return;
    }

    const btn = e.target.querySelector('button[type=submit]');
    const originalLabel = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = `${icon('wand', 16)} Generating…`;
    showError(czError, '');

    try {
      const res = await fetch(AI_DESIGN_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt, productName: p.name })
      });
      const data = await res.json();
      if (!res.ok || !data.image) throw new Error(data.error || 'Could not generate that design.');

      design.logo = data.image;
      logoImg.src = design.logo;
      Object.assign(design, { x: 0.5, y: 0.48, size: 0.28, rot: 0 });
      $('#cz-size').value = design.size;
      $('#cz-rot').value = 0;
      $('#cz-hint').textContent = 'Drag the logo to move it.';
      toast('Design generated, on a white background — drag it into place');
    } catch (err) {
      showError(czError, err.message);
    } finally {
      btn.disabled = false;
      btn.innerHTML = originalLabel;
    }
  });

  /* ---------- add the customised order to the cart ---------- */
  $('#order-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.target;
    const error = $('#order-error');
    const pieces = Math.floor(Number(form.elements.pieces.value));
    const notes = form.elements.notes.value.trim();
    if (!design.logo && !notes && !design.tint) return showError(error, 'Upload a logo, pick a colour or write what you want.');
    if (!(pieces >= min && pieces <= p.stock)) return showError(error, `Enter between ${min} and ${p.stock} pieces.`);
    let preview = '';
    try {
      const small = document.createElement('canvas');
      small.width = small.height = 320;
      small.getContext('2d').drawImage(canvas, 0, 0, 320, 320);
      preview = small.toDataURL('image/jpeg', 0.8);
    } catch (err) { /* a photo from another site cannot be exported; the order keeps the logo and notes */ }
    const custom = { logo: design.logo, preview, tint: design.tint, pieces, notes };
    const res = Store.addToCart(p.id, pieces, custom);
    if (!res.ok) return showError(error, res.error);
    if (design.logo && design.logo !== saved) Store.saveBrand({ logo: design.logo });
    toast(`Added ${pieces} customised to cart`);
    updateCartCount(true);
    location.href = 'cart.html';
  });
})();
