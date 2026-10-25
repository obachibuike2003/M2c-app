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

    <p class="small muted mt-16">${esc(APP.supportEmail)} · Demo build: support messages are not actually sent anywhere.</p>`;
})();

});
