// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('account');

(function () {
  const root = $('#support-root');
  const user = Store.currentUser();
  const biz = user && user.mode === 'business';
  const a = biz && user.agentId ? Store.agent(user.agentId) : null;

  root.innerHTML = `
    <h1>Customer service</h1>
    <p class="muted mt-12">Questions about an order, your wallet or your account? Here's every way to reach us.</p>

    ${a ? `
      <section class="card section agent-card mt-16">
        <span class="avatar">${esc(a.name.charAt(0))}</span>
        <div><span class="kicker">Your agent</span><h2>${esc(a.name)}</h2><p class="small muted">Fastest for bulk orders, custom branding and delivery questions.</p></div>
        <div class="row"><a class="btn btn-primary btn-sm" href="business.html#agent">${icon('chat', 16)} Chat</a><a class="btn btn-outline btn-sm" href="${esc(waLink(a.whatsapp, `Hi ${a.name}, this is ${user.name} on ${APP.name}.`))}" target="_blank" rel="noopener">${icon('whatsapp', 16)} WhatsApp</a></div>
      </section>` : ''}

    <section class="card chat section mt-16" aria-labelledby="care-h">
      <div class="chat-head">
        <span class="avatar">${icon('headset', 20)}</span>
        <div><h2 id="care-h">Chat with customer care</h2><span class="small muted">Answers in seconds. A person takes over when you need one.</span></div>
      </div>
      <div class="chat-log" id="care-log" aria-live="polite"></div>
      <div class="chips ai-suggest" id="care-suggest">${['Where is my order?', 'How long does delivery take?', 'How does buyer protection work?', 'My item arrived damaged'].map((q) => `<button type="button" class="chip" data-ask="${esc(q)}">${esc(q)}</button>`).join('')}</div>
      <form class="chat-form" id="care-form">
        <input name="text" autocomplete="off" maxlength="500" placeholder="${user ? 'How can we help?' : 'Sign in to chat, or WhatsApp us below'}" aria-label="Your question"${user ? '' : ' disabled'}>
        <button class="btn btn-primary" type="submit" aria-label="Send"${user ? '' : ' disabled'}>${icon('send', 18)}</button>
      </form>
    </section>

    <section class="section mt-16" aria-labelledby="links-h">
      <h2 id="links-h" class="visually-hidden">Ways to reach us</h2>
      <div class="quick-links">
        <a href="${esc(waLink(APP.supportWhatsapp, `Hi ${APP.name}, I need some help.`))}" target="_blank" rel="noopener">${icon('whatsapp', 22)}<span>WhatsApp us</span></a>
        <a href="mailto:${esc(APP.supportEmail)}">${icon('send', 22)}<span>Email us</span></a>
        <a href="assistant.html">${icon('bot', 22)}<span>Ask the AI assistant</span></a>
        <a href="orders.html">${icon('truck', 22)}<span>Track my goods</span></a>
      </div>
    </section>

    <section class="card section mt-16" aria-labelledby="faq-h">
      <h2 id="faq-h">Common questions</h2>
      <dl class="mt-16 support-faq">
        <div><dt>Where is my order?</dt><dd>Open <a href="orders.html">My orders</a> and tap any order to see its live tracking stage and estimated delivery date.</dd></div>
        <div><dt>How do I get a refund?</dt><dd>If an order doesn't arrive or doesn't match what was ordered, the amount paid is returned to your ${esc(APP.name)} wallet. WhatsApp us with your order number.</dd></div>
        <div><dt>How do I switch to business buying?</dt><dd>Go to <a href="account.html">My account</a> and choose Business under "How are you buying?" to unlock wholesale prices, an agent and logo branding.</dd></div>
        <div><dt>How do I verify my identity?</dt><dd>Go to <a href="kyc.html">Account upgrades &amp; KYC</a> and take a quick selfie. Verified buyers get faster approval on big orders.</dd></div>
      </dl>
    </section>

    <p class="small muted mt-16">${esc(APP.supportEmail)}</p>`;

  /* ---------- customer care chat ---------- */
  const log = $('#care-log');
  const history = [];
  const bubble = (m) => m.role === 'user'
    ? `<div class="msg msg-me"><p>${esc(m.content)}</p></div>`
    : `<div class="msg msg-them"><p>${esc(m.content).replace(/\n/g, '<br>')}</p>
        ${(m.actions || []).length ? `<div class="row mt-12">${m.actions.map(([label, href]) => `<a class="btn btn-soft btn-sm" href="${esc(href)}"${/^https?:/.test(href) ? ' target="_blank" rel="noopener"' : ''}>${icon('whatsapp', 14)} ${esc(label)}</a>`).join('')}</div>` : ''}</div>`;
  function render() {
    const intro = { role: 'assistant', content: `Hi${user ? ' ' + user.name.split(' ')[0] : ''}! I'm ${APP.name} customer care. Ask me about an order, delivery, payment or your account. If it needs a person, I'll pass you to one.` };
    log.innerHTML = [intro, ...history].map(bubble).join('');
    log.scrollTop = log.scrollHeight;
  }
  async function ask(text) {
    text = String(text || '').trim();
    if (!text || !user) return;
    const before = history.map(({ role, content }) => ({ role, content }));
    history.push({ role: 'user', content: text });
    render();
    log.insertAdjacentHTML('beforeend', '<div class="msg msg-them typing"><p><i></i><i></i><i></i></p></div>');
    log.scrollTop = log.scrollHeight;
    const res = await Assistant.reply(text, before, 'support');
    history.push({ role: 'assistant', content: res.text, actions: res.actions });
    render();
  }
  $('#care-form').addEventListener('submit', (e) => { e.preventDefault(); ask(e.target.elements.text.value); e.target.elements.text.value = ''; });
  $('#care-suggest').addEventListener('click', (e) => { const c = e.target.closest('[data-ask]'); if (c) ask(c.dataset.ask); });
  render();
})();

});
