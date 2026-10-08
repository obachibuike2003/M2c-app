mountChrome('admin');

(function () {
  const root = $('#admin-root');
  const me = Store.currentUser();

  if (!me || me.role !== 'admin') {
    root.innerHTML = `<div class="card empty">${icon('shield', 40)}<h1>Admins only</h1><p>Sign in with the store admin account to manage products, orders and rates.</p><a class="btn btn-primary" href="login.html?next=admin.html">Sign in</a></div>`;
    return;
  }

  const TABS = [['overview', 'Overview'], ['products', 'Products'], ['orders', 'Orders'], ['rates', 'Rates'], ['payouts', 'Send-outs'], ['users', 'Customers']];
  const STATUSES = ['Processing', 'Shipped', 'Delivered', 'Cancelled'];
  let tab = TABS.some(([id]) => id === location.hash.slice(1)) ? location.hash.slice(1) : 'overview';

  const userName = (id) => (Store.users().find((u) => u.id === id) || { name: 'Deleted user' }).name;
  const table = (head, rows, emptyText) => (rows.length
    ? `<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`
    : `<p class="muted">${emptyText}</p>`);

  const panels = {
    overview() {
      const orders = Store.orders();
      const live = orders.filter((o) => o.status !== 'Cancelled');
      const products = Store.products();
      const pending = Store.txns().filter((t) => t.type === 'payout' && t.status === 'processing').length;
      const low = products.filter((p) => p.stock <= 20).sort((a, b) => a.stock - b.stock);
      const stat = (label, value) => `<div class="stat"><span class="small muted">${label}</span><b>${value}</b></div>`;
      return `
        <div class="stats">
          ${stat('Sales', money(live.reduce((n, o) => n + o.total, 0)))}
          ${stat('Orders', live.length)}
          ${stat('Products', products.length)}
          ${stat('Send-outs waiting', pending)}
        </div>
        <section class="card section">
          <h2>Recent orders</h2>
          <div class="mt-12">${table('<th>Order</th><th>Customer</th><th>Status</th><th class="num">Total</th>',
            orders.slice(0, 5).map((o) => `<tr><td>${esc(o.id)}<br><span class="small muted">${formatDate(o.createdAt)}</span></td><td>${esc(userName(o.userId))}</td><td>${statusPill(o.status)}</td><td class="num">${money(o.total)}</td></tr>`),
            'No orders yet.')}</div>
        </section>
        <section class="card section">
          <h2>Low stock</h2>
          <div class="mt-12">${table('<th>Product</th><th class="num">Left</th>',
            low.map((p) => `<tr><td>${esc(p.name)}</td><td class="num">${p.stock}</td></tr>`),
            'Everything is well stocked.')}</div>
        </section>`;
    },

    products() {
      return `
        <section class="card">
          <div class="section-head"><h2>Products</h2><button type="button" class="btn btn-primary btn-sm" data-act="add-product">${icon('plus', 16)} Add product</button></div>
          ${table('<th>Item</th><th>Name</th><th>Category</th><th class="num">Price</th><th class="num">Stock</th><th class="num">Sold</th><th>Actions</th>',
            Store.products().map((p) => `
              <tr>
                <td><div class="thumb">${productThumb(p, 22)}</div></td>
                <td>${esc(p.name)}</td>
                <td>${esc(categoryOf(p.cat).name)}</td>
                <td class="num">${money(p.price)}</td>
                <td class="num">${p.stock}</td>
                <td class="num">${p.sold || 0}</td>
                <td><span class="row">
                  <button type="button" class="btn btn-outline btn-sm" data-act="edit-product" data-id="${esc(p.id)}">Edit</button>
                  <button type="button" class="btn btn-outline btn-sm" data-act="delete-product" data-id="${esc(p.id)}" aria-label="Delete ${esc(p.name)}">${icon('trash', 16)}</button>
                </span></td>
              </tr>`),
            'No products yet. Add your first one.')}
        </section>`;
    },

    orders() {
      return `
        <section class="card">
          <div class="section-head"><h2>Orders</h2></div>
          ${table('<th>Order</th><th>Customer</th><th>Items</th><th>Payment</th><th class="num">Total</th><th>Status</th>',
            Store.orders().map((o) => `
              <tr>
                <td>${esc(o.id)}<br><span class="small muted">${formatDate(o.createdAt)}</span></td>
                <td>${esc(o.address.name)}<br><span class="small muted">${esc(o.address.phone)} · ${esc(o.address.city)}, ${esc(o.address.state)}</span></td>
                <td class="small">${o.items.map((it) => `${it.qty} × ${esc(it.name)}`).join('<br>')}</td>
                <td>${o.pay === 'wallet' ? 'Wallet (paid)' : 'On delivery'}</td>
                <td class="num">${money(o.total)}</td>
                <td>${o.status === 'Cancelled' ? statusPill(o.status) : `
                  <select class="input" data-order="${esc(o.id)}" aria-label="Status for ${esc(o.id)}">
                    ${STATUSES.map((s) => `<option${s === o.status ? ' selected' : ''}>${s}</option>`).join('')}
                  </select>`}</td>
              </tr>`),
            'No orders yet.')}
        </section>`;
    },

    rates() {
      const rates = Store.rates();
      return `
        <form class="card" id="rates-form" novalidate>
          <div class="section-head"><h2>Exchange rates</h2></div>
          <p class="muted small">Naira per 1 unit. "Customer buys at" is what a customer pays you; "customer sells at" is what you pay a customer. The gap between them is your margin.</p>
          <div class="table-wrap mt-12">
            <table>
              <thead><tr><th>Currency</th><th>Customer buys at (₦)</th><th>Customer sells at (₦)</th></tr></thead>
              <tbody>
                ${Object.keys(rates).map((c) => `
                  <tr>
                    <td><b>${c}</b><br><span class="small muted">${esc(rates[c].name)}</span></td>
                    <td><input class="input" type="number" min="0" step="any" inputmode="decimal" name="${c}_buy" value="${rates[c].buy}" aria-label="${c} customer buys at"></td>
                    <td><input class="input" type="number" min="0" step="any" inputmode="decimal" name="${c}_sell" value="${rates[c].sell}" aria-label="${c} customer sells at"></td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>
          <p class="form-error" id="rates-error" role="alert" hidden></p>
          <div class="form-actions"><button class="btn btn-primary" type="submit">Save rates</button></div>
        </form>`;
    },

    payouts() {
      const list = Store.txns().filter((t) => t.type === 'payout');
      return `
        <section class="card">
          <div class="section-head"><h2>Send-outs</h2></div>
          <p class="muted small">Customers asking to move money out of their wallet. Mark one as sent after you make the transfer, or reject it to return the money.</p>
          <div class="mt-12">${table('<th>Date</th><th>Customer</th><th>Destination</th><th class="num">Amount</th><th>Status</th><th>Actions</th>',
            list.map((t) => `
              <tr>
                <td class="small muted">${formatDate(t.createdAt)}</td>
                <td>${esc(userName(t.userId))}</td>
                <td>${esc(t.desc.replace(/^Send to /, ''))}</td>
                <td class="num">${money(-t.amount, t.currency)}</td>
                <td>${statusPill(t.status)}</td>
                <td>${t.status === 'processing' ? `<span class="row">
                  <button type="button" class="btn btn-primary btn-sm" data-act="payout-ok" data-id="${esc(t.id)}">Mark sent</button>
                  <button type="button" class="btn btn-outline btn-sm" data-act="payout-no" data-id="${esc(t.id)}">Reject</button>
                </span>` : ''}</td>
              </tr>`),
            'No send-out requests yet.')}</div>
        </section>`;
    },

    users() {
      const orders = Store.orders();
      return `
        <section class="card">
          <div class="section-head"><h2>Customers</h2></div>
          ${table('<th>Name</th><th>Contact</th><th>Joined</th><th class="num">Orders</th><th class="num">Naira balance</th>',
            Store.users().map((u) => `
              <tr>
                <td>${esc(u.name)} ${u.role === 'admin' ? '<span class="pill pill-blue">Admin</span>' : ''}</td>
                <td>${esc(u.email)}<br><span class="small muted">${esc(u.phone)}</span></td>
                <td class="small muted">${formatDate(u.createdAt)}</td>
                <td class="num">${orders.filter((o) => o.userId === u.id).length}</td>
                <td class="num">${money(u.balances.NGN)}</td>
              </tr>`),
            'No customers yet.')}
        </section>`;
    }
  };

  function render() {
    root.innerHTML = `
      <div class="row spread">
        <h1>Store admin</h1>
        <button type="button" class="btn btn-outline btn-sm" data-act="reset">Reset demo data</button>
      </div>
      <div class="tabs mt-16">
        ${TABS.map(([id, label]) => `<button type="button" data-tab="${id}" aria-pressed="${tab === id}">${label}</button>`).join('')}
      </div>
      <div id="admin-panel">${panels[tab]()}</div>`;
  }

  function productDialog(p) {
    const v = p || { name: '', cat: CATEGORIES[0].id, price: '', oldPrice: '', stock: '', ship: '7-15', desc: '', img: '' };
    const isUrl = /^https?:\/\//i.test(v.img || '');
    const dlg = openDialog(p ? 'Edit product' : 'Add product', `
      <form id="product-form" novalidate>
        <div class="form-grid cols-2">
          <label class="field full"><span>Product name</span><input name="name" required maxlength="120" value="${esc(v.name)}"></label>
          <label class="field"><span>Category</span>
            <select name="cat">${CATEGORIES.map((c) => `<option value="${c.id}"${c.id === v.cat ? ' selected' : ''}>${esc(c.name)}</option>`).join('')}</select>
          </label>
          <label class="field"><span>Stock</span><input name="stock" type="number" min="0" step="1" inputmode="numeric" required value="${esc(v.stock)}"></label>
          <label class="field"><span>Price (₦)</span><input name="price" type="number" min="1" step="any" inputmode="numeric" required value="${esc(v.price)}"></label>
          <label class="field"><span>Old price (₦)</span><input name="oldPrice" type="number" min="0" step="any" inputmode="numeric" value="${esc(v.oldPrice || '')}"><small class="hint">Optional, shows a discount</small></label>
          <label class="field full"><span>Delivery time in days</span><input name="ship" placeholder="7-15" value="${esc(v.ship)}"></label>
          <label class="field full"><span>Image link</span><input name="imgUrl" type="url" placeholder="https://" value="${isUrl ? esc(v.img) : ''}"></label>
          <label class="field full"><span>Or upload an image</span><input name="imgFile" type="file" accept="image/*"><small class="hint">Up to 300 KB, because the demo stores images in the browser</small></label>
          <label class="field full"><span>Description</span><textarea name="desc" maxlength="600">${esc(v.desc)}</textarea></label>
        </div>
        <p class="form-error" role="alert" hidden></p>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Save product</button><button class="btn btn-outline" type="button" data-close>Cancel</button></div>
      </form>`);

    const form = $('#product-form', dlg);
    const error = $('.form-error', form);
    let uploaded = '';

    form.elements.imgFile.addEventListener('change', (e) => {
      const file = e.target.files[0];
      uploaded = '';
      if (!file) return;
      if (file.size > 300 * 1024) {
        e.target.value = '';
        return showError(error, 'That image is over 300 KB. Pick a smaller one or use an image link.');
      }
      showError(error, '');
      const reader = new FileReader();
      reader.onload = () => { uploaded = String(reader.result); };
      reader.readAsDataURL(file);
    });

    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const d = Object.fromEntries(new FormData(form));
      const price = Number(d.price);
      const oldPrice = Number(d.oldPrice) || 0;
      const stock = Number(d.stock);
      if (!d.name.trim()) return showError(error, 'Enter a product name.');
      if (!(price > 0)) return showError(error, 'Enter a price above zero.');
      if (d.stock === '' || !Number.isInteger(stock) || stock < 0) return showError(error, 'Stock must be a whole number, 0 or more.');
      if (oldPrice && oldPrice <= price) return showError(error, 'The old price must be higher than the price, or leave it empty.');
      if (d.imgUrl && !/^https?:\/\//i.test(d.imgUrl)) return showError(error, 'The image link must start with http:// or https://');

      const res = Store.saveProduct({
        ...(p ? { id: p.id } : {}),
        name: d.name.trim(), cat: d.cat, price, oldPrice, stock,
        ship: d.ship.trim() || '7-15', desc: d.desc.trim(),
        img: uploaded || d.imgUrl.trim() || (isUrl ? '' : v.img || '')
      });
      if (!res.ok) return showError(error, res.error);
      dlg.close();
      toast('Product saved');
      render();
    });
  }

  root.addEventListener('click', (e) => {
    const tabBtn = e.target.closest('[data-tab]');
    if (tabBtn) {
      tab = tabBtn.dataset.tab;
      history.replaceState(null, '', '#' + tab);
      return render();
    }
    const btn = e.target.closest('[data-act]');
    if (!btn) return;
    const { act, id } = btn.dataset;

    if (act === 'add-product') productDialog(null);
    if (act === 'edit-product') productDialog(Store.product(id));
    if (act === 'delete-product' && confirm('Delete this product? This cannot be undone.')) {
      Store.deleteProduct(id);
      toast('Product deleted');
      render();
    }
    if (act === 'payout-ok' || act === 'payout-no') {
      Store.resolvePayout(id, act === 'payout-ok');
      toast(act === 'payout-ok' ? 'Marked as sent' : 'Rejected and refunded');
      render();
    }
    if (act === 'reset' && confirm('Erase all demo data in this browser (accounts, orders, products, rates) and start fresh?')) {
      Store.resetDemo();
      location.href = 'login.html';
    }
  });

  root.addEventListener('change', (e) => {
    const select = e.target.closest('[data-order]');
    if (!select) return;
    if (select.value === 'Cancelled' && !confirm('Cancel this order? Stock is returned and wallet payments are refunded.')) {
      return render();
    }
    Store.setOrderStatus(select.dataset.order, select.value);
    toast('Order updated');
    render();
  });

  root.addEventListener('submit', (e) => {
    if (e.target.id !== 'rates-form') return;
    e.preventDefault();
    const d = Object.fromEntries(new FormData(e.target));
    const next = Store.rates();
    const error = $('#rates-error');
    for (const code of Object.keys(next)) {
      const buy = Number(d[code + '_buy']);
      const sell = Number(d[code + '_sell']);
      if (!(buy > 0) || !(sell > 0)) return showError(error, `Enter both ${code} rates as numbers above zero.`);
      if (sell > buy) return showError(error, `${code}: the sell rate is above the buy rate, so you would lose money on every exchange.`);
      next[code] = { ...next[code], buy, sell };
    }
    Store.saveRates(next);
    showError(error, '');
    toast('Rates saved');
  });

  render();
})();
