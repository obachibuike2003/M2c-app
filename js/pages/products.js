mountChrome('shop');

(function () {
  const params = new URLSearchParams(location.search);
  const CONDITIONS = [['', 'All'], ['new', 'Brand new'], ['used', 'Used']];
  const state = {
    q: (params.get('q') || '').trim().toLowerCase(),
    cat: categories().some((c) => c.id === params.get('cat')) ? params.get('cat') : '',
    condition: ['new', 'used'].includes(params.get('condition')) ? params.get('condition') : '',
    sort: 'popular',
    max: 0
  };

  const sorters = {
    popular: (a, b) => (b.sold || 0) - (a.sold || 0),
    low: (a, b) => a.price - b.price,
    high: (a, b) => b.price - a.price,
    discount: (a, b) => discountOf(b) - discountOf(a),
    rating: (a, b) => (b.rating || 0) - (a.rating || 0)
  };

  const chip = (attr, value, label, on) =>
    `<button type="button" class="chip${on ? ' is-on' : ''}" data-${attr}="${esc(value)}" aria-pressed="${on}">${esc(label)}</button>`;

  function syncUrl() {
    const next = new URLSearchParams(location.search);
    ['cat', 'condition'].forEach((k) => { if (state[k]) next.set(k, state[k]); else next.delete(k); });
    history.replaceState(null, '', 'products.html' + (next.toString() ? '?' + next : ''));
  }

  function render() {
    $('#filter-cats').innerHTML = [{ id: '', name: 'All' }, ...categories()].map((c) => chip('cat', c.id, c.name, state.cat === c.id)).join('');
    $('#filter-condition').innerHTML = CONDITIONS.map(([id, name]) => chip('condition', id, name, state.condition === id)).join('');

    const list = Store.products()
      .filter((p) => !state.cat || p.cat === state.cat)
      .filter((p) => !state.condition || (p.condition || 'new') === state.condition)
      .filter((p) => !state.q || (p.name + ' ' + p.desc + ' ' + categoryOf(p.cat).name).toLowerCase().includes(state.q))
      .filter((p) => !state.max || p.price <= state.max)
      .sort(sorters[state.sort]);

    const title = state.q ? `Results for "${state.q}"` : state.cat ? categoryOf(state.cat).name : 'All products';
    $('#list-title').textContent = state.condition === 'used' ? `${title === 'All products' ? 'Used products' : title + ', used'}` : title;
    $('#result-count').textContent = `${list.length} ${list.length === 1 ? 'product' : 'products'}${Store.isBusiness() ? ' · prices shown are wholesale, per piece' : ''}`;
    $('#results').innerHTML = list.length
      ? list.map((p, i) => productCard(p, i)).join('')
      : `<div class="card empty" style="grid-column:1/-1">${icon('search', 40)}<h2>Nothing matches</h2><p>Try a different search, category or price.</p><a class="btn btn-primary" href="products.html">Show all products</a></div>`;
    observeReveals();
  }

  $('#filter-cats').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-cat]');
    if (!btn) return;
    state.cat = btn.dataset.cat;
    syncUrl();
    render();
  });
  $('#filter-condition').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-condition]');
    if (!btn) return;
    state.condition = btn.dataset.condition;
    syncUrl();
    render();
  });
  $('#sort').addEventListener('change', (e) => { state.sort = e.target.value; render(); });
  $('#max-price').addEventListener('input', (e) => { state.max = Number(e.target.value) || 0; render(); });

  render();
})();
