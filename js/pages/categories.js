mountChrome('shop');

(function () {
  const products = Store.products();
  const counts = {};
  products.forEach((p) => { counts[p.cat] = (counts[p.cat] || 0) + 1; });

  $('#cat-list').innerHTML = categories().map((c) => `
    <a class="cat-row reveal" href="products.html?cat=${encodeURIComponent(c.id)}">
      <span class="bubble" style="--h:${c.hue}">${categoryArt(c, 28)}</span>
      <span class="cat-row-text"><b>${esc(c.name)}</b><small>${counts[c.id] || 0} products</small></span>
      ${icon('chevron', 20)}
    </a>`).join('');
  observeReveals();
})();
