mountChrome('cart');

(function () {
  const root = $('#cart-root');
  const biz = Store.isBusiness();

  function summaryHtml(totals) {
    return `
      <dl>
        <div class="sum-row"><dt>Subtotal</dt><dd>${money(totals.subtotal)}</dd></div>
        ${totals.bulkSaving > 0 ? `<div class="sum-row sum-save"><dt>Wholesale saving</dt><dd>-${money(totals.bulkSaving)}</dd></div>` : ''}
        <div class="sum-row"><dt>Delivery</dt><dd>${totals.shipping ? money(totals.shipping) : 'Free'}</dd></div>
        <div class="sum-row sum-total"><dt>Total</dt><dd>${money(totals.total)}</dd></div>
      </dl>`;
  }

  // What a customised line will look like, plus what the factory is asked to do.
  function customHtml(c) {
    return `
      <div class="custom-note">
        ${c.preview ? `<img src="${esc(c.preview)}" alt="Your design">` : c.logo ? `<img src="${esc(c.logo)}" alt="Your logo">` : ''}
        <span><b>${icon('wand', 14)} Customised: ${c.pieces} piece${c.pieces === 1 ? '' : 's'}</b>${c.notes ? `<br>${esc(c.notes)}` : ''}</span>
      </div>`;
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
    const short = lines.filter((l) => l.short);
    root.innerHTML = `
      ${biz ? `<p class="notice notice-ok mb-16">${icon('briefcase', 16)} You're buying as a business: wholesale prices, at least ${Store.bulk().minQty} of each item (fewer for some big items like cars).</p>` : ''}
      <div class="two-col">
        <div class="card">
          ${lines.map((l) => {
            const p = l.product;
            const href = `product.html?id=${encodeURIComponent(p.id)}`;
            return `
            <div class="line${l.short ? ' is-short' : ''}">
              <a class="thumb" href="${href}">${productThumb(p, 30)}</a>
              <div>
                <a class="line-name" href="${href}">${esc(p.name)}</a>
                <span class="price">${money(l.unit)}</span>${biz && l.unit < p.price ? ` <span class="old-price">${money(p.price)}</span>` : ''}
                ${l.qty > 1 ? `<span class="small muted"> each · ${money(l.total)}</span>` : ''}
                ${l.custom ? customHtml(l.custom) : ''}
                ${l.short ? `<p class="line-warn">Business orders need at least ${l.min}. <button type="button" class="linkish" data-set="${esc(l.key)}" data-qty="${l.min}">Make it ${l.min}</button></p>` : ''}
                <div class="line-foot">
                  <div class="qty" role="group" aria-label="Quantity for ${esc(p.name)}">
                    <button type="button" data-step="-1" data-key="${esc(l.key)}" aria-label="Decrease quantity" ${biz && l.qty <= l.min ? 'disabled' : ''}>${icon('minus', 18)}</button>
                    <span>${l.qty}</span>
                    <button type="button" data-step="1" data-key="${esc(l.key)}" aria-label="Increase quantity" ${l.qty >= p.stock ? 'disabled' : ''}>${icon('plus', 18)}</button>
                  </div>
                  <button type="button" class="btn btn-outline btn-sm" data-remove="${esc(l.key)}">${icon('trash', 16)} Remove</button>
                </div>
              </div>
            </div>`;
          }).join('')}
        </div>
        <aside class="card summary">
          <h2>Order summary</h2>
          <div class="mt-12">${summaryHtml(totals)}</div>
          ${toFree > 0 ? `<p class="notice mt-12">Add ${money(toFree)} more for free delivery.</p>` : ''}
          ${short.length ? `<p class="form-error">Raise the quantity of ${short.length === 1 ? 'one item' : short.length + ' items'} to the business minimum, or switch to personal buying.</p>` : ''}
          ${short.length ? '<button type="button" class="btn btn-primary btn-block mt-16" disabled>Checkout</button>' : '<a class="btn btn-primary btn-block mt-16" href="checkout.html">Checkout</a>'}
          <a class="btn btn-outline btn-block mt-12" href="products.html">Keep shopping</a>
        </aside>
      </div>`;
  }

  root.addEventListener('click', (e) => {
    const step = e.target.closest('[data-step]');
    const set = e.target.closest('[data-set]');
    const remove = e.target.closest('[data-remove]');
    if (step) {
      const line = Store.cart().find((c) => c.key === step.dataset.key);
      if (line) Store.setCartQty(line.key, line.qty + Number(step.dataset.step));
    } else if (set) {
      Store.setCartQty(set.dataset.set, Number(set.dataset.qty));
    } else if (remove) {
      Store.setCartQty(remove.dataset.remove, 0);
    } else return;
    render();
  });

  render();
})();
