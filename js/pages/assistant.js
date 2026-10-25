// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('business');

(function () {
  const root = $('#assistant-root');
  const user = requireBusiness(root);
  if (!user) return;

  const KEY = 'mp_assistant_' + user.id;
  let history = [];
  try { history = JSON.parse(sessionStorage.getItem(KEY) || '[]'); } catch (e) { history = []; }

  const SUGGESTIONS = ['What should I stock first?', 'How much for 50 power banks?', 'How do I price my goods?', 'Where is my order?', 'Ideas to get more customers', 'Find caustic soda'];

  root.innerHTML = `
    <div class="assistant">
      <div class="assistant-head">
        <span class="bot-badge">${icon('bot', 26)}</span>
        <div><h1>Business assistant</h1><p class="small muted">Helps ${esc(user.business.name)} find products, price orders and grow.</p></div>
      </div>
      <div class="card chat assistant-chat">
        <div class="chat-log" id="ai-log" aria-live="polite"></div>
        <div class="chips ai-suggest" id="ai-suggest">${SUGGESTIONS.map((s) => `<button type="button" class="chip" data-ask="${esc(s)}">${esc(s)}</button>`).join('')}</div>
        <form class="chat-form" id="ai-form">
          <input name="text" autocomplete="off" maxlength="500" placeholder="Ask anything about your business" aria-label="Your question">
          <button class="btn btn-primary" type="submit" aria-label="Send">${icon('send', 18)}</button>
        </form>
      </div>
    </div>`;

  const log = $('#ai-log');

  function bubble(m) {
    if (m.role === 'user') return `<div class="msg msg-me"><p>${esc(m.content)}</p></div>`;
    const products = (m.products || []).map(Store.product).filter(Boolean);
    return `
      <div class="msg msg-them msg-ai">
        <p>${esc(m.content).replace(/\n/g, '<br>')}</p>
        ${products.length ? `<div class="ai-products">${products.map((p) => `
          <a href="product.html?id=${encodeURIComponent(p.id)}" class="ai-product">
            <span class="thumb">${productThumb(p, 22)}</span>
            <span><b>${esc(p.name)}</b><small>${money(Store.unitPrice(p, Store.bulkMin(p)))} each · min. ${Store.bulkMin(p)}</small></span>
          </a>`).join('')}</div>` : ''}
        ${(m.actions || []).length ? `<div class="row">${m.actions.map(([label, href]) => `<a class="btn btn-soft btn-sm" href="${esc(href)}">${esc(label)}</a>`).join('')}</div>` : ''}
      </div>`;
  }

  function render() {
    const intro = { role: 'assistant', content: `Hi ${user.name.split(' ')[0]}! I'm your ${APP.name} business assistant. Ask me to find products, work out bulk prices and profit, check your orders, or for tips on pricing, marketing and branding.` };
    log.innerHTML = [intro, ...history].map(bubble).join('');
    log.scrollTop = log.scrollHeight;
    try { sessionStorage.setItem(KEY, JSON.stringify(history.slice(-30))); } catch (e) { /* ignore */ }
  }

  async function ask(text) {
    text = String(text || '').trim();
    if (!text) return;
    history.push({ role: 'user', content: text });
    render();
    log.insertAdjacentHTML('beforeend', '<div class="msg msg-them typing" id="typing"><p><i></i><i></i><i></i></p></div>');
    log.scrollTop = log.scrollHeight;
    const [res] = await Promise.all([
      Assistant.reply(text, history.slice(0, -1).map(({ role, content }) => ({ role, content }))),
      new Promise((r) => setTimeout(r, 450))
    ]);
    history.push({ role: 'assistant', content: res.text, products: res.products, actions: res.actions });
    render();
  }

  $('#ai-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const input = e.target.elements.text;
    ask(input.value);
    input.value = '';
  });
  $('#ai-suggest').addEventListener('click', (e) => {
    const chip = e.target.closest('[data-ask]');
    if (chip) ask(chip.dataset.ask);
  });

  render();
})();

});
