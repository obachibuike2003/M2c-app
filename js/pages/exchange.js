// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('exchange');

(function () {
  const root = $('#fx-root');
  const rates = Store.rates();
  const codes = Object.keys(rates);
  const wanted = new URLSearchParams(location.search).get('asset');
  // mode "buy" = naira to asset, "sell" = asset to naira
  const state = { mode: 'buy', asset: codes.includes(wanted) ? wanted : 'CNY', amount: '' };

  const pair = () => (state.mode === 'buy' ? { from: 'NGN', to: state.asset } : { from: state.asset, to: 'NGN' });

  function update() {
    const user = Store.currentUser();
    const { from, to } = pair();
    const r = rates[state.asset];
    $('#fx-out').textContent = money(Store.quote(from, to, state.amount), to);
    $('#fx-rate').textContent = `1 ${state.asset} = ${money(state.mode === 'buy' ? r.buy : r.sell)}`;
    $('#fx-balance').innerHTML = user
      ? `Balance: ${money(user.balances[from] || 0, from)} <button type="button" class="btn btn-outline btn-sm" id="fx-max">Use all</button>`
      : '';
  }

  function renderForm() {
    const user = Store.currentUser();
    const { from, to } = pair();
    const select = `<select id="fx-asset" aria-label="Currency">${codes.map((c) => `<option value="${c}"${c === state.asset ? ' selected' : ''}>${c}</option>`).join('')}</select>`;
    const naira = '<span class="fx-code">NGN</span>';

    root.innerHTML = `
      <div class="tabs">
        <button type="button" data-mode="buy" aria-pressed="${state.mode === 'buy'}">Buy with naira</button>
        <button type="button" data-mode="sell" aria-pressed="${state.mode === 'sell'}">Sell for naira</button>
      </div>
      <form id="fx-form" novalidate>
        <div class="fx-box">
          <label for="fx-amount">You pay</label>
          <div class="fx-line">
            <input id="fx-amount" type="number" inputmode="decimal" min="0" step="any" placeholder="0" value="${esc(state.amount)}">
            ${from === 'NGN' ? naira : select}
          </div>
        </div>
        <div class="fx-swap"><button type="button" id="fx-swap" aria-label="Swap direction">${icon('swap')}</button></div>
        <div class="fx-box">
          <span class="label">You receive</span>
          <div class="fx-line">
            <output id="fx-out" for="fx-amount" aria-live="polite"></output>
            ${to === 'NGN' ? naira : select}
          </div>
        </div>
        <div class="row spread small muted mt-12"><span id="fx-rate"></span><span id="fx-balance" class="row"></span></div>
        <p class="form-error" id="fx-error" role="alert" hidden></p>
        <button class="btn btn-primary btn-block mt-16" type="submit">${user ? `Exchange ${from} to ${to}` : 'Sign in to exchange'}</button>
      </form>`;
    update();
  }

  function renderSide() {
    const user = Store.currentUser();
    const side = $('#fx-side');
    if (!user) {
      side.innerHTML = `
        <h2>How it works</h2>
        <ul class="facts mt-12">
          <li>${icon('check', 18)}<span>Create an account and add naira to your wallet</span></li>
          <li>${icon('check', 18)}<span>Exchange naira to yuan (RMB) or crypto at the rate shown</span></li>
          <li>${icon('check', 18)}<span>Send it out to Alipay, WeChat, a bank or a crypto address</span></li>
        </ul>
        <a class="btn btn-primary btn-block mt-16" href="login.html?next=exchange.html">Sign in or create account</a>`;
      return;
    }
    const held = codes.filter((c) => user.balances[c] > 0);
    side.innerHTML = `
      <h2>Your wallet</h2>
      <ul class="rate-list mt-12">
        <li><span>Naira</span><b class="num">${money(user.balances.NGN)}</b></li>
        ${held.map((c) => `<li><span>${esc(rates[c].name)}</span><b class="num">${money(user.balances[c], c)}</b></li>`).join('')}
      </ul>
      <a class="btn btn-outline btn-block mt-16" href="wallet.html">Open wallet</a>`;
  }

  $('#rates-table').innerHTML = `
    <table class="table-cards rates-table">
      <thead><tr><th>Currency</th><th class="num">You buy at</th><th class="num">You sell at</th><th><span class="muted">Action</span></th></tr></thead>
      <tbody>
        ${codes.map((c) => `
          <tr>
            <td><span class="coin"><span class="coin-dot">${c}</span><span><b>${esc(rates[c].name)}</b><small>1 ${c}</small></span></span></td>
            <td class="num" data-label="You buy at">${money(rates[c].buy)}</td>
            <td class="num" data-label="You sell at">${money(rates[c].sell)}</td>
            <td><button type="button" class="btn btn-soft btn-sm" data-pick="${c}">Exchange</button></td>
          </tr>`).join('')}
      </tbody>
    </table>`;

  $('#rates-table').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-pick]');
    if (!btn) return;
    state.asset = btn.dataset.pick;
    renderForm();
    root.scrollIntoView({ block: 'center' });
    $('#fx-amount').focus();
  });

  root.addEventListener('click', (e) => {
    const mode = e.target.closest('[data-mode]');
    if (mode) {
      state.mode = mode.dataset.mode;
      state.amount = '';
      renderForm();
    } else if (e.target.closest('#fx-swap')) {
      state.mode = state.mode === 'buy' ? 'sell' : 'buy';
      state.amount = '';
      renderForm();
    } else if (e.target.closest('#fx-max')) {
      const user = Store.currentUser();
      state.amount = String(user.balances[pair().from] || 0);
      $('#fx-amount').value = state.amount;
      update();
    }
  });

  root.addEventListener('input', (e) => {
    if (e.target.id !== 'fx-amount') return;
    state.amount = e.target.value;
    showError($('#fx-error'), '');
    update();
  });

  root.addEventListener('change', (e) => {
    if (e.target.id !== 'fx-asset') return;
    state.asset = e.target.value;
    renderForm();
  });

  root.addEventListener('submit', (e) => {
    e.preventDefault();
    if (!Store.currentUser()) {
      location.href = 'login.html?next=' + encodeURIComponent('exchange.html?asset=' + state.asset);
      return;
    }
    const { from, to } = pair();
    const res = Store.exchange(from, to, state.amount);
    if (!res.ok) {
      showError($('#fx-error'), res.error);
      return;
    }
    toast(`You received ${money(res.received, to)}`);
    state.amount = '';
    renderForm();
    renderSide();
  });

  renderForm();
  renderSide();
})();

});
