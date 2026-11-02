// Runs once Store.ready has loaded the catalogue and account from the server.
Store.ready.then(() => {
mountChrome('terms');

$('#terms-root').innerHTML = `
  <span class="kicker">Legal</span>
  <h1>${esc(APP.name)} Terms and Conditions</h1>
  ${termsHtml()}
  <p class="small muted mt-16">Questions about these terms? <a href="support.html">Contact customer service</a>.</p>`;

});
