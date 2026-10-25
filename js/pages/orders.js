// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('orders');

(function () {
  const user = requireLogin();
  if (!user) return;

  const root = $('#orders-root');
  const placed = new URLSearchParams(location.search).get('placed');
  const last = TRACK_STAGES.length - 1;

  function render() {
    const orders = Store.userOrders(user.id);
    if (!orders.length) {
      root.innerHTML = `<div class="card empty">${icon('box', 40)}<h2>No orders yet</h2><p>When you buy something, you can track it here.</p><a class="btn btn-primary" href="products.html">Start shopping</a></div>`;
      return;
    }

    root.innerHTML = `
      ${placed && orders.some((o) => o.id === placed) ? `<p class="notice notice-ok">Order ${esc(placed)} placed. Thank you! You can follow every step below.</p>` : ''}
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
              <span class="small muted">${o.pay === 'wallet' ? 'Paid from wallet' : 'Pay on delivery'} · Delivery ${o.shipping ? money(o.shipping) : 'free'}<br>To ${esc(o.address.street)}, ${esc(o.address.city)}, ${esc(o.address.state)}</span>
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

  root.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-cancel]');
    if (!btn) return;
    if (!confirm('Cancel this order? Wallet payments are refunded straight away.')) return;
    toast(Store.cancelMyOrder(btn.dataset.cancel) ? 'Order cancelled' : 'This order can no longer be cancelled');
    render();
  });

  render();
})();

});
