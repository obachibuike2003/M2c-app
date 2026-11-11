// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('orders');

(function () {
  const user = requireLogin();
  if (!user) return;

  const root = $('#orders-root');
  const placed = new URLSearchParams(location.search).get('placed');
  const last = TRACK_STAGES.length - 1;

  // Orders live on the server, where our team moves them along. Very old demo
  // orders may still be kept in this browser; they show underneath.
  let online = [];
  let loaded = false;
  async function loadOnline() {
    try {
      online = await Store.api('GET', '/api/orders');
    } catch (e) { /* offline: the browser orders still show */ }
    loaded = true;
    render();
  }

  function onlineCard(o) {
    const p = o.payment || {};
    const waiting = o.status === 'Awaiting payment' && p.status === 'pending';
    const tracked = !['Awaiting payment', 'Payment expired', 'Cancelled'].includes(o.status);
    const tone = p.status === 'paid' ? 'Paid' : waiting ? 'Awaiting payment' : o.status;
    const step = Math.min(o.stage || 0, last);
    return `
      <article class="card order">
        <div class="row spread">
          <div><h2>${esc(o.id)}</h2><span class="small muted">${formatDate(Date.parse(o.createdAt))}${o.mode === 'business' ? ' · Business order' : ''}</span></div>
          ${statusPill(o.status)}
        </div>
        ${tracked ? `
          <div class="progress mt-12" role="img" aria-label="Step ${step + 1} of ${last + 1}: ${esc(o.status)}">
            <i style="--w:${(step / last) * 100}%"></i>
          </div>
          <p class="small muted mt-12">Step ${step + 1} of ${last + 1}: ${esc(TRACK_STAGES[step].text)}</p>` : ''}
        <ul class="order-items mt-12">
          ${o.items.map((it) => `<li><span>${it.qty} × ${esc(it.name)}${it.custom ? ' <span class="pill pill-blue">customised</span>' : ''}</span><span class="num">${money(it.price * it.qty)}</span></li>`).join('')}
        </ul>
        <div class="row spread mt-12">
          <span class="small muted">${o.pay === 'nomba' ? `Nomba · ${esc(tone)}` : 'Pay on delivery'}${(o.address || {}).creditUsed ? ` · Referral credit -${money(o.address.creditUsed)}` : ''}</span>
          <b class="price">${money(o.total)}</b>
        </div>
        ${waiting && p.checkoutLink ? `<div class="row mt-12"><a class="btn btn-primary btn-sm" href="${esc(p.checkoutLink)}">${icon('lock', 16)} Pay now</a><button type="button" class="btn btn-outline btn-sm" data-check="${esc(o.id)}">I've paid, check</button></div>` : ''}
        ${tracked ? `<div class="row mt-12"><a class="btn btn-primary btn-sm" href="track.html?id=${encodeURIComponent(o.id)}">${icon('truck', 16)} Track order</a></div>` : ''}
      </article>`;
  }

  function render() {
    const orders = Store.userOrders(user.id);
    if (!loaded && !orders.length) {
      root.innerHTML = '<p class="muted">Loading your orders…</p>';
      return;
    }
    if (!orders.length && !online.length) {
      root.innerHTML = `<div class="card empty">${icon('box', 40)}<h2>No orders yet</h2><p>When you buy something, you can track it here.</p><a class="btn btn-primary" href="products.html">Start shopping</a></div>`;
      return;
    }

    root.innerHTML = `
      ${placed && (orders.some((o) => o.id === placed) || online.some((o) => o.id === placed)) ? `<p class="notice notice-ok">Order ${esc(placed)} placed. Thank you! You can follow every step below.</p>` : ''}
      ${online.length ? `<div class="mt-16">${online.map(onlineCard).join('')}</div>` : ''}
      <div class="mt-16">
        ${orders.map((o) => {
          const cancelled = o.status === 'Cancelled';
          return `
          <article class="card order">
            <div class="row spread">
              <div><h2>${esc(o.id)}</h2><span class="small muted">${formatDate(o.createdAt)}${o.mode === 'business' ? ' · Business order' : ''}</span></div>
              ${statusPill(o.status)}
            </div>
            ${cancelled ? '' : `
              <div class="progress mt-12" role="img" aria-label="Step ${o.stage + 1} of ${last + 1}: ${esc(o.status)}">
                <i style="--w:${(o.stage / last) * 100}%"></i>
              </div>
              <p class="small muted mt-12">${esc(TRACK_STAGES[o.stage].text)}</p>`}
            <ul class="order-items mt-12">
              ${o.items.map((it) => `<li><span>${it.qty} × ${esc(it.name)}${it.custom ? ` <span class="pill pill-blue">${it.custom.pieces} customised</span>` : ''}</span><span class="num">${money(it.price * it.qty)}</span></li>`).join('')}
            </ul>
            <div class="row spread mt-12">
              <span class="small muted">${o.pay === 'wallet' ? 'Paid' : 'Pay on delivery'} · Delivery ${o.shipping ? money(o.shipping) : 'free'}<br>To ${esc(o.address.street)}, ${esc(o.address.city)}, ${esc(o.address.state)}</span>
              <b class="price">${money(o.total)}</b>
            </div>
            <div class="row mt-12">
              ${cancelled ? '' : `<a class="btn btn-primary btn-sm" href="track.html?id=${encodeURIComponent(o.id)}">${icon('truck', 16)} Track order</a>`}
              ${Store.canCancel(o) ? `<button type="button" class="btn btn-outline btn-sm" data-cancel="${esc(o.id)}">Cancel order</button>` : ''}
            </div>
          </article>`;
        }).join('')}
      </div>`;
  }

  root.addEventListener('click', async (e) => {
    const check = e.target.closest('[data-check]');
    if (check) {
      check.disabled = true;
      try {
        const o = await Store.api('GET', `/api/orders/${encodeURIComponent(check.dataset.check)}/payment`);
        toast((o.payment || {}).status === 'paid' ? 'Payment received. Thank you!' : 'Not received yet. It can take a minute after paying.');
        loadOnline();
      } catch (err) { toast(err.message, 'error'); check.disabled = false; }
      return;
    }
    const btn = e.target.closest('[data-cancel]');
    if (!btn) return;
    if (!confirm('Cancel this order?')) return;
    toast(Store.cancelMyOrder(btn.dataset.cancel) ? 'Order cancelled' : 'This order can no longer be cancelled');
    render();
  });

  render();
  loadOnline();
})();

});
