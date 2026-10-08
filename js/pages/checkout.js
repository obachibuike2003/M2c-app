mountChrome('cart');

(function () {
  const user = requireLogin();
  if (!user) return;

  const root = $('#checkout-root');
  const lines = Store.cartLines();
  if (!lines.length) {
    location.replace('cart.html');
    return;
  }

  const totals = Store.cartTotals();
  const a = user.address || {};
  const enough = user.balances.NGN >= totals.total;

  root.innerHTML = `
    <form class="two-col" id="checkout-form" novalidate>
      <div class="stack">
        <section class="card">
          <h2>Delivery address</h2>
          <div class="form-grid cols-2 mt-16">
            <label class="field"><span>Full name</span><input name="name" required autocomplete="name" value="${esc(a.name || user.name)}"></label>
            <label class="field"><span>Phone number</span><input name="phone" type="tel" required autocomplete="tel" inputmode="tel" value="${esc(a.phone || user.phone)}"></label>
            <label class="field full"><span>Street address</span><input name="street" required autocomplete="street-address" value="${esc(a.street)}"></label>
            <label class="field"><span>City</span><input name="city" required autocomplete="address-level2" value="${esc(a.city)}"></label>
            <label class="field"><span>State</span><input name="state" required autocomplete="address-level1" value="${esc(a.state)}"></label>
          </div>
        </section>

        <section class="card">
          <h2>Payment</h2>
          <div class="mt-16">
            <label class="choice">
              <input type="radio" name="pay" value="wallet" ${enough ? 'checked' : ''}>
              <span><b>Naira wallet</b><span class="small muted">Balance: ${money(user.balances.NGN)}${enough ? '' : ` (you need ${money(totals.total - user.balances.NGN)} more)`}</span></span>
            </label>
            <label class="choice">
              <input type="radio" name="pay" value="delivery" ${enough ? '' : 'checked'}>
              <span><b>Pay on delivery</b><span class="small muted">Pay cash or transfer when your order arrives</span></span>
            </label>
          </div>
          ${enough ? '' : '<p class="small mt-12"><a href="wallet.html">Add money to your wallet</a> to pay now.</p>'}
        </section>
      </div>

      <aside class="card summary">
        <h2>Your order</h2>
        <ul class="order-items mt-12">
          ${lines.map((l) => `<li><span>${l.qty} × ${esc(l.product.name)}</span><span class="num">${money(l.product.price * l.qty)}</span></li>`).join('')}
        </ul>
        <dl>
          <div class="sum-row"><dt>Subtotal</dt><dd>${money(totals.subtotal)}</dd></div>
          <div class="sum-row"><dt>Delivery</dt><dd>${totals.shipping ? money(totals.shipping) : 'Free'}</dd></div>
          <div class="sum-row sum-total"><dt>Total</dt><dd>${money(totals.total)}</dd></div>
        </dl>
        <p class="form-error" id="checkout-error" role="alert" hidden></p>
        <button class="btn btn-primary btn-block mt-16" type="submit">Place order</button>
      </aside>
    </form>`;

  $('#checkout-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    const error = $('#checkout-error');
    const data = Object.fromEntries(new FormData(form));
    const missing = ['name', 'phone', 'street', 'city', 'state'].find((k) => !String(data[k] || '').trim());
    if (missing) {
      showError(error, 'Please fill in every delivery field.');
      form.elements[missing].focus();
      return;
    }
    const { pay, ...address } = data;
    const res = Store.placeOrder({ address, pay });
    if (!res.ok) {
      showError(error, res.error);
      return;
    }
    location.href = 'orders.html?placed=' + encodeURIComponent(res.order.id);
  });
})();
