// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('business');

(function () {
  const root = $('#brand-root');
  const user = requireBusiness(root);
  if (!user) return;

  const typeId = user.business.type;
  const saved = user.brand || {};
  const brand = {
    name: saved.name || user.business.name,
    tagline: saved.tagline || '',
    logo: saved.logo || '',
    c1: saved.c1 || '#e0182d',
    c2: saved.c2 || '#111216',
    steps: saved.steps || {}
  };

  // Tagline ideas by type of business. {name} is replaced with the business name.
  const TAGLINES = {
    fashion: ['Style that speaks for you', 'Look good, feel good, every day', 'Fresh fits at fair prices', 'Dress the part with {name}'],
    phones: ['Original gadgets, honest prices', 'Stay connected, stay ahead', 'Your trusted phone plug', 'Tech you can count on'],
    electronics: ['Power your home for less', 'Quality electronics, fair prices', 'Bright ideas, better living'],
    beauty: ['Glow with confidence', 'Beauty that cares for you', 'Your skin, our passion', 'Look your best with {name}'],
    soap: ['Clean you can trust', 'Made fresh, made right', 'Pure clean for every home', '{name}: cleaner, fresher, better'],
    packaging: ['Packaging that protects your product', 'Built strong, made to last', 'Quality from the first layer'],
    furniture: ['Comfort for every room', 'Build a home you love', 'Style that lasts for years'],
    home: ['Everything your home needs', 'Making homes easier', 'Good things for good homes'],
    supermarket: ['Everything you need, one stop', 'Fair prices, every day', 'Your neighbourhood favourite'],
    sports: ['Play harder, play better', 'Gear up for greatness', 'Built for the game'],
    cars: ['Drive your dream today', 'Quality cars, honest deals', 'Your trusted car plug'],
    other: ['Quality you can trust', 'Good things, fair prices', 'Here for you, every time', '{name}: done right']
  };
  const PALETTES = [['#e0182d', '#111216'], ['#1d4ed8', '#ffc83d'], ['#0b7a43', '#f5f0e6'], ['#8b5cf6', '#111216'], ['#ec4899', '#2a2c33'], ['#f97316', '#1e293b'], ['#0f766e', '#fde68a'], ['#111216', '#d4af37']];

  const STEPS = [
    ['niche', 'Pick what you will sell', 'You chose: ' + (Store.businessType(typeId) || { name: 'your business' }).name + '. You can change it on your account page.'],
    ['kit', 'Make your brand kit', 'Name, logo, colours and tagline, on this page.'],
    ['stock', 'Order your first stock', 'Start small, around the minimum, and see what sells.', 'products.html'],
    ['brandgoods', 'Put your logo on your goods', 'Tap "Customise with your logo" on any product.', 'products.html'],
    ['price', 'Set your selling prices', 'Use the calculator below so every sale makes a profit.'],
    ['market', 'Tell people', 'Share your products on WhatsApp status, Instagram and with old customers.']
  ];

  root.innerHTML = `
    <section class="page-hero bg-shopper">
      <span class="kicker">Build my brand</span>
      <h1>Build a business people remember</h1>
      <p>Make your brand kit here. Your logo is saved and used when you customise products.</p>
    </section>

    <div class="two-col">
      <form class="card stack" id="brand-form" novalidate>
        <h2>Your brand kit</h2>
        <label class="field"><span>Brand name</span><input name="name" maxlength="40" value="${esc(brand.name)}"></label>
        <div class="field">
          <span>Tagline</span>
          <div class="row"><input class="input" name="tagline" maxlength="70" value="${esc(brand.tagline)}" placeholder="A short line about what you do" style="flex:1 1 200px"><button type="button" class="btn btn-soft btn-sm" id="suggest-tag">${icon('wand', 16)} Suggest</button></div>
          <div class="chips mt-12" id="tag-ideas"></div>
        </div>
        <div class="field">
          <span>Colours</span>
          <div class="row">
            <label class="color-pick"><input type="color" name="c1" value="${brand.c1}"> Main</label>
            <label class="color-pick"><input type="color" name="c2" value="${brand.c2}"> Second</label>
          </div>
          <div class="palettes mt-12" id="palettes">${PALETTES.map(([a, b]) => `<button type="button" data-pal="${a},${b}" aria-label="Use ${a} and ${b}"><i style="background:${a}"></i><i style="background:${b}"></i></button>`).join('')}</div>
        </div>
        <div class="field">
          <span>Logo</span>
          <div class="row">
            <label class="btn btn-outline btn-sm file-btn">${icon('upload', 16)} Upload logo<input type="file" name="logoFile" accept="image/png,image/jpeg,image/webp"></label>
            <button type="button" class="btn btn-soft btn-sm" id="make-logo">${icon('wand', 16)} Make one for me</button>
          </div>
          <small class="hint">No logo yet? "Make one for me" creates a simple one from your name and colours. Tap again for a different style.</small>
        </div>
        <div class="field ai-logo">
          <span>${icon('wand', 16)} Generate a logo with AI</span>
          <textarea name="logoIdea" rows="2" maxlength="200" placeholder="Say what you want, e.g. A shopping bag with a crown, bold and modern"></textarea>
          <button type="button" class="btn btn-primary btn-sm mt-12" id="ai-logo">${icon('wand', 16)} Generate logo</button>
          <small class="hint">The AI draws it in your brand name and colours, and it's saved straight away. Takes about 15 seconds.</small>
        </div>
        <p class="form-error" role="alert" hidden></p>
        <button class="btn btn-primary" type="submit">Save brand kit</button>
      </form>

      <aside class="stack">
        <section class="card">
          <h2>Preview</h2>
          <div class="brand-card mt-12" id="pv-card"></div>
          <div class="brand-post mt-12" id="pv-post"></div>
        </section>
      </aside>
    </div>

    <div class="two-col section">
      <section class="card">
        <h2>Starter steps</h2>
        <p class="small muted mt-12">Tick each one off as you go.</p>
        <ul class="steps mt-12" id="steps">
          ${STEPS.map(([id, title, text, href]) => `
            <li><label><input type="checkbox" data-step="${id}"${brand.steps[id] ? ' checked' : ''}><span><b>${title}</b><span class="small muted">${text}${href ? ` <a href="${href}">Go</a>` : ''}</span></span></label></li>`).join('')}
        </ul>
      </section>
      <aside class="card" id="calc">
        <h2>Profit calculator</h2>
        <p class="small muted mt-12">What should you sell at? Most small shops add 30% to 60%.</p>
        <div class="form-grid cols-2 mt-12">
          <label class="field"><span>Your cost per piece (₦)</span><input name="cost" type="number" min="0" inputmode="numeric" value="5000"></label>
          <label class="field"><span>Markup (%)</span><input name="markup" type="number" min="0" max="500" inputmode="numeric" value="40"></label>
          <label class="field full"><span>Pieces you will sell</span><input name="pieces" type="number" min="1" inputmode="numeric" value="50"></label>
        </div>
        <dl class="summary mt-12" id="calc-out"></dl>
      </aside>
    </div>`;

  const form = $('#brand-form');
  const error = $('.form-error', form);

  function preview() {
    const logo = brand.logo ? `<img src="${esc(brand.logo)}" alt="">` : `<i class="logo-ph" style="background:${brand.c1}">${esc(initials(brand.name))}</i>`;
    $('#pv-card').style.cssText = `--b1:${brand.c1};--b2:${brand.c2}`;
    $('#pv-card').innerHTML = `${logo}<div><b>${esc(brand.name || 'Your brand')}</b><span>${esc(brand.tagline || 'Your tagline here')}</span><small>${esc(user.phone || '')}</small></div>`;
    $('#pv-post').style.cssText = `--b1:${brand.c1};--b2:${brand.c2}`;
    $('#pv-post').innerHTML = `<span class="small">New stock in!</span><b>${esc(brand.tagline || 'Quality you can trust')}</b>${logo}<small>${esc(brand.name || '')} · Order on WhatsApp</small>`;
  }

  function initials(name) {
    const words = String(name || '?').trim().split(/\s+/).filter(Boolean);
    return (words.length > 1 ? words[0][0] + words[1][0] : (words[0] || '?').slice(0, 2)).toUpperCase();
  }

  // A simple logo: initials in a shape, in the brand colours. Each tap tries the next style.
  let style = 0;
  function makeLogo() {
    const S = 320;
    const c = document.createElement('canvas');
    c.width = c.height = S;
    const x = c.getContext('2d');
    const shape = style % 4;
    x.fillStyle = brand.c1;
    x.beginPath();
    if (shape === 0) x.arc(S / 2, S / 2, S / 2 - 6, 0, Math.PI * 2);
    else if (shape === 1) x.roundRect(10, 10, S - 20, S - 20, 70);
    else if (shape === 2) { x.moveTo(S / 2, 8); x.lineTo(S - 8, S / 2); x.lineTo(S / 2, S - 8); x.lineTo(8, S / 2); x.closePath(); }
    else x.roundRect(10, 10, S - 20, S - 20, 18);
    x.fill();
    x.strokeStyle = brand.c2;
    x.lineWidth = 12;
    if (shape !== 2) x.stroke();
    x.fillStyle = '#fff';
    x.font = `800 ${shape === 2 ? 104 : 128}px Outfit, system-ui, sans-serif`;
    x.textAlign = 'center';
    x.textBaseline = 'middle';
    x.fillText(initials(brand.name), S / 2, S / 2 + 8);
    style++;
    return c.toDataURL('image/png');
  }

  function ideas(fromAi) {
    const list = fromAi || (TAGLINES[typeId] || TAGLINES.other).map((t) => t.replace('{name}', brand.name || 'us'));
    $('#tag-ideas').innerHTML = list.map((text) => `<button type="button" class="chip" data-tag="${esc(text)}">${esc(text)}</button>`).join('');
  }

  // "Suggest" asks the AI for fresh ideas; the built-in ones stay if it's off.
  async function suggest() {
    const btn = $('#suggest-tag');
    btn.disabled = true;
    const fresh = await Assistant.taglines(brand.name);
    btn.disabled = false;
    ideas(fresh);
  }

  form.addEventListener('input', (e) => {
    const { name, value } = e.target;
    if (['name', 'tagline', 'c1', 'c2'].includes(name)) { brand[name] = value; preview(); }
  });
  form.addEventListener('click', (e) => {
    const tag = e.target.closest('[data-tag]');
    const pal = e.target.closest('[data-pal]');
    if (tag) { brand.tagline = tag.dataset.tag; form.elements.tagline.value = brand.tagline; preview(); }
    if (pal) {
      [brand.c1, brand.c2] = pal.dataset.pal.split(',');
      form.elements.c1.value = brand.c1;
      form.elements.c2.value = brand.c2;
      preview();
    }
  });
  $('#suggest-tag').addEventListener('click', suggest);
  $('#make-logo').addEventListener('click', () => { brand.logo = makeLogo(); preview(); });

  // A real logo from the AI (OpenAI through the backend), saved at once so a paid-for design isn't lost.
  $('#ai-logo').addEventListener('click', async (e) => {
    const btn = e.currentTarget;
    if (!brand.name.trim()) return showError(error, 'Enter your brand name first.');
    const idea = form.elements.logoIdea.value.trim();
    const prompt = `A logo for a Nigerian business called "${brand.name.trim()}". Main colour ${brand.c1}, second colour ${brand.c2}. ${idea || 'Modern, simple and memorable, works small on packaging.'}`;
    const label = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = `${icon('wand', 16)} Drawing your logo…`;
    showError(error, '');
    try {
      const data = await Store.api('POST', AI_DESIGN_ENDPOINT, { prompt, productName: brand.name.trim() });
      brand.logo = data.image;
      preview();
      Store.saveBrand({ logo: brand.logo });
      toast('Your new logo is ready and saved. Generate again for another idea.');
      btn.innerHTML = `${icon('wand', 16)} Generate another`;
    } catch (err) {
      showError(error, err.message);
      btn.innerHTML = label;
    } finally {
      btn.disabled = false;
    }
  });
  form.elements.logoFile.addEventListener('change', async (e) => {
    try {
      brand.logo = await readImage(e.target.files[0], 320, 'image/png');
      showError(error, '');
      preview();
    } catch (err) {
      showError(error, err.message);
    }
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    if (!brand.name.trim()) return showError(error, 'Enter your brand name.');
    brand.steps.kit = true;
    const res = Store.saveBrand({ name: brand.name.trim(), tagline: brand.tagline.trim(), logo: brand.logo, c1: brand.c1, c2: brand.c2, steps: brand.steps });
    if (!res.ok) return showError(error, res.error);
    showError(error, '');
    $('[data-step="kit"]').checked = true;
    toast('Brand kit saved. Your logo is ready for product customising.');
  });

  $('#steps').addEventListener('change', (e) => {
    const box = e.target.closest('[data-step]');
    if (!box) return;
    brand.steps[box.dataset.step] = box.checked;
    Store.saveBrand({ steps: brand.steps });
  });

  /* profit calculator */
  const calc = $('#calc');
  function runCalc() {
    const v = (n) => Math.max(0, Number(calc.querySelector(`[name=${n}]`).value) || 0);
    const cost = v('cost');
    const price = Math.round(cost * (1 + v('markup') / 100));
    const pieces = Math.max(1, v('pieces'));
    $('#calc-out').innerHTML = `
      <div class="sum-row"><dt>Sell each at</dt><dd>${money(price)}</dd></div>
      <div class="sum-row"><dt>Profit per piece</dt><dd>${money(price - cost)}</dd></div>
      <div class="sum-row sum-total"><dt>Profit on ${pieces}</dt><dd>${money((price - cost) * pieces)}</dd></div>`;
  }
  calc.addEventListener('input', runCalc);
  runCalc();

  ideas(null);
  preview();
})();

});
