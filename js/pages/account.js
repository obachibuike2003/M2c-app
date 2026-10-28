// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('account');

(function () {
  if (!requireLogin()) return;
  const root = $('#account-root');

  const VERIFY_TEXT = {
    none: 'Verify your identity for faster approval on big orders.',
    pending: 'Your selfie is waiting for our team to check it.',
    verified: 'Your identity is verified.',
    rejected: 'We could not verify that photo. Try again.'
  };

  function render() {
    const user = Store.currentUser();
    const biz = user.mode === 'business';
    const type = biz && user.business ? Store.businessType(user.business.type) : null;
    const a = biz ? Store.agent(user.agentId) : null;
    const v = (user.verify || {}).status || 'none';
    const favs = (user.favs || []).map(Store.product).filter(Boolean);

    root.innerHTML = `
      <div class="row spread">
        <div><h1>Hi, ${esc(user.name.split(' ')[0])}</h1><span class="muted small">${esc(user.email)} · ${esc(user.phone)}</span></div>
        <div class="row">
          ${user.role === 'admin' ? `<a class="btn btn-outline btn-sm" href="admin.html">${icon('settings', 16)} Admin panel</a>` : ''}
          <button type="button" class="btn btn-outline btn-sm" data-act="logout">${icon('logout', 16)} Sign out</button>
        </div>
      </div>

      <section class="card section" aria-labelledby="mode-h">
        <h2 id="mode-h">How are you buying?</h2>
        <div class="mode-pick mt-16">
          <button type="button" class="mode-opt" data-switch-mode="personal" aria-pressed="${!biz}">
            ${icon('user', 26)}<b>Personal</b><span>For yourself, family and friends. Retail prices, buy one or more.</span>
          </button>
          <button type="button" class="mode-opt" data-switch-mode="business" aria-pressed="${biz}">
            ${icon('briefcase', 26)}<b>Business</b><span>Bulk buying from ${Store.bulk().minQty} pieces at wholesale prices, your own agent, logo branding and the AI assistant.</span>
          </button>
        </div>
        ${biz ? `
          <form id="biz-edit" class="form-grid cols-2 mt-16" novalidate>
            <label class="field"><span>Business name</span><input name="name" maxlength="80" value="${esc(user.business.name)}"></label>
            <label class="field"><span>Type of business</span>
              <select name="type">${BUSINESS_TYPES.map((t) => `<option value="${t.id}"${type && type.id === t.id ? ' selected' : ''}>${esc(t.name)}</option>`).join('')}</select>
            </label>
            <div class="full row"><button class="btn btn-outline btn-sm" type="submit">Save business details</button><p class="form-error" role="alert" hidden></p></div>
          </form>` : ''}
      </section>

      <a class="card section row spread" href="kyc.html" aria-labelledby="verify-h">
        <div><span class="kicker" id="verify-h">Account upgrades &amp; KYC</span><p class="muted mt-12">${VERIFY_TEXT[v]}</p></div>
        <div class="row" style="flex:none">${statusPill(v === 'none' ? 'Not verified' : v)}${icon('arrowRight', 18)}</div>
      </a>

      <section class="card section invite" id="invite" aria-labelledby="invite-h">
        <span class="kicker">Invite &amp; earn</span>
        <h2 id="invite-h">Give ${money(1000)}, get ${money(1000)}</h2>
        <p class="small muted mt-12">Friends who sign up with your code get money off their first order. When they place it, you get the same off your next one.</p>
        <div id="invite-body" class="mt-12"><p class="small muted">Loading your code…</p></div>
      </section>

      <section class="section" aria-labelledby="links-h">
        <h2 id="links-h" class="visually-hidden">Shortcuts</h2>
        <div class="quick-links">
          <a href="orders.html">${icon('truck', 22)}<span>Track my orders</span></a>
          <a href="wallet.html">${icon('wallet', 22)}<span>Wallet</span></a>
          <a href="exchange.html">${icon('swap', 22)}<span>Exchange</span></a>
          ${biz ? `<a href="business.html">${icon('briefcase', 22)}<span>Business hub</span></a>` : `<a href="products.html?condition=used">${icon('tag', 22)}<span>Used products</span></a>`}
          <a href="support.html">${icon('headset', 22)}<span>Customer service</span></a>
        </div>
      </section>

      ${biz ? `
        <section class="card section agent-card">
          <span class="avatar">${esc((a ? a.name : '?').charAt(0))}</span>
          <div><span class="kicker">Your agent</span><h2>${a ? esc(a.name) : 'Being assigned'}</h2><p class="small muted">${a ? 'Helps you with bulk orders, custom branding and delivery.' : 'We will assign an agent to you shortly.'}</p></div>
          ${a ? `<div class="row"><a class="btn btn-primary btn-sm" href="business.html#agent">${icon('chat', 16)} Chat</a><a class="btn btn-outline btn-sm" href="${esc(waLink(a.whatsapp, `Hi ${a.name}, this is ${user.name} (${user.business.name}) on ${APP.name}.`))}" target="_blank" rel="noopener">${icon('whatsapp', 16)} WhatsApp</a></div>` : ''}
        </section>` : ''}

      <section class="section" aria-labelledby="fav-h">
        <div class="section-head"><h2 id="fav-h">Saved products</h2></div>
        ${favs.length
          ? `<div class="grid-products">${favs.map((p, i) => productCard(p, i)).join('')}</div>`
          : `<p class="muted">Tap the ${icon('heart', 16)} on any product to save it here. We also use your saved products to recommend things you'll like.</p>`}
      </section>`;
    observeReveals();
    invite();
  }

  root.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-act]');
    if (!btn) return;
    if (btn.dataset.act === 'logout') {
      Store.logout();
      location.href = 'index.html';
    }
  });

  root.addEventListener('submit', (e) => {
    if (e.target.id !== 'biz-edit') return;
    e.preventDefault();
    const d = Object.fromEntries(new FormData(e.target));
    const res = Store.setMode('business', d);
    if (!res.ok) return showError($('.form-error', e.target), res.error);
    toast('Business details saved');
    render();
  });

  /* ---------- invite friends ---------- */
  async function invite() {
    const box = $('#invite-body');
    if (!box) return;
    try {
      const r = await Store.api('GET', '/api/referral');
      const link = `${location.origin}${location.pathname.replace(/[^/]*$/, '')}login.html?ref=${encodeURIComponent(r.code)}`;
      const text = `Shop factory prices from China, paid in naira, on ${APP.name}. Sign up with my code ${r.code} and get ${money(r.reward)} off your first order: ${link}`;
      box.innerHTML = `
        <div class="row spread invite-code">
          <b style="font-size:1.6rem;letter-spacing:.12em">${esc(r.code)}</b>
          <button type="button" class="btn btn-outline btn-sm" id="copy-code">${icon('copy', 16)} Copy</button>
        </div>
        <div class="row mt-12">
          <a class="btn btn-primary btn-sm" href="https://wa.me/?text=${encodeURIComponent(text)}" target="_blank" rel="noopener">${icon('whatsapp', 16)} Share on WhatsApp</a>
          <button type="button" class="btn btn-soft btn-sm" id="copy-link">${icon('copy', 16)} Copy invite link</button>
        </div>
        <p class="small muted mt-12">${r.invited} joined · ${r.ordered} ordered · ${money(r.earned)} earned${r.credit ? ` · <b>${money(r.credit)} off your next order</b>` : ''}</p>
        ${r.canApply ? `
          <form class="row mt-12" id="apply-ref">
            <input class="input" name="code" maxlength="12" placeholder="Friend's code" style="flex:1 1 140px;text-transform:uppercase" aria-label="Friend's referral code">
            <button class="btn btn-outline btn-sm" type="submit">Add code</button>
          </form>` : ''}`;
      const copy = async (value, msg) => { try { await navigator.clipboard.writeText(value); toast(msg); } catch (e) { toast('Could not copy', 'error'); } };
      $('#copy-code').addEventListener('click', () => copy(r.code, 'Code copied'));
      $('#copy-link').addEventListener('click', () => copy(text, 'Invite link copied'));
      const form = $('#apply-ref');
      if (form) form.addEventListener('submit', async (e) => {
        e.preventDefault();
        try {
          await Store.api('POST', '/api/referral/apply', { code: form.elements.code.value });
          toast(`Code added. ${money(r.reward)} comes off your first order.`);
          invite();
        } catch (err) { toast(err.message, 'error'); }
      });
    } catch (e) {
      box.innerHTML = `<p class="small muted">${esc(e.message)}</p>`;
    }
  }

  render();
})();

});
