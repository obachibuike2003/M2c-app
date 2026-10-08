mountChrome('orders');

(function () {
  const user = requireLogin();
  if (!user) return;

  const root = $('#orders-root');
  const placed = new URLSearchParams(location.search).get('placed');

  function render() {
    const orders = Store.userOrders(user.id);
    if (!orders.length) {
      root.innerHTML = `<div class="card empty">${icon('box', 40)}<h2>No orders yet</h2><p>When you buy something, you can track it here.</p><a class="btn btn-primary" href="products.html">Start shopping</a></div>`;
      return;
    }

    root.innerHTML = `
      ${placed && orders.some((o) => o.id === placed) ? `<p class="notice notice-ok">Order ${esc(placed)} placed. Thank you!</p>` : ''}
      <div class="mt-16">
        ${orders.map((o) => `
          <article class="card order">
            <div class="row spread">
              <div><h2>${esc(o.id)}</h2><span class="small muted">${formatDate(o.createdAt)}</span></div>
              ${statusPill(o.status)}
            </div>
            <ul class="order-items mt-12">
              ${o.items.map((it) => `<li><span>${it.qty} × ${esc(it.name)}</span><span class="num">${money(it.price * it.qty)}</span></li>`).join('')}
            </ul>
            <div class="row spread mt-12">
              <span class="small muted">${o.pay === 'wallet' ? 'Paid from wallet' : 'Pay on delivery'} · Delivery ${o.shipping ? money(o.shipping) : 'free'}<br>To ${esc(o.address.street)}, ${esc(o.address.city)}, ${esc(o.address.state)}</span>
              <span class="row">
                <b class="price">${money(o.total)}</b>
                ${o.status === 'Processing' ? `<button type="button" class="btn btn-outline btn-sm" data-cancel="${esc(o.id)}">Cancel order</button>` : ''}
              </span>
            </div>
          </article>`).join('')}
      </div>`;
  }

  root.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-cancel]');
    if (!btn) return;
    if (!confirm('Cancel this order? Wallet payments are refunded straight away.')) return;
    toast(Store.cancelMyOrder(btn.dataset.cancel) ? 'Order cancelled' : 'This order can no longer be cancelled', 'ok');
    render();
  });

  render();
})();
