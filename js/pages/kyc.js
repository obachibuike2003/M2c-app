mountChrome('account');

(function () {
  if (!requireLogin()) return;
  const root = $('#kyc-root');

  const VERIFY_TEXT = {
    none: 'Take a quick selfie so we know it is really you.',
    pending: 'Thanks! Your selfie is waiting for our team to check it.',
    verified: 'Your identity is verified.',
    rejected: 'We could not verify that photo. Please take a clear selfie in good light.'
  };

  function render() {
    const user = Store.currentUser();
    const v = (user.verify || {}).status || 'none';

    root.innerHTML = `
      <p class="small muted"><a href="account.html">My account</a> / Account upgrades &amp; KYC</p>
      <h1 class="mt-12">Account upgrades &amp; KYC</h1>
      <p class="muted mt-12">Verifying your identity unlocks faster approval on big orders.</p>

      <section class="card section mt-16" aria-labelledby="verify-h">
        <div class="row spread"><h2 id="verify-h">Identity check</h2>${statusPill(v === 'none' ? 'Not verified' : v)}</div>
        <p class="muted mt-12">${VERIFY_TEXT[v]}</p>
        ${v === 'none' || v === 'rejected' ? `
          <label class="btn btn-primary mt-16 file-btn">${icon('camera', 18)} Take a selfie<input type="file" accept="image/*" capture="user" id="selfie"></label>
          <p class="hint">On a phone this opens your front camera. Demo: the photo stays in this browser for the admin to check.</p>` : ''}
      </section>

      <section class="card section mt-16">
        <h2>What verifying unlocks</h2>
        <ul class="perks mt-16">
          <li><span class="perk-ic">${icon('zap', 22)}</span><div><b>Faster approval</b><span>Quicker checks on large or bulk orders</span></div></li>
          <li><span class="perk-ic">${icon('shield', 22)}</span><div><b>Trust signal</b><span>Shows you're a verified buyer to our team</span></div></li>
        </ul>
      </section>`;
    observeReveals();
  }

  root.addEventListener('change', async (e) => {
    if (e.target.id !== 'selfie') return;
    try {
      const photo = await readImage(e.target.files[0], 360);
      const res = Store.submitVerification(photo);
      if (!res.ok) return toast(res.error, 'error');
      toast('Selfie sent for checking');
      render();
    } catch (err) {
      toast(err.message, 'error');
    }
  });

  render();
})();
