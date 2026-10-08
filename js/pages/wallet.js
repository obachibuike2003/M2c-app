mountChrome('wallet');

(function () {
  if (!requireLogin()) return;

  const root = $('#wallet-root');
  const signed = (n, code) => (n < 0 ? '-' : '+') + money(Math.abs(n), code);

  function txnAmount(t) {
    if (t.type === 'exchange') {
      return `<span class="amt-out">${signed(t.amount, t.currency)}</span><br><span class="amt-in">${signed(t.gotAmount, t.gotCurrency)}</span>`;
    }
    return `<span class="${t.amount < 0 ? 'amt-out' : 'amt-in'}">${signed(t.amount, t.currency)}</span>`;
  }

  // Naira balance counts up or down from the last value shown.
  let shownBalance = 0;

  function render() {
    const user = Store.currentUser();
    const rates = Store.rates();
    const txns = Store.userTxns(user.id);

    root.innerHTML = `
      <div class="row spread">
        <div><h1>Hi, ${esc(user.name.split(' ')[0])}</h1><span class="muted small">${esc(user.email)}</span></div>
        <div class="row">
          ${user.role === 'admin' ? `<a class="btn btn-outline btn-sm" href="admin.html">${icon('settings', 16)} Admin panel</a>` : ''}
          <button type="button" class="btn btn-outline btn-sm" data-act="logout">${icon('logout', 16)} Sign out</button>
        </div>
      </div>

      <section class="card balance-main mt-16" aria-label="Naira balance">
        <span class="label">Naira balance</span>
        <div class="balance-amount" id="balance-amount">${money(shownBalance)}</div>
        <div class="row mt-16">
          <button type="button" class="btn btn-white" data-act="fund">${icon('plus', 18)} Add money</button>
          <a class="btn btn-ghost-white" href="exchange.html">${icon('swap', 18)} Exchange</a>
          <button type="button" class="btn btn-ghost-white" data-act="send">Send out</button>
        </div>
      </section>

      <section class="section" aria-labelledby="bal-h">
        <div class="section-head"><h2 id="bal-h">Yuan and crypto</h2><a href="exchange.html">Exchange</a></div>
        <div class="balances">
          ${Object.keys(rates).map((c) => `
            <a class="bal" href="exchange.html?asset=${c}">
              <span class="coin-dot">${c}</span>
              <span class="small muted">${esc(rates[c].name)}</span>
              <b>${money(user.balances[c] || 0, c)}</b>
            </a>`).join('')}
        </div>
      </section>

      <section class="section card" aria-labelledby="txn-h">
        <h2 id="txn-h">Transactions</h2>
        ${txns.length ? `
          <div class="table-wrap mt-12">
            <table class="table-cards txn-table">
              <thead><tr><th>Date</th><th>Details</th><th>Status</th><th class="num">Amount</th></tr></thead>
              <tbody>
                ${txns.map((t) => `
                  <tr>
                    <td class="small muted">${formatDate(t.createdAt)}</td>
                    <td>${esc(t.desc)}</td>
                    <td>${statusPill(t.status)}</td>
                    <td class="num">${txnAmount(t)}</td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>` : '<p class="muted mt-12">Nothing yet. Add money to get started.</p>'}
      </section>`;

    const amount = $('#balance-amount');
    amount._value = shownBalance;
    animateNumber(amount, user.balances.NGN, (n) => money(n === user.balances.NGN ? n : Math.round(n)), 900);
    shownBalance = user.balances.NGN;
  }

  function fundDialog() {
    const dlg = openDialog('Add money', `
      <form id="fund-form" novalidate>
        <p class="notice">Demo: the money is added instantly. The live site would take a bank transfer or card payment here.</p>
        <label class="field mt-16"><span>Amount (₦)</span><input name="amount" type="number" inputmode="numeric" min="100" step="100" required></label>
        <div class="row mt-12">
          ${[5000, 20000, 100000, 500000].map((n) => `<button type="button" class="chip" data-quick="${n}">${money(n)}</button>`).join('')}
        </div>
        <p class="form-error" role="alert" hidden></p>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Add money</button><button class="btn btn-outline" type="button" data-close>Cancel</button></div>
      </form>`);
    const form = $('#fund-form', dlg);
    form.addEventListener('click', (e) => {
      const quick = e.target.closest('[data-quick]');
      if (quick) form.elements.amount.value = quick.dataset.quick;
    });
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const res = Store.fundWallet(form.elements.amount.value);
      if (!res.ok) return showError($('.form-error', form), res.error);
      dlg.close();
      toast('Money added to your wallet');
      render();
    });
    form.elements.amount.focus();
  }

  function sendDialog() {
    const user = Store.currentUser();
    const rates = Store.rates();
    const codes = ['NGN', ...Object.keys(rates)];
    const destLabel = (code) => {
      if (code === 'NGN') return ['Bank account', 'Bank name and account number'];
      if (code === 'CNY') return ['Alipay, WeChat or bank card', 'Account name and number or ID'];
      return ['Wallet address', 'Include the network, for example TRC20'];
    };
    const dlg = openDialog('Send out', `
      <form id="send-form" novalidate>
        <label class="field"><span>Send from</span>
          <select name="code">${codes.map((c) => `<option value="${c}">${c} (${money(user.balances[c] || 0, c)})</option>`).join('')}</select>
        </label>
        <label class="field"><span>Amount</span><input name="amount" type="number" inputmode="decimal" min="0" step="any" required></label>
        <label class="field"><span id="dest-label"></span><input name="dest" required><small class="hint" id="dest-hint"></small></label>
        <p class="hint">The amount is held from your balance and released once the store confirms the transfer.</p>
        <p class="form-error" role="alert" hidden></p>
        <div class="form-actions"><button class="btn btn-primary" type="submit">Send</button><button class="btn btn-outline" type="button" data-close>Cancel</button></div>
      </form>`);
    const form = $('#send-form', dlg);
    const syncLabel = () => {
      const [label, hint] = destLabel(form.elements.code.value);
      $('#dest-label', form).textContent = label;
      $('#dest-hint', form).textContent = hint;
    };
    form.elements.code.addEventListener('change', syncLabel);
    syncLabel();
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const res = Store.requestPayout(form.elements.code.value, form.elements.amount.value, form.elements.dest.value);
      if (!res.ok) return showError($('.form-error', form), res.error);
      dlg.close();
      toast('Sent for processing');
      render();
    });
  }

  root.addEventListener('click', (e) => {
    const act = e.target.closest('[data-act]');
    if (!act) return;
    if (act.dataset.act === 'fund') fundDialog();
    if (act.dataset.act === 'send') sendDialog();
    if (act.dataset.act === 'logout') {
      Store.logout();
      location.href = 'index.html';
    }
  });

  render();
})();
