mountChrome('login');

(function () {
  const root = $('#auth-root');
  // Only follow "next" when it points at one of our own pages.
  const nextRaw = new URLSearchParams(location.search).get('next') || '';
  const next = /^[a-z]+\.html(\?[\w=&%.-]*)?$/i.test(nextRaw) ? nextRaw : '';

  if (Store.currentUser()) {
    location.replace(next || 'index.html');
    return;
  }

  let mode = 'in';
  // The sign-up side is a 4-step onboarding wizard: create account (with a demo OTP step),
  // agree to terms, pick personal/business, then (business only) meet the assigned agent.
  let step = 1;
  let otpSent = false;
  let otpCode = '';
  const wizard = { mode: 'personal', bizType: '', bizName: '' };
  // Revealing the OTP field re-renders step 1, so what's already typed has to survive that.
  const signupData = { name: '', phone: '', email: '', password: '' };

  const STEP_NAMES = ['Create account', 'Terms & conditions', 'Your profile', 'Your agent'];

  function stepHead(n, total) {
    return `
      <p class="small muted">Step ${n} of ${total}</p>
      <div class="progress mt-12" style="margin-bottom:20px"><i style="--w:${(n / total) * 100}%"></i></div>`;
  }

  function renderSignIn() {
    root.innerHTML = `
      <div class="tabs">
        <button type="button" data-mode="in" aria-pressed="true">Sign in</button>
        <button type="button" data-mode="up" aria-pressed="false">Create account</button>
      </div>
      <h1>Welcome back</h1>
      <form id="auth-form" class="mt-16" novalidate>
        <label class="field"><span>Email</span><input name="email" type="email" autocomplete="email" required></label>
        <label class="field"><span>Password</span><input name="password" type="password" autocomplete="current-password" required minlength="6"></label>
        <p class="form-error" id="auth-error" role="alert" hidden></p>
        <button class="btn btn-primary btn-block mt-16" type="submit">Sign in</button>
      </form>
      <p class="notice mt-16">Demo admin login: <b>${esc(DEMO_ADMIN.email)}</b> with password <b>${esc(DEMO_ADMIN.password)}</b></p>`;
  }

  function renderStep1() {
    root.innerHTML = `
      <div class="tabs">
        <button type="button" data-mode="in" aria-pressed="false">Sign in</button>
        <button type="button" data-mode="up" aria-pressed="true">Create account</button>
      </div>
      ${stepHead(1, 4)}
      <h1>${STEP_NAMES[0]}</h1>
      <form id="auth-form" class="mt-16" novalidate>
        <label class="field"><span>Full name</span><input name="name" autocomplete="name" value="${esc(signupData.name)}" ${otpSent ? 'readonly' : ''} required></label>
        <label class="field"><span>Phone number</span><input name="phone" type="tel" inputmode="tel" autocomplete="tel" value="${esc(signupData.phone)}" ${otpSent ? 'readonly' : ''} required></label>
        <label class="field"><span>Email</span><input name="email" type="email" autocomplete="email" value="${esc(signupData.email)}" ${otpSent ? 'readonly' : ''} required></label>
        <label class="field"><span>Password</span><input name="password" type="password" autocomplete="new-password" value="${esc(signupData.password)}" required minlength="6"><small class="hint">At least 6 characters</small></label>
        ${!otpSent ? `
          <button type="button" class="btn btn-outline btn-block mt-16" id="send-otp">Send verification code</button>
          <p class="hint">We'll text a one-time code to your phone to confirm it's really you.</p>` : `
          <label class="field mt-16"><span>Verification code</span><input name="otp" inputmode="numeric" maxlength="6" placeholder="Enter the code we sent" required></label>
          <p class="hint">Demo build: no real SMS is sent, so the code was shown in a toast instead.</p>
          <button type="button" class="btn btn-outline btn-sm" id="resend-otp">Send a new code</button>`}
        <p class="form-error" id="auth-error" role="alert" hidden></p>
        ${otpSent ? '<button class="btn btn-primary btn-block mt-16" type="submit">Verify &amp; create account</button>' : ''}
      </form>`;
  }

  function renderStep2() {
    root.innerHTML = `
      ${stepHead(2, 4)}
      <h1>${STEP_NAMES[1]}</h1>
      <div class="card mt-16" style="max-height:260px; overflow-y:auto; padding:16px">
        <p><b>Cross-border trade terms.</b> Orders are sourced and shipped from China; prices and delivery windows shown at checkout are estimates and can shift with supplier stock or customs.</p>
        <p class="mt-12"><b>Escrow &amp; buyer protection.</b> Payment is held against your order until it's confirmed delivered. If an order doesn't arrive or doesn't match what was ordered, the amount paid is returned to your ${esc(APP.name)} wallet.</p>
        <p class="mt-12"><b>Your account.</b> You're responsible for keeping your password private and for the accuracy of the details you give us, including for business accounts.</p>
        <p class="mt-12 small muted">Demo build: this is placeholder copy, not a real legal agreement.</p>
      </div>
      <label class="row mt-16" style="align-items:flex-start; gap:10px">
        <input type="checkbox" id="terms-check" style="margin-top:3px">
        <span>I agree to the Terms of Service and the Escrow &amp; Buyer Protection Policy.</span>
      </label>
      <p class="form-error" id="auth-error" role="alert" hidden></p>
      <button class="btn btn-primary btn-block mt-16" id="terms-continue" disabled>Agree &amp; continue</button>`;
  }

  function renderStep3() {
    const biz = wizard.mode === 'business';
    root.innerHTML = `
      ${stepHead(3, 4)}
      <h1>${STEP_NAMES[2]}</h1>
      <div class="mode-pick mt-16">
        <button type="button" class="mode-opt" data-wizard-mode="personal" aria-pressed="${!biz}">
          ${icon('user', 26)}<b>Personal</b><span>For yourself, family and friends. Retail prices, buy one or more.</span>
        </button>
        <button type="button" class="mode-opt" data-wizard-mode="business" aria-pressed="${biz}">
          ${icon('briefcase', 26)}<b>Business</b><span>Bulk buying from ${Store.bulk().minQty} pieces at wholesale prices, your own agent, logo branding and the AI assistant.</span>
        </button>
      </div>
      ${biz ? `
        <div class="form-grid cols-2 mt-16">
          <label class="field"><span>Business name</span><input id="biz-name" maxlength="80" value="${esc(wizard.bizName)}" placeholder="What should we call your business?"></label>
          <label class="field"><span>Primary niche</span>
            <select id="biz-type">
              <option value="">Choose one</option>
              ${BUSINESS_TYPES.filter((t) => t.id !== 'other').map((t) => `<option value="${t.id}"${wizard.bizType === t.id ? ' selected' : ''}>${esc(t.name)}</option>`).join('')}
            </select>
          </label>
        </div>` : ''}
      <p class="form-error" id="auth-error" role="alert" hidden></p>
      <button class="btn btn-primary btn-block mt-16" id="profile-continue">${biz ? 'Continue' : 'Finish'}</button>`;
  }

  function renderStep4() {
    const user = Store.currentUser();
    const a = user && user.agentId ? Store.agent(user.agentId) : null;
    root.innerHTML = `
      ${stepHead(4, 4)}
      <h1>${STEP_NAMES[3]}</h1>
      <div class="card mt-16 agent-card">
        <span class="avatar">${esc((a ? a.name : '?').charAt(0))}</span>
        <div><span class="kicker">Your dedicated sourcing agent</span><h2>${a ? esc(a.name) : 'Being assigned'}</h2><p class="small muted">${a ? 'Helps you with bulk orders, custom branding and delivery.' : 'We will assign an agent to you shortly.'}</p></div>
      </div>
      <div class="row mt-16">
        <a class="btn btn-outline" href="business.html#agent">${icon('chat', 18)} Chat now</a>
        <a class="btn btn-primary" href="${esc(next || 'index.html')}">Explore dashboard ${icon('arrowRight', 18, 'ic-arrow')}</a>
      </div>`;
  }

  function render() {
    if (mode === 'in') return renderSignIn();
    if (step === 1) return renderStep1();
    if (step === 2) return renderStep2();
    if (step === 3) return renderStep3();
    return renderStep4();
  }

  root.addEventListener('click', (e) => {
    const tabBtn = e.target.closest('[data-mode]');
    if (tabBtn) { mode = tabBtn.dataset.mode; step = 1; otpSent = false; render(); return; }

    if (e.target.closest('#send-otp') || e.target.closest('#resend-otp')) {
      const form = $('#auth-form');
      signupData.name = form.name.value.trim();
      signupData.phone = form.phone.value.trim();
      signupData.email = form.email.value.trim();
      signupData.password = form.password.value;
      const error = $('#auth-error');
      if (!signupData.name) return showError(error, 'Enter your full name.');
      if (!/^[0-9+\s-]{7,}$/.test(signupData.phone)) return showError(error, 'Enter a valid phone number.');
      if (!/^\S+@\S+\.\S+$/.test(signupData.email)) return showError(error, 'Enter a valid email address.');
      otpCode = String(Math.floor(1000 + Math.random() * 9000));
      otpSent = true;
      render();
      toast(`Demo code: ${otpCode} (sent by SMS/WhatsApp in production)`);
      return;
    }

    const wizardMode = e.target.closest('[data-wizard-mode]');
    if (wizardMode) { wizard.mode = wizardMode.dataset.wizardMode; render(); return; }

    if (e.target.closest('#terms-continue')) {
      Store.updateUser(Store.currentUser().id, { termsAcceptedAt: Date.now() });
      step = 3;
      render();
      return;
    }

    if (e.target.closest('#profile-continue')) {
      const error = $('#auth-error');
      if (wizard.mode === 'personal') {
        Store.setMode('personal');
        location.href = next || 'index.html';
        return;
      }
      wizard.bizName = $('#biz-name').value.trim();
      wizard.bizType = $('#biz-type').value;
      if (!wizard.bizName) return showError(error, 'Enter your business name.');
      if (!wizard.bizType) return showError(error, 'Pick your primary niche.');
      const res = Store.setMode('business', { name: wizard.bizName, type: wizard.bizType });
      if (!res.ok) return showError(error, res.error);
      // Reflect the new mode in the header pill without a full mountChrome() re-run,
      // which would double up its document-level click/change listeners.
      $$('.mode-switch button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.switchMode === 'business')));
      const hdr = document.querySelector('.hdr');
      if (hdr) hdr.classList.add('is-biz');
      step = 4;
      render();
    }
  });

  root.addEventListener('input', (e) => {
    if (e.target.id === 'terms-check') $('#terms-continue').disabled = !e.target.checked;
  });

  root.addEventListener('submit', (e) => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(e.target));
    const error = $('#auth-error');

    if (mode === 'in') {
      const res = Store.login(data.email, data.password);
      if (!res.ok) return showError(error, res.error);
      location.href = next || (res.user.role === 'admin' ? 'admin.html' : 'index.html');
      return;
    }

    // Step 1 submit: only valid once the OTP field is showing and filled in.
    if (!otpSent) return;
    if ((data.otp || '').trim() !== otpCode) return showError(error, 'That code is not right. Check the toast and try again.');
    if (data.password.length < 6) return showError(error, 'Your password needs at least 6 characters.');
    const res = Store.signup({ name: data.name, phone: data.phone, email: data.email, whatsapp: data.phone, password: data.password });
    if (!res.ok) return showError(error, res.error);
    step = 2;
    render();
  });

  render();
})();
