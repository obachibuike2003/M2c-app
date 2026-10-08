mountChrome('shop');

(function () {
  const params = new URLSearchParams(location.search);
  const state = {
    q: (params.get('q') || '').trim().toLowerCase(),
    cat: CATEGORIES.some((c) => c.id === params.get('cat')) ? params.get('cat') : '',
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

  function render() {
    $('#filter-cats').innerHTML = [{ id: '', name: 'All' }, ...CATEGORIES].map((c) => `
      <button type="button" class="chip${state.cat === c.id ? ' is-on' : ''}" data-cat="${c.id}" aria-pressed="${state.cat === c.id}">${esc(c.name)}</button>`).join('');

    const list = Store.products()
      .filter((p) => !state.cat || p.cat === state.cat)
      .filter((p) => !state.q || (p.name + ' ' + p.desc).toLowerCase().includes(state.q))
      .filter((p) => !state.max || p.price <= state.max)
      .sort(sorters[state.sort]);

    $('#list-title').textContent = state.q
      ? `Results for "${state.q}"`
      : state.cat ? categoryOf(state.cat).name : 'All products';
    $('#result-count').textContent = `${list.length} ${list.length === 1 ? 'product' : 'products'}`;
    $('#results').innerHTML = list.length
      ? list.map((p, i) => productCard(p, i)).join('')
      : `<div class="card empty" style="grid-column:1/-1">${icon('search', 40)}<h2>Nothing matches</h2><p>Try a different search, category or price.</p><a class="btn btn-primary" href="products.html">Show all products</a></div>`;
    observeReveals();
  }

  $('#filter-cats').addEventListener('click', (e) => {
    const chip = e.target.closest('[data-cat]');
    if (!chip) return;
    state.cat = chip.dataset.cat;
    const next = new URLSearchParams(location.search);
    if (state.cat) next.set('cat', state.cat); else next.delete('cat');
    history.replaceState(null, '', 'products.html' + (next.toString() ? '?' + next : ''));
    render();
  });
  $('#sort').addEventListener('change', (e) => { state.sort = e.target.value; render(); });
  $('#max-price').addEventListener('input', (e) => { state.max = Number(e.target.value) || 0; render(); });

  render();
})();
