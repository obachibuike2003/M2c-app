mountChrome('business');

(function () {
  const root = $('#business-root');
  const user = requireBusiness(root);
  if (!user) return;

  const type = Store.businessType(user.business.type);
  const a = Store.agent(user.agentId);
  const rules = Store.bulk();
  const first = user.name.split(' ')[0];

  root.innerHTML = `
    <section class="page-hero bg-warehouse">
      <span class="kicker">Business hub</span>
      <h1>${esc(user.business.name)}</h1>
      <p>${type ? esc(type.name) + ' · ' : ''}Wholesale prices from ${rules.minQty} pieces, your own agent, and your brand on the goods you buy.</p>
    </section>

    <div class="tool-grid">
      <a class="tool" href="assistant.html">${icon('bot', 26)}<b>AI business assistant</b><span>Find products, work out prices and margins, get advice.</span></a>
      <a class="tool" href="brand.html">${icon('palette', 26)}<b>Build my brand</b><span>Logo, colours and tagline, then put them on your goods.</span></a>
      <a class="tool" href="products.html">${icon('grid', 26)}<b>Buy in bulk</b><span>Every product at wholesale price. Customise with your logo.</span></a>
      <a class="tool" href="orders.html">${icon('truck', 26)}<b>Track my goods</b><span>From the factory in China to your door.</span></a>
    </div>

    <div class="two-col section">
      <section class="card chat" id="agent" aria-labelledby="agent-h">
        <div class="chat-head">
          <span class="avatar">${esc((a ? a.name : '?').charAt(0))}</span>
          <div><h2 id="agent-h">${a ? esc(a.name) : 'Your agent'}</h2><span class="small muted">${a ? 'Your Easy2buy agent' : 'An agent will be assigned soon'}</span></div>
          ${a && a.whatsapp ? `<a class="btn btn-outline btn-sm" href="${esc(waLink(a.whatsapp, `Hi ${a.name}, this is ${user.name} (${user.business.name}) on ${APP.name}.`))}" target="_blank" rel="noopener">${icon('whatsapp', 16)} WhatsApp</a>` : ''}
        </div>
        <div class="chat-log" id="chat-log" aria-live="polite"></div>
        <form class="chat-form" id="chat-form">
          <input name="text" autocomplete="off" maxlength="1000" placeholder="Message ${a ? esc(a.name) : 'your agent'}" aria-label="Message">
          <button class="btn btn-primary" type="submit" aria-label="Send">${icon('send', 18)}</button>
        </form>
      </section>

      <aside class="card summary">
        <h2>Your wholesale prices</h2>
        <p class="small muted mt-12">The more of one item you buy, the less you pay for each.</p>
        <ul class="tiers mt-12">
          <li><span>Minimum order</span><b>${rules.minQty} pieces</b><small>per item</small></li>
          ${rules.tiers.filter((t) => t.off > 0).map((t) => `<li><span>${t.from}+ pieces</span><b>${t.off}% off</b><small>retail price</small></li>`).join('')}
        </ul>
        <p class="small muted mt-12">Some big items, like cars, have a smaller minimum.</p>
        <button type="button" class="btn btn-outline btn-block mt-16" data-switch-mode="personal">Switch to personal buying</button>
      </aside>
    </div>

    <section class="section" aria-labelledby="rec-h">
      <div class="section-head"><div><span class="kicker">For ${esc(user.business.name)}</span><h2 id="rec-h">Picked for your business</h2></div><a href="products.html">All products</a></div>
      <div class="grid-products" id="biz-rec"></div>
    </section>`;

  $('#biz-rec').innerHTML = Store.recommend(Store.currentUser(), 10).map((p, i) => productCard(p, i)).join('');
  observeReveals();

  /* ---------- agent chat ---------- */
  const log = $('#chat-log');
  function renderChat() {
    const thread = Store.threadOf(user.id);
    log.innerHTML = thread.length
      ? thread.map((m) => `<div class="msg msg-${m.from === 'user' ? 'me' : 'them'}"><p>${esc(m.text)}</p><time>${formatDate(m.at)}</time></div>`).join('')
      : `<p class="muted small chat-empty">Say hello, ${esc(first)}. Ask about prices, custom orders or delivery.</p>`;
    log.scrollTop = log.scrollHeight;
    Store.markSeen(user.id, 'user');
  }
  renderChat();

  $('#chat-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const input = e.target.elements.text;
    if (!Store.sendMessage(user.id, 'user', input.value)) return;
    const firstMessage = Store.threadOf(user.id).filter((m) => m.from === 'user').length === 1;
    input.value = '';
    renderChat();
    // Demo: let the customer know a person will answer.
    if (firstMessage && a) {
      setTimeout(() => {
        Store.sendMessage(user.id, 'agent', `Thanks ${first}! I've seen your message and will reply here soon. For anything urgent, tap WhatsApp above.`);
        renderChat();
      }, 1200);
    }
  });

  // Replies sent from the admin panel in another tab show up straight away.
  addEventListener('storage', (e) => { if (e.key === 'mp_messages') renderChat(); });

  if (location.hash === '#agent') $('#agent').scrollIntoView({ block: 'start' });
})();
