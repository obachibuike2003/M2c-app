mountChrome('orders');

(function () {
  const user = requireLogin();
  if (!user) return;

  const root = $('#track-root');
  const o = Store.order(new URLSearchParams(location.search).get('id'));
  if (!o || (o.userId !== user.id && user.role !== 'admin')) {
    root.innerHTML = `<div class="card empty">${icon('box', 40)}<h1>Order not found</h1><p>Check the order number, or see all your orders.</p><a class="btn btn-primary" href="orders.html">My orders</a></div>`;
    return;
  }

  const when = {};
  (o.tracking || []).forEach((t) => { when[t.stage] = t.at; });
  const cancelled = o.status === 'Cancelled';
  const a = user.agentId ? Store.agent(user.agentId) : null;

  root.innerHTML = `
    <p class="small muted"><a href="orders.html">My orders</a> / ${esc(o.id)}</p>
    <div class="two-col mt-12">
      <section class="card">
        <div class="row spread">
          <div><span class="kicker">Order tracker</span><h1>${esc(o.id)}</h1></div>
          ${statusPill(o.status)}
        </div>
        ${cancelled ? `<p class="notice mt-16">This order was cancelled${o.cancelledAt ? ' on ' + formatDate(o.cancelledAt) : ''}.${o.pay === 'wallet' ? ' Your payment was returned to your wallet.' : ''}</p>` : ''}
        <ol class="timeline mt-16">
          ${TRACK_STAGES.map((s, i) => {
            const state = cancelled ? (i <= o.stage ? 'done' : 'off') : i < o.stage ? 'done' : i === o.stage ? 'now' : 'next';
            return `
            <li class="is-${state}">
              <span class="dot">${state === 'done' ? icon('check', 14) : ''}</span>
              <div>
                <b>${esc(s.name)}</b>
                ${when[i] && state !== 'next' ? `<span class="small muted">${formatDate(when[i])}</span>` : ''}
                ${state === 'now' ? `<p class="small">${esc(s.text)}</p>` : ''}
              </div>
            </li>`;
          }).join('')}
        </ol>
      </section>
      <aside class="card summary">
        <h2>What's in it</h2>
        <ul class="order-items mt-12">
          ${o.items.map((it) => `
            <li><span>${it.qty} × ${esc(it.name)}${it.custom ? `<br><span class="small muted">${it.custom.pieces} with your logo</span>` : ''}</span><span class="num">${money(it.price * it.qty)}</span></li>`).join('')}
        </ul>
        <dl class="mt-12">
          <div class="sum-row sum-total"><dt>Total</dt><dd>${money(o.total)}</dd></div>
        </dl>
        <p class="small muted mt-12">Delivering to ${esc(o.address.name)}, ${esc(o.address.street)}, ${esc(o.address.city)}, ${esc(o.address.state)}</p>
        ${a ? `<a class="btn btn-outline btn-block mt-16" href="business.html#agent">${icon('chat', 18)} Ask ${esc(a.name)} about this order</a>` : ''}
      </aside>
    </div>`;
})();
