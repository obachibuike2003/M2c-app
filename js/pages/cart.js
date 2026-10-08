mountChrome('cart');

(function () {
  const root = $('#cart-root');

  function summaryHtml(totals) {
    return `
      <dl>
        <div class="sum-row"><dt>Subtotal</dt><dd>${money(totals.subtotal)}</dd></div>
        <div class="sum-row"><dt>Delivery</dt><dd>${totals.shipping ? money(totals.shipping) : 'Free'}</dd></div>
        <div class="sum-row sum-total"><dt>Total</dt><dd>${money(totals.total)}</dd></div>
      </dl>`;
  }

  function render() {
    const lines = Store.cartLines();
    updateCartCount();

    if (!lines.length) {
      root.innerHTML = `<div class="card empty">${icon('cart', 40)}<h2>Your cart is empty</h2><p>Add something you like and it will show up here.</p><a class="btn btn-primary" href="products.html">Start shopping</a></div>`;
      return;
    }

    const totals = Store.cartTotals();
    const toFree = APP.freeShippingFrom - totals.subtotal;
    root.innerHTML = `
      <div class="two-col">
        <div class="card">
          ${lines.map(({ product: p, qty }) => `
            <div class="line">
              <a class="thumb" href="product.html?id=${encodeURIComponent(p.id)}">${productThumb(p, 30)}</a>
              <div>
                <a class="line-name" href="product.html?id=${encodeURIComponent(p.id)}">${esc(p.name)}</a>
                <span class="price">${money(p.price)}</span>
                <div class="line-foot">
                  <div class="qty" role="group" aria-label="Quantity for ${esc(p.name)}">
                    <button type="button" data-step="-1" data-id="${esc(p.id)}" aria-label="Decrease quantity">${icon('minus', 18)}</button>
                    <span>${qty}</span>
                    <button type="button" data-step="1" data-id="${esc(p.id)}" aria-label="Increase quantity" ${qty >= p.stock ? 'disabled' : ''}>${icon('plus', 18)}</button>
                  </div>
                  <button type="button" class="btn btn-outline btn-sm" data-remove="${esc(p.id)}">${icon('trash', 16)} Remove</button>
                </div>
              </div>
            </div>`).join('')}
        </div>
        <aside class="card summary">
          <h2>Order summary</h2>
          <div class="mt-12">${summaryHtml(totals)}</div>
          ${toFree > 0 ? `<p class="notice mt-12">Add ${money(toFree)} more for free delivery.</p>` : ''}
          <a class="btn btn-primary btn-block mt-16" href="checkout.html">Checkout</a>
          <a class="btn btn-outline btn-block mt-12" href="products.html">Keep shopping</a>
        </aside>
      </div>`;
  }

  root.addEventListener('click', (e) => {
    const step = e.target.closest('[data-step]');
    const remove = e.target.closest('[data-remove]');
    if (step) {
      const line = Store.cart().find((c) => c.id === step.dataset.id);
      if (line) Store.setCartQty(line.id, line.qty + Number(step.dataset.step));
      render();
    } else if (remove) {
      Store.setCartQty(remove.dataset.remove, 0);
      render();
    }
  });

  render();
})();
