mountChrome('admin');

(function () {
  const root = $('#admin-root');
  const me = Store.currentUser();

  if (!me || me.role !== 'admin') {
    root.innerHTML = `<div class="card empty">${icon('shield', 40)}<h1>Admins only</h1><p>Sign in with the store admin account to manage products, orders and rates.</p><a class="btn btn-primary" href="login.html?next=admin.html">Sign in</a></div>`;
    return;
  }

  const TABS = [
    ['overview', 'Overview'], ['products', 'Products'], ['categories', 'Categories'], ['orders', 'Orders'],
    ['messages', 'Messages'], ['agents', 'Agents'], ['users', 'Customers'], ['bulk', 'Business pricing'],
    ['rates', 'Rates'], ['payouts', 'Send-outs']
  ];
  const ICON_CHOICES = ['box', 'factory', 'flask', 'phone', 'monitor', 'cpu', 'shirt', 'sparkle', 'droplet', 'sofa', 'cup', 'bag', 'clock', 'smile', 'car', 'truck', 'tag', 'zap'];
  let tab = TABS.some(([id]) => id === location.hash.slice(1)) ? location.hash.slice(1) : 'overview';
  let thread = null; // customer whose messages are open

  const userName = (id) => (Store.users().find((u) => u.id === id) || { name: 'Deleted user' }).name;
  const table = (head, rows, emptyText) => (rows.length
    ? `<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`
    : `<p class="muted">${emptyText}</p>`);
  const businessUsers = () => Store.users().filter((u) => u.mode === 'business' || u.business);
  const unreadTotal = () => businessUsers().reduce((n, u) => n + Store.unseenFor(u.id, 'agent'), 0);

  const panels = {
    overview() {
      const orders = Store.orders();
      const live = orders.filter((o) => o.status !== 'Cancelled');
      const products = Store.products();
      const pending = Store.txns().filter((t) => t.type === 'payout' && t.status === 'processing').length;
      const verify = Store.users().filter((u) => u.verify && u.verify.status === 'pending').length;
      const low = products.filter((p) => p.stock <= 20).sort((a, b) => a.stock - b.stock);
      const stat = (label, value, go) => `<a class="stat" href="#${go}" data-tab="${go}"><span class="small muted">${label}</span><b>${value}</b></a>`;
      return `
        <div class="stats">
          ${stat('Sales', money(live.reduce((n, o) => n + o.total, 0)), 'orders')}
          ${stat('Open orders', live.filter((o) => o.stage < TRACK_STAGES.length - 1).length, 'orders')}
          ${stat('Business customers', businessUsers().length, 'users')}
          ${stat('Unread messages', unreadTotal(), 'messages')}
          ${stat('Selfies to check', verify, 'users')}
          ${stat('Send-outs waiting', pending, 'payouts')}
          ${stat('Products', products.length, 'products')}
          ${stat('Categories', Store.categories().length, 'categories')}
        </div>
        <section class="card section">
          <h2>Recent orders</h2>
          <div class="mt-12">${table('<th>Order</th><th>Customer</th><th>Status</th><th class="num">Total</th>',
            orders.slice(0, 5).map((o) => `<tr><td>${esc(o.id)}<br><span class="small muted">${formatDate(o.createdAt)}</span></td><td>${esc(userName(o.userId))}${o.mode === 'business' ? ' <span class="pill pill-blue">Business</span>' : ''}</td><td>${statusPill(o.status)}</td><td class="num">${money(o.total)}</td></tr>`),
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
          ${table('<th>Item</th><th>Name</th><th>Category</th><th class="num">Price</th><th class="num">Stock</th><th class="num">Business min.</th><th>Actions</th>',
            Store.products().map((p) => `
              <tr>
                <td><div class="thumb">${productThumb(p, 22)}</div></td>
                <td>${esc(p.name)}${p.condition === 'used' ? ' <span class="pill pill-amber">Used</span>' : ''}${p.gif ? ' <span class="pill pill-blue">GIF</span>' : ''}</td>
                <td>${esc(categoryOf(p.cat).name)}</td>
                <td class="num">${money(p.price)}</td>
                <td class="num">${p.stock}</td>
                <td class="num">${Store.bulkMin(p)}</td>
                <td><span class="row">
                  <button type="button" class="btn btn-outline btn-sm" data-act="edit-product" data-id="${esc(p.id)}">Edit</button>
                  <button type="button" class="btn btn-outline btn-sm" data-act="delete-product" data-id="${esc(p.id)}" aria-label="Delete ${esc(p.name)}">${icon('trash', 16)}</button>
                </span></td>
              </tr>`),
            'No products yet. Add your first one.')}
        </section>`;
    },

    categories() {
      const products = Store.products();
      return `
        <section class="card">
          <div class="section-head"><h2>Categories</h2><button type="button" class="btn btn-primary btn-sm" data-act="add-cat">${icon('plus', 16)} Add category</button></div>
          <p class="muted small">Categories show on the home page, the shop filters and the menu. Add products to a category from the Products tab, or straight from here.</p>
          <div class="mt-12">${table('<th>Picture</th><th>Name</th><th class="num">Products</th><th>Actions</th>',
            Store.categories().map((c) => `
              <tr>
                <td><span class="cat-mini" style="--h:${c.hue}">${categoryArt(c, 20)}</span></td>
                <td>${esc(c.name)}</td>
                <td class="num">${products.filter((p) => p.cat === c.id).length}</td>
                <td><span class="row">
                  <button type="button" class="btn btn-soft btn-sm" data-act="add-product" data-cat="${esc(c.id)}">${icon('plus', 16)} Add listing</button>
                  <button type="button" class="btn btn-outline btn-sm" data-act="edit-cat" data-id="${esc(c.id)}">Edit</button>
                  <button type="button" class="btn btn-outline btn-sm" data-act="delete-cat" data-id="${esc(c.id)}" aria-label="Delete ${esc(c.name)}">${icon('trash', 16)}</button>
                </span></td>
              </tr>`),
            'No categories yet.')}</div>
        </section>`;
    },

    orders() {
      return `
        <section class="card">
          <div class="section-head"><h2>Orders</h2></div>
          <p class="muted small">Move each order along the tracker as it happens. Customers see every step on their order page.</p>
          <div class="mt-12">${table('<th>Order</th><th>Customer</th><th>Items</th><th>Payment</th><th class="num">Total</th><th>Tracker step</th>',
            Store.orders().map((o) => `
              <tr>
                <td>${esc(o.id)}<br><span class="small muted">${formatDate(o.createdAt)}</span>${o.mode === 'business' ? '<br><span class="pill pill-blue">Business</span>' : ''}</td>
                <td>${esc(o.address.name)}<br><span class="small muted">${esc(o.address.phone)} · ${esc(o.address.city)}, ${esc(o.address.state)}</span></td>
                <td class="small">${o.items.map((it, i) => `${it.qty} × ${esc(it.name)}${it.custom ? ` <button type="button" class="linkish" data-act="view-custom" data-id="${esc(o.id)}" data-i="${i}">${icon('wand', 14)} ${it.custom.pieces} customised</button>` : ''}`).join('<br>')}</td>
                <td>${o.pay === 'wallet' ? 'Wallet (paid)' : 'On delivery'}</td>
                <td class="num">${money(o.total)}</td>
                <td>${o.status === 'Cancelled' ? statusPill(o.status) : `
                  <select class="input" data-order="${esc(o.id)}" aria-label="Tracker step for ${esc(o.id)}">
                    ${TRACK_STAGES.map((s, i) => `<option value="${i}"${i === o.stage ? ' selected' : ''}>${i + 1}. ${esc(s.name)}</option>`).join('')}
                    <option value="cancel">Cancel order</option>
                  </select>`}</td>
              </tr>`),
            'No orders yet.')}</div>
        </section>`;
    },

    messages() {
      const list = businessUsers()
        .map((u) => ({ u, msgs: Store.threadOf(u.id) }))
        .sort((a, b) => ((b.msgs.at(-1) || {}).at || 0) - ((a.msgs.at(-1) || {}).at || 0));
      if (!list.length) return '<section class="card"><h2>Messages</h2><p class="muted mt-12">No business customers yet. Their chats with agents show up here.</p></section>';
      if (!thread || !list.some((x) => x.u.id === thread)) thread = list[0].u.id;
      const cur = list.find((x) => x.u.id === thread);
      const a = Store.agent(cur.u.agentId);
      Store.markSeen(thread, 'agent');
      return `
        <div class="inbox">
          <section class="card inbox-list">
            <h2>Chats</h2>
            <ul class="mt-12">
              ${list.map(({ u, msgs }) => {
                const last = msgs.at(-1);
                const unread = Store.unseenFor(u.id, 'agent');
                return `<li><button type="button" data-thread="${esc(u.id)}" aria-pressed="${u.id === thread}">
                  <b>${esc(u.name)}</b>${unread ? `<span class="count">${unread}</span>` : ''}
                  <span class="small muted">${esc((u.business || {}).name || '')} · ${esc((Store.agent(u.agentId) || { name: 'No agent' }).name)}</span>
                  <span class="small">${last ? esc(last.text.slice(0, 60)) : 'No messages yet'}</span>
                </button></li>`;
              }).join('')}
            </ul>
          </section>
          <section class="card chat">
            <div class="chat-head">
              <span class="avatar">${esc(cur.u.name.charAt(0))}</span>
              <div><h2>${esc(cur.u.name)}</h2><span class="small muted">${esc((cur.u.business || {}).name || '')} · replying as ${a ? esc(a.name) : 'the team'}</span></div>
              ${cur.u.whatsapp ? `<a class="btn btn-outline btn-sm" href="${esc(waLink(cur.u.whatsapp))}" target="_blank" rel="noopener">${icon('whatsapp', 16)} WhatsApp</a>` : ''}
            </div>
            <div class="chat-log" id="admin-log">
              ${cur.msgs.length ? cur.msgs.map((m) => `<div class="msg msg-${m.from === 'agent' ? 'me' : 'them'}"><p>${esc(m.text)}</p><time>${formatDate(m.at)}</time></div>`).join('') : '<p class="muted small chat-empty">No messages yet.</p>'}
            </div>
            <form class="chat-form" id="admin-chat">
              <input name="text" autocomplete="off" maxlength="1000" placeholder="Reply to ${esc(cur.u.name.split(' ')[0])}" aria-label="Reply">
              <button class="btn btn-primary" type="submit" aria-label="Send">${icon('send', 18)}</button>
            </form>
          </section>
        </div>`;
    },

    agents() {
      const users = Store.users();
      return `
        <section class="card">
          <div class="section-head"><h2>Agents</h2><button type="button" class="btn btn-primary btn-sm" data-act="add-agent">${icon('plus', 16)} Add agent</button></div>
          <p class="muted small">Each business customer gets the least busy agent when they switch to business. You can move customers between agents on the Customers tab.</p>
          <div class="mt-12">${table('<th>Name</th><th>Phone / WhatsApp</th><th class="num">Customers</th><th>Actions</th>',
            Store.agents().map((a) => `
              <tr>
                <td><b>${esc(a.name)}</b></td>
                <td>${esc(a.phone || '')}<br><span class="small muted">wa.me/${esc(a.whatsapp || '')}</span></td>
                <td class="num">${users.filter((u) => u.agentId === a.id).length}</td>
                <td><span class="row">
                  <button type="button" class="btn btn-outline btn-sm" data-act="edit-agent" data-id="${esc(a.id)}">Edit</button>
                  <button type="button" class="btn btn-outline btn-sm" data-act="delete-agent" data-id="${esc(a.id)}" aria-label="Remove ${esc(a.name)}">${icon('trash', 16)}</button>
                </span></td>
              </tr>`),
            'No agents yet. Add one so business customers have someone to talk to.')}</div>
        </section>`;
    },

    users() {
      const orders = Store.orders();
      const agents = Store.agents();
      return `
        <section class="card">
          <div class="section-head"><h2>Customers</h2></div>
          ${table('<th>Name</th><th>Contact</th><th>Buying as</th><th>Agent</th><th>Identity</th><th class="num">Orders</th><th class="num">Naira balance</th>',
            Store.users().map((u) => {
              const v = (u.verify || {}).status;
              return `
              <tr>
                <td>${esc(u.name)} ${u.role === 'admin' ? '<span class="pill pill-blue">Admin</span>' : ''}<br><span class="small muted">Joined ${formatDate(u.createdAt)}</span></td>
                <td>${esc(u.email)}<br><span class="small muted">${esc(u.phone)}${u.whatsapp && u.whatsapp !== u.phone ? ' · WA ' + esc(u.whatsapp) : ''}</span></td>
                <td>${u.mode === 'business' ? `<span class="pill pill-blue">Business</span><br><span class="small">${esc(u.business.name)}</span><br><span class="small muted">${esc((Store.businessType(u.business.type) || { name: '' }).name)}</span>` : '<span class="pill pill-grey">Personal</span>'}</td>
                <td>${u.business ? `<select class="input" data-agent-for="${esc(u.id)}" aria-label="Agent for ${esc(u.name)}">
                  <option value="">None</option>${agents.map((a) => `<option value="${a.id}"${a.id === u.agentId ? ' selected' : ''}>${esc(a.name)}</option>`).join('')}
                </select>` : '<span class="muted small">—</span>'}</td>
                <td>${v === 'pending' ? `
                  <img class="selfie" src="${esc(u.verify.selfie)}" alt="Selfie from ${esc(u.name)}">
                  <span class="row"><button type="button" class="btn btn-primary btn-sm" data-act="verify-ok" data-id="${esc(u.id)}">Verify</button><button type="button" class="btn btn-outline btn-sm" data-act="verify-no" data-id="${esc(u.id)}">Reject</button></span>`
                  : v ? statusPill(v) : '<span class="muted small">Not sent</span>'}</td>
                <td class="num">${orders.filter((o) => o.userId === u.id).length}</td>
                <td class="num">${money(u.balances.NGN)}</td>
              </tr>`;
            }),
            'No customers yet.')}
        </section>`;
    },

    bulk() {
      const r = Store.bulk();
      const rows = [...r.tiers, { from: '', off: '' }, { from: '', off: '' }];
      return `
        <form class="card" id="bulk-form" novalidate>
          <div class="section-head"><h2>Business pricing</h2></div>
          <p class="muted small">Business customers must buy at least the minimum of each item. Discounts apply per item: for example "50 pieces, 10%" means 50 or more of the same item cost 10% less each. You can also set a different minimum on any product (useful for cars).</p>
          <label class="field mt-16" style="max-width:240px"><span>Default minimum per item</span><input name="minQty" type="number" min="1" step="1" inputmode="numeric" value="${r.minQty}"></label>
          <div class="table-wrap mt-16">
            <table>
              <thead><tr><th>From (pieces)</th><th>Discount (%)</th></tr></thead>
              <tbody>
                ${rows.map((t, i) => `
                  <tr>
                    <td><input class="input" name="from${i}" type="number" min="1" step="1" inputmode="numeric" value="${t.from}" aria-label="Tier ${i + 1} from"></td>
                    <td><input class="input" name="off${i}" type="number" min="0" max="90" step="0.5" inputmode="decimal" value="${t.off}" aria-label="Tier ${i + 1} discount"></td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>
          <p class="small muted mt-12">Leave a row empty to remove it.</p>
          <p class="form-error" id="bulk-error" role="alert" hidden></p>
          <div class="form-actions"><button class="btn btn-primary" type="submit">Save business pricing</button></div>
        </form>`;
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
    }
  };

  function render() {
    // Build the panel first: opening a chat marks its messages as read, which changes the count.
    const panel = panels[tab]();
    const unread = unreadTotal();
    root.innerHTML = `
      <div class="row spread">
        <h1>Store admin</h1>
        <button type="button" class="btn btn-outline btn-sm" data-act="reset">Reset demo data</button>
      </div>
      <div class="tabs mt-16">
        ${TABS.map(([id, label]) => `<button type="button" data-tab="${id}" aria-pressed="${tab === id}">${label}${id === 'messages' && unread ? ` <span class="count count-inline">${unread}</span>` : ''}</button>`).join('')}
      </div>
      <div id="admin-panel">${panel}</div>`;
    const log = $('#admin-log');
    if (log) log.scrollTop = log.scrollHeight;
  }

  /* ---------- dialogs ---------- */

  function productDialog(p, presetCat) {
    const cats = Store.categories();
    const v = p || { name: '', cat: presetCat || (cats[0] || {}).id, condition: 'new', price: '', oldPrice: '', stock: '', bulkMin: '', ship: '7-15', desc: '', img: '', gif: '' };
    const isUrl = /^https?:\/\//i.test(v.img || '');
    const gifUrl = /^https?:\/\//i.test(v.gif || '');
    const dlg = openDialog(p ? 'Edit product' : 'Add product', `
      <form id="product-form" novalidate>
        <div class="form-grid cols-2">
          <label class="field full"><span>Product name</span><input name="name" required maxlength="120" value="${esc(v.name)}"></label>
          <label class="field"><span>Category</span>
            <select name="cat">${cats.map((c) => `<option value="${c.id}"${c.id === v.cat ? ' selected' : ''}>${esc(c.name)}</option>`).join('')}</select>
          </label>
          <label class="field"><span>Condition</span>
            <select name="condition"><option value="new"${v.condition !== 'used' ? ' selected' : ''}>Brand new</option><option value="used"${v.condition === 'used' ? ' selected' : ''}>Used</option></select>
          </label>
          <label class="field"><span>Price (₦)</span><input name="price" type="number" min="1" step="any" inputmode="numeric" required value="${esc(v.price)}"><small class="hint">Retail price. Business buyers get the bulk discount off this.</small></label>
          <label class="field"><span>Old price (₦)</span><input name="oldPrice" type="number" min="0" step="any" inputmode="numeric" value="${esc(v.oldPrice || '')}"><small class="hint">Optional, shows a discount</small></label>
          <label class="field"><span>Stock</span><input name="stock" type="number" min="0" step="1" inputmode="numeric" required value="${esc(v.stock)}"></label>
          <label class="field"><span>Business minimum</span><input name="bulkMin" type="number" min="1" step="1" inputmode="numeric" placeholder="${Store.bulk().minQty} (default)" value="${esc(v.bulkMin || '')}"><small class="hint">Leave empty to use the default</small></label>
          <label class="field full"><span>Delivery time in days</span><input name="ship" placeholder="7-15" value="${esc(v.ship)}"></label>
          <label class="field full"><span>Image link</span><input name="imgUrl" type="url" placeholder="https://" value="${isUrl ? esc(v.img) : ''}"></label>
          <label class="field full"><span>Or upload an image</span><input name="imgFile" type="file" accept="image/*"><small class="hint">It is resized to fit the demo's browser storage</small></label>
          <label class="field full"><span>Product GIF (moving view)</span><input name="gifUrl" type="url" placeholder="https:// link to a .gif" value="${gifUrl ? esc(v.gif) : ''}"></label>
          <label class="field full"><span>Or upload a GIF</span><input name="gifFile" type="file" accept="image/gif"><small class="hint">Under 900 KB. Shows first in the product's photos.${v.gif ? ' <label><input type="checkbox" name="gifRemove"> Remove the current GIF</label>' : ''}</small></label>
          <label class="field full"><span>Description</span><textarea name="desc" maxlength="600">${esc(v.desc)}</textarea></label>
        </div>
        <p class="form-error" role="alert" hidden></p>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Save product</button><button class="btn btn-outline" type="button" data-close>Cancel</button></div>
      </form>`);

    const form = $('#product-form', dlg);
    const error = $('.form-error', form);
    const uploads = { img: '', gif: '' };
    const pick = (field, key, ...args) => form.elements[field].addEventListener('change', async (e) => {
      uploads[key] = '';
      if (!e.target.files[0]) return;
      try {
        uploads[key] = await readImage(e.target.files[0], ...args);
        showError(error, '');
      } catch (err) {
        e.target.value = '';
        showError(error, err.message);
      }
    });
    pick('imgFile', 'img', 700);
    pick('gifFile', 'gif');

    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const d = Object.fromEntries(new FormData(form));
      const price = Number(d.price);
      const oldPrice = Number(d.oldPrice) || 0;
      const stock = Number(d.stock);
      const bulkMin = Number(d.bulkMin) || 0;
      if (!d.name.trim()) return showError(error, 'Enter a product name.');
      if (!d.cat) return showError(error, 'Add a category first, on the Categories tab.');
      if (!(price > 0)) return showError(error, 'Enter a price above zero.');
      if (d.stock === '' || !Number.isInteger(stock) || stock < 0) return showError(error, 'Stock must be a whole number, 0 or more.');
      if (d.bulkMin && !(Number.isInteger(bulkMin) && bulkMin >= 1)) return showError(error, 'Business minimum must be a whole number, 1 or more.');
      if (oldPrice && oldPrice <= price) return showError(error, 'The old price must be higher than the price, or leave it empty.');
      if (d.imgUrl && !/^https?:\/\//i.test(d.imgUrl)) return showError(error, 'The image link must start with http:// or https://');
      if (d.gifUrl && !/^https?:\/\//i.test(d.gifUrl)) return showError(error, 'The GIF link must start with http:// or https://');

      const res = Store.saveProduct({
        ...(p ? { id: p.id } : {}),
        name: d.name.trim(), cat: d.cat, condition: d.condition, price, oldPrice, stock, bulkMin,
        ship: d.ship.trim() || '7-15', desc: d.desc.trim(),
        img: uploads.img || d.imgUrl.trim() || (isUrl ? '' : v.img || ''),
        gif: d.gifRemove ? '' : uploads.gif || d.gifUrl.trim() || (gifUrl ? '' : v.gif || '')
      });
      if (!res.ok) return showError(error, res.error);
      dlg.close();
      toast('Product saved');
      render();
    });
  }

  function categoryDialog(c) {
    const v = c || { name: '', icon: 'box', hue: Math.floor(Math.random() * 360), img: '' };
    const dlg = openDialog(c ? 'Edit category' : 'Add category', `
      <form id="cat-form" novalidate>
        <label class="field"><span>Name</span><input name="name" required maxlength="40" value="${esc(v.name)}"></label>
        <div class="field">
          <span>Icon</span>
          <div class="icon-pick">${ICON_CHOICES.map((n) => `<label><input type="radio" name="icon" value="${n}"${n === v.icon ? ' checked' : ''}><span>${icon(n, 22)}</span></label>`).join('')}</div>
        </div>
        <label class="field"><span>Colour</span><input name="hue" type="range" min="0" max="359" value="${v.hue}"></label>
        <label class="field"><span>Picture (optional)</span><input name="imgFile" type="file" accept="image/*"><small class="hint">Shown in the category circle on the home page. Without one, the icon is used.${v.img ? ' <label><input type="checkbox" name="imgRemove"> Remove the current picture</label>' : ''}</small></label>
        <div class="cat-preview"><span class="cat-mini" id="cat-pv" style="--h:${v.hue}">${categoryArt(v, 24)}</span></div>
        <p class="form-error" role="alert" hidden></p>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Save category</button><button class="btn btn-outline" type="button" data-close>Cancel</button></div>
      </form>`);
    const form = $('#cat-form', dlg);
    const error = $('.form-error', form);
    let upload = '';
    const pv = () => {
      const d = Object.fromEntries(new FormData(form));
      $('#cat-pv', dlg).style.setProperty('--h', d.hue);
      $('#cat-pv', dlg).innerHTML = categoryArt({ icon: d.icon, img: d.imgRemove ? '' : upload || v.img }, 24);
    };
    form.addEventListener('input', pv);
    form.elements.imgFile.addEventListener('change', async (e) => {
      try { upload = await readImage(e.target.files[0], 300, 'image/png'); pv(); showError(error, ''); } catch (err) { showError(error, err.message); }
    });
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const d = Object.fromEntries(new FormData(form));
      const res = Store.saveCategory({ ...(c ? { id: c.id } : {}), name: d.name, icon: d.icon, hue: Number(d.hue), img: d.imgRemove ? '' : upload || v.img || '' });
      if (!res.ok) return showError(error, res.error);
      dlg.close();
      toast('Category saved');
      render();
    });
  }

  function agentDialog(a) {
    const v = a || { name: '', phone: '', whatsapp: '' };
    const dlg = openDialog(a ? 'Edit agent' : 'Add agent', `
      <form id="agent-form" novalidate>
        <label class="field"><span>Name customers see</span><input name="name" required maxlength="40" value="${esc(v.name)}"></label>
        <label class="field"><span>Phone</span><input name="phone" type="tel" value="${esc(v.phone)}"></label>
        <label class="field"><span>WhatsApp number</span><input name="whatsapp" type="tel" placeholder="2348012345678" value="${esc(v.whatsapp)}"><small class="hint">With country code, no + or spaces</small></label>
        <p class="form-error" role="alert" hidden></p>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Save agent</button><button class="btn btn-outline" type="button" data-close>Cancel</button></div>
      </form>`);
    $('#agent-form', dlg).addEventListener('submit', (e) => {
      e.preventDefault();
      const d = Object.fromEntries(new FormData(e.target));
      if (!d.name.trim()) return showError($('.form-error', dlg), 'Enter the agent\'s name.');
      Store.saveAgent({ ...(a ? { id: a.id } : {}), name: d.name.trim(), phone: d.phone.trim(), whatsapp: d.whatsapp.replace(/\D/g, '') });
      dlg.close();
      toast('Agent saved');
      render();
    });
  }

  function customDialog(o, it) {
    const c = it.custom;
    openDialog(`Custom design: ${it.name}`, `
      <div class="custom-view">
        ${c.preview ? `<figure><img src="${esc(c.preview)}" alt="Design preview"><figcaption class="small muted">Preview</figcaption></figure>` : ''}
        ${c.logo ? `<figure><img src="${esc(c.logo)}" alt="Customer logo"><figcaption class="small muted"><a href="${esc(c.logo)}" download="${esc(o.id)}-logo.png">Download logo</a></figcaption></figure>` : ''}
      </div>
      <dl class="summary mt-12">
        <div class="sum-row"><dt>Order</dt><dd>${esc(o.id)}</dd></div>
        <div class="sum-row"><dt>Pieces to customise</dt><dd>${c.pieces} of ${it.qty}</dd></div>
        ${c.tint ? `<div class="sum-row"><dt>Product colour</dt><dd><span class="swatch-dot" style="background:${esc(c.tint)}"></span> ${esc(c.tint)}</dd></div>` : ''}
      </dl>
      ${c.notes ? `<p class="mt-12"><b>Notes:</b> ${esc(c.notes)}</p>` : ''}`);
  }

  /* ---------- events ---------- */

  root.addEventListener('click', (e) => {
    const tabBtn = e.target.closest('[data-tab]');
    if (tabBtn) {
      e.preventDefault();
      tab = tabBtn.dataset.tab;
      history.replaceState(null, '', '#' + tab);
      return render();
    }
    const threadBtn = e.target.closest('[data-thread]');
    if (threadBtn) { thread = threadBtn.dataset.thread; return render(); }

    const btn = e.target.closest('[data-act]');
    if (!btn) return;
    const { act, id } = btn.dataset;

    if (act === 'add-product') productDialog(null, btn.dataset.cat);
    if (act === 'edit-product') productDialog(Store.product(id));
    if (act === 'delete-product' && confirm('Delete this product? This cannot be undone.')) {
      Store.deleteProduct(id);
      toast('Product deleted');
      render();
    }
    if (act === 'add-cat') categoryDialog(null);
    if (act === 'edit-cat') categoryDialog(Store.categories().find((c) => c.id === id));
    if (act === 'delete-cat' && confirm('Delete this category?')) {
      const res = Store.deleteCategory(id);
      toast(res.ok ? 'Category deleted' : res.error, res.ok ? 'ok' : 'error');
      render();
    }
    if (act === 'add-agent') agentDialog(null);
    if (act === 'edit-agent') agentDialog(Store.agent(id));
    if (act === 'delete-agent' && confirm('Remove this agent? Their customers move to another agent.')) {
      Store.deleteAgent(id);
      toast('Agent removed');
      render();
    }
    if (act === 'verify-ok' || act === 'verify-no') {
      Store.setVerification(id, act === 'verify-ok' ? 'verified' : 'rejected');
      toast(act === 'verify-ok' ? 'Customer verified' : 'Selfie rejected');
      render();
    }
    if (act === 'view-custom') {
      const o = Store.order(id);
      if (o) customDialog(o, o.items[Number(btn.dataset.i)]);
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
    if (select) {
      if (select.value === 'cancel') {
        if (!confirm('Cancel this order? Stock is returned and wallet payments are refunded.')) return render();
        Store.cancelOrder(select.dataset.order);
        toast('Order cancelled');
      } else {
        Store.setOrderStage(select.dataset.order, select.value);
        toast('Tracker updated');
      }
      return render();
    }
    const agentSel = e.target.closest('[data-agent-for]');
    if (agentSel) {
      Store.updateUser(agentSel.dataset.agentFor, { agentId: agentSel.value || null });
      toast('Agent updated');
      render();
    }
  });

  root.addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.target;
    const d = Object.fromEntries(new FormData(form));

    if (form.id === 'admin-chat') {
      if (Store.sendMessage(thread, 'agent', d.text)) render();
      return;
    }

    if (form.id === 'bulk-form') {
      const error = $('#bulk-error');
      const minQty = Number(d.minQty);
      if (!(Number.isInteger(minQty) && minQty >= 1)) return showError(error, 'The minimum must be a whole number, 1 or more.');
      const tiers = [];
      for (let i = 0; d['from' + i] !== undefined; i++) {
        if (d['from' + i] === '' && d['off' + i] === '') continue;
        const from = Number(d['from' + i]);
        const off = Number(d['off' + i]);
        if (!(Number.isInteger(from) && from >= 1) || !(off >= 0 && off <= 90)) return showError(error, `Row ${i + 1}: pieces must be a whole number and the discount between 0 and 90.`);
        tiers.push({ from, off });
      }
      tiers.sort((a, b) => a.from - b.from);
      Store.saveBulk({ minQty, tiers });
      showError(error, '');
      toast('Business pricing saved');
      return render();
    }

    if (form.id === 'rates-form') {
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
    }
  });

  // New customer messages from another tab.
  addEventListener('storage', (e) => { if (e.key === 'mp_messages' && tab === 'messages') render(); });

  render();
})();
