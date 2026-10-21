mountChrome('shop');

(function () {
  const params = new URLSearchParams(location.search);
  const CONDITIONS = [['', 'All'], ['new', 'Brand new'], ['used', 'Used']];
  const SORT_OPTIONS = [
    ['popular', 'Most popular'],
    ['low', 'Price: low to high'],
    ['high', 'Price: high to low'],
    ['discount', 'Biggest discount'],
    ['rating', 'Top rated']
  ];
  const biz = Store.isBusiness();
  const state = {
    q: (params.get('q') || '').trim().toLowerCase(),
    cat: categories().some((c) => c.id === params.get('cat')) ? params.get('cat') : '',
    sub: params.get('sub') || '',
    condition: ['new', 'used'].includes(params.get('condition')) ? params.get('condition') : '',
    custom: biz && params.get('custom') === '1',
    sort: 'popular',
    max: 0
  };

  // Subcategories (e.g. car brands, phone brands) are whatever distinct `sub` values
  // exist among a category's own products, so a new product auto-creates its subcategory.
  function subsFor(catId) {
    const seen = [];
    Store.products().forEach((p) => {
      if (p.cat === catId && p.sub && !seen.includes(p.sub)) seen.push(p.sub);
    });
    return seen;
  }
  if (!subsFor(state.cat).includes(state.sub)) state.sub = '';

  const sorters = {
    popular: (a, b) => (b.sold || 0) - (a.sold || 0),
    low: (a, b) => a.price - b.price,
    high: (a, b) => b.price - a.price,
    discount: (a, b) => discountOf(b) - discountOf(a),
    rating: (a, b) => (b.rating || 0) - (a.rating || 0)
  };

  const chip = (attr, value, label, on) =>
    `<button type="button" class="chip${on ? ' is-on' : ''}" data-${attr}="${esc(value)}" aria-pressed="${on}">${esc(label)}</button>`;

  if (biz) {
    $('#filter-custom-label').hidden = false;
    $('#filter-custom').hidden = false;
    $('#filter-custom').innerHTML = chip('custom', '1', 'Customizable only', state.custom);
  }

  const sortTrigger = $('#sort-trigger');
  const sortValue = $('#sort-value');
  const sortOptions = $('#sort-options');
  const sortControl = $('#sort-control');

  sortOptions.innerHTML = SORT_OPTIONS.map(([value, label]) =>
    `<button type="button" role="option" class="sort-option" data-sort="${value}" aria-selected="${value === state.sort}">${label}</button>`
  ).join('');

  function closeSortMenu(returnFocus = false) {
    sortOptions.hidden = true;
    sortTrigger.setAttribute('aria-expanded', 'false');
    if (returnFocus) sortTrigger.focus();
  }

  function openSortMenu(focusSelected = false) {
    sortOptions.hidden = false;
    sortTrigger.setAttribute('aria-expanded', 'true');
    if (focusSelected) sortOptions.querySelector('[aria-selected="true"]').focus();
  }

  function chooseSort(value) {
    state.sort = value;
    sortValue.textContent = SORT_OPTIONS.find(([key]) => key === value)[1];
    sortOptions.querySelectorAll('[role="option"]').forEach((option) => {
      option.setAttribute('aria-selected', String(option.dataset.sort === value));
    });
    closeSortMenu(true);
    render();
  }

  sortTrigger.addEventListener('click', () => {
    if (sortOptions.hidden) openSortMenu();
    else closeSortMenu();
  });
  sortTrigger.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      openSortMenu(true);
    }
  });
  sortOptions.addEventListener('click', (e) => {
    const option = e.target.closest('[data-sort]');
    if (option) chooseSort(option.dataset.sort);
  });
  sortOptions.addEventListener('keydown', (e) => {
    const options = [...sortOptions.querySelectorAll('[role="option"]')];
    const index = options.indexOf(document.activeElement);
    let nextIndex = index;
    if (e.key === 'ArrowDown') nextIndex = (index + 1) % options.length;
    else if (e.key === 'ArrowUp') nextIndex = (index - 1 + options.length) % options.length;
    else if (e.key === 'Home') nextIndex = 0;
    else if (e.key === 'End') nextIndex = options.length - 1;
    else if (e.key === 'Escape') {
      e.preventDefault();
      closeSortMenu(true);
      return;
    } else return;
    e.preventDefault();
    options[nextIndex].focus();
  });
  document.addEventListener('pointerdown', (e) => {
    if (!sortControl.contains(e.target)) closeSortMenu();
  });

  function syncUrl() {
    const next = new URLSearchParams(location.search);
    ['cat', 'sub', 'condition'].forEach((k) => { if (state[k]) next.set(k, state[k]); else next.delete(k); });
    if (state.custom) next.set('custom', '1'); else next.delete('custom');
    history.replaceState(null, '', 'products.html' + (next.toString() ? '?' + next : ''));
  }

  function render() {
    // Arriving already filtered to one category (from the home page's category icons) makes
    // re-picking it here redundant, so the chip row only shows while browsing "All products".
    $('#filter-cats-label').hidden = !!state.cat;
    $('#filter-cats').hidden = !!state.cat;
    $('#filter-cats').innerHTML = [{ id: '', name: 'All' }, ...categories()].map((c) => chip('cat', c.id, c.name, state.cat === c.id)).join('');

    const subs = subsFor(state.cat);
    $('#filter-subs-label').hidden = subs.length < 2;
    $('#filter-subs').hidden = subs.length < 2;
    if (subs.length >= 2) {
      $('#filter-subs-label').textContent = 'Subcategory';
      $('#filter-subs').innerHTML = [{ id: '', name: 'All' }, ...subs.map((s) => ({ id: s, name: s }))]
        .map((s) => chip('sub', s.id, s.name, state.sub === s.id)).join('');
    }

    $('#filter-condition').innerHTML = CONDITIONS.map(([id, name]) => chip('condition', id, name, state.condition === id)).join('');
    if (biz) $('#filter-custom').innerHTML = chip('custom', '1', 'Customizable only', state.custom);

    const list = Store.products()
      .filter((p) => !state.cat || p.cat === state.cat)
      .filter((p) => !state.sub || p.sub === state.sub)
      .filter((p) => !state.condition || (p.condition || 'new') === state.condition)
      .filter((p) => !state.custom || isCustomizable(p))
      .filter((p) => !state.q || (p.name + ' ' + p.desc + ' ' + categoryOf(p.cat).name).toLowerCase().includes(state.q))
      .filter((p) => !state.max || p.price <= state.max)
      .sort(sorters[state.sort]);

    const title = state.q ? `Results for "${state.q}"` : state.cat ? categoryOf(state.cat).name + (state.sub ? ` · ${state.sub}` : '') : 'All products';
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
    state.sub = '';
    syncUrl();
    render();
  });
  $('#filter-subs').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-sub]');
    if (!btn) return;
    state.sub = btn.dataset.sub;
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
  if (biz) $('#filter-custom').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-custom]');
    if (!btn) return;
    state.custom = !state.custom;
    syncUrl();
    render();
  });
  $('#max-price').addEventListener('input', (e) => { state.max = Number(e.target.value) || 0; render(); });

  render();
})();
