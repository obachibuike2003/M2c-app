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

  function render() {
    root.innerHTML = `
      <div class="tabs">
        <button type="button" data-mode="in" aria-pressed="${mode === 'in'}">Sign in</button>
        <button type="button" data-mode="up" aria-pressed="${mode === 'up'}">Create account</button>
      </div>
      <h1>${mode === 'in' ? 'Welcome back' : 'Create your account'}</h1>
      <form id="auth-form" class="mt-16" novalidate>
        ${mode === 'up' ? `
          <label class="field"><span>Full name</span><input name="name" autocomplete="name" required></label>
          <label class="field"><span>Phone number</span><input name="phone" type="tel" inputmode="tel" autocomplete="tel" required></label>
          <label class="field"><span>WhatsApp number</span><input name="whatsapp" type="tel" inputmode="tel" placeholder="Leave empty if it's the same as your phone"><small class="hint">Your agent can reach you here about orders.</small></label>` : ''}
        <label class="field"><span>Email</span><input name="email" type="email" autocomplete="email" required></label>
        <label class="field"><span>Password</span>
          <input name="password" type="password" autocomplete="${mode === 'in' ? 'current-password' : 'new-password'}" required minlength="6">
          ${mode === 'up' ? '<small class="hint">At least 6 characters</small>' : ''}
        </label>
        <p class="form-error" id="auth-error" role="alert" hidden></p>
        <button class="btn btn-primary btn-block mt-16" type="submit">${mode === 'in' ? 'Sign in' : 'Create account'}</button>
      </form>
      ${mode === 'up' ? '<p class="small muted mt-16">After you sign up you can choose to buy for yourself or for your business, and switch any time.</p>' : ''}
      ${mode === 'in' ? `<p class="notice mt-16">Demo admin login: <b>${esc(DEMO_ADMIN.email)}</b> with password <b>${esc(DEMO_ADMIN.password)}</b></p>` : ''}`;
  }

  root.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-mode]');
    if (!btn) return;
    mode = btn.dataset.mode;
    render();
  });

  root.addEventListener('submit', (e) => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(e.target));
    const error = $('#auth-error');
    let res;

    if (mode === 'up') {
      if (!data.name.trim()) return showError(error, 'Enter your full name.');
      if (!/^[0-9+\s-]{7,}$/.test(data.phone.trim())) return showError(error, 'Enter a valid phone number.');
      if (data.whatsapp.trim() && !/^[0-9+\s-]{7,}$/.test(data.whatsapp.trim())) return showError(error, 'Enter a valid WhatsApp number, or leave it empty.');
      if (!/^\S+@\S+\.\S+$/.test(data.email.trim())) return showError(error, 'Enter a valid email address.');
      if (data.password.length < 6) return showError(error, 'Your password needs at least 6 characters.');
      res = Store.signup(data);
    } else {
      res = Store.login(data.email, data.password);
    }

    if (!res.ok) return showError(error, res.error);
    location.href = next || (res.user.role === 'admin' ? 'admin.html' : 'index.html');
  });

  render();
})();
