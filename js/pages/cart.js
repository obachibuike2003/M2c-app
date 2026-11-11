// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('cart');

(function () {
  const root = $('#cart-root');
  const biz = Store.isBusiness();
  const FIELDS = [['name', 'Full name', 'name'], ['phone', 'Phone number', 'tel'], ['street', 'Street address', 'street-address'], ['city', 'City', 'address-level2'], ['state', 'State', 'address-level1']];
  let payOnline = false; // switched on at the server once Nomba keys are set
  let editing = false;   // address form open
  let busy = false;

  const addressOf = () => {
    const u = Store.currentUser();
    const a = (u && u.address) || {};
    return { name: a.name || (u && u.name) || '', phone: a.phone || (u && u.phone) || '', street: a.street || '', city: a.city || '', state: a.state || '' };
  };
  const complete = (a) => FIELDS.every(([k]) => String(a[k] || '').trim());
  const payLabel = (totals) => `${payOnline ? 'Pay' : 'Place order'} ${money(totals.total)}`;

  function addressHtml() {
    const user = Store.currentUser();
    if (!user) return `<div class="deliver"><p class="small muted">Sign in to add your delivery address and pay.</p></div>`;
    const a = addressOf();
    if (editing || !complete(a)) {
      return `
        <form class="deliver" id="address-form" novalidate>
          <h3>${icon('pin', 18)} Delivery address</h3>
          <div class="form-grid mt-12">
            ${FIELDS.map(([k, label, ac]) => `<label class="field"><span>${label}</span><input name="${k}" required autocomplete="${ac}"${k === 'phone' ? ' type="tel" inputmode="tel"' : ''} value="${esc(a[k])}"></label>`).join('')}
          </div>
          ${complete(a) ? '<button type="submit" class="btn btn-outline btn-sm mt-12">Save address</button>' : ''}
        </form>`;
    }
    return `
      <div class="deliver">
        <div class="row spread"><h3>${icon('pin', 18)} Deliver to</h3><button type="button" class="linkish" data-act="edit-address">Change</button></div>
        <p class="mt-12"><b>${esc(a.name)}</b> · ${esc(a.phone)}<br><span class="muted">${esc(a.street)}, ${esc(a.city)}, ${esc(a.state)}</span></p>
      </div>`;
  }

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
      document.body.classList.remove('has-paybar');
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
          <div class="mt-16">${addressHtml()}</div>
          <p class="form-error" id="pay-error" role="alert" hidden></p>
          <button type="button" class="btn btn-primary btn-block btn-lg mt-16" data-act="pay" ${short.length || busy ? 'disabled' : ''}>${icon(payOnline ? 'lock' : 'check', 18)} ${busy ? 'Please wait…' : payLabel(totals)}</button>
          <p class="small muted mt-12 center">${payOnline ? "Card, bank transfer or USSD on Nomba's secure page." : 'Our team will contact you to pay before we buy from the factory.'}</p>
          <a class="btn btn-outline btn-block mt-12" href="products.html">Keep shopping</a>
        </aside>
      </div>
      <div class="paybar" role="region" aria-label="Pay">
        <div><span class="small muted">Total</span><b>${money(totals.total)}</b><span class="small ${totals.shipping ? 'muted' : 'ok'}">${totals.shipping ? 'Includes delivery' : 'Free delivery'}</span></div>
        <button type="button" class="btn btn-primary" data-act="pay" ${short.length || busy ? 'disabled' : ''}>${icon(payOnline ? 'lock' : 'check', 18)} ${busy ? 'Please wait…' : `${payOnline ? 'Pay' : 'Place order'} (${lines.reduce((n, l) => n + l.qty, 0)})`}</button>
      </div>`;
    document.body.classList.add('has-paybar');
  }

  function readAddress() {
    const form = $('#address-form');
    if (!form) return addressOf();
    return Object.fromEntries(FIELDS.map(([k]) => [k, String(form.elements[k].value || '').trim()]));
  }

  async function pay() {
    const user = Store.currentUser();
    if (!user) { location.href = 'login.html?next=cart.html'; return; }
    const error = $('#pay-error');
    const address = readAddress();
    const missing = FIELDS.find(([k]) => !address[k]);
    if (missing) {
      editing = true;
      render();
      showError($('#pay-error'), 'Please fill in your delivery address.');
      const input = $(`#address-form [name=${missing[0]}]`);
      input.scrollIntoView({ block: 'center', behavior: 'smooth' });
      input.focus({ preventScroll: true });
      return;
    }
    const lines = Store.cartLines();
    busy = true;
    render();
    const place = (how) => Store.api('POST', '/api/orders', {
      items: lines.map((l) => ({ productId: l.product.id, qty: l.qty, ...(l.custom ? { custom: l.custom } : {}) })),
      address, pay: how, returnTo: 'web'
    });
    try {
      let order;
      try {
        order = await place(payOnline ? 'nomba' : 'delivery');
      } catch (err) {
        if (err.code !== 'pay_off') throw err;
        payOnline = false; // switched off since the page loaded
        order = await place('delivery');
      }
      Store.updateUser(user.id, { address });
      lines.forEach((l) => Store.setCartQty(l.key, 0));
      location.href = order.pay === 'nomba' && order.payment ? order.payment.checkoutLink : 'orders.html?placed=' + encodeURIComponent(order.id);
    } catch (err) {
      busy = false;
      render();
      showError($('#pay-error'), err.message);
    }
  }

  root.addEventListener('submit', (e) => {
    if (e.target.id !== 'address-form') return;
    e.preventDefault();
    const address = readAddress();
    if (!complete(address)) return showError($('#pay-error'), 'Please fill in every address field.');
    Store.updateUser(Store.currentUser().id, { address });
    editing = false;
    render();
  });

  root.addEventListener('click', (e) => {
    const act = e.target.closest('[data-act]');
    if (act && act.dataset.act === 'pay') return pay();
    if (act && act.dataset.act === 'edit-address') { editing = true; return render(); }
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
  Store.api('GET', '/api/payments/config').then((c) => {
    payOnline = !!(c && c.nomba);
    // Don't wipe an address being typed; the button updates on the next render.
    if (!busy && !(document.activeElement && document.activeElement.closest('#address-form'))) render();
  }).catch(() => {});
})();

});
