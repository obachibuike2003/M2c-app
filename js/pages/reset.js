// Choose a new password from the link in the reset email.
Store.ready.then(() => {
mountChrome('login');

(function () {
  const root = $('#reset-root');
  const token = new URLSearchParams(location.search).get('token') || '';
  if (!token) {
    root.innerHTML = `<h1>Link missing</h1><p class="muted mt-12">Open the link from your email again, or ask for a new one.</p><a class="btn btn-primary mt-16" href="login.html">Back to sign in</a>`;
    return;
  }
  root.innerHTML = `
    <h1>Choose a new password</h1>
    <form id="reset-form" class="mt-16" novalidate>
      <label class="field"><span>New password</span><input name="password" type="password" autocomplete="new-password" required minlength="6"><small class="hint">At least 6 characters</small></label>
      <label class="field"><span>Type it again</span><input name="again" type="password" autocomplete="new-password" required minlength="6"></label>
      <p class="form-error" id="reset-error" role="alert" hidden></p>
      <button class="btn btn-primary btn-block mt-16" type="submit">Save new password</button>
    </form>`;

  $('#reset-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    const error = $('#reset-error');
    const { password, again } = Object.fromEntries(new FormData(form));
    if (password.length < 6) return showError(error, 'Your password needs at least 6 characters.');
    if (password !== again) return showError(error, "The two passwords don't match.");
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    try {
      const data = await Store.api('POST', '/api/auth/reset', { token, password });
      Store.useSession(data);
      root.innerHTML = `<h1>Password changed</h1><p class="muted mt-12">You're signed in. Use your new password next time, on the website and in the app.</p><a class="btn btn-primary mt-16" href="index.html">Continue shopping</a>`;
    } catch (err) {
      showError(error, err.message);
      btn.disabled = false;
    }
  });
})();

});
