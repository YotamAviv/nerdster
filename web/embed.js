/* iframe init + demo-button wiring */
(async function () {
  const iframe = document.getElementById('flutterApp');

  // Choose iframe src at runtime so the HTML doesn't need editing for dev.
  const origin = location.origin;
  const search = location.search || '';
  const iframeUrl = search ? `${origin}${search}` : `${origin}/`;
  iframe.src = iframeUrl;
  console.info('embed.js: iframe src set to', iframeUrl);

  const response = await fetch('/data/simpsonsDemo.json');
  const demoKeys = await response.json();

  const aviv = document.getElementById('load-aviv');
  aviv?.addEventListener('click', function (ev) {
    ev.preventDefault();
    const AVIV = { crv: 'Ed25519', kty: 'OKP', x: 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo' };
    iframe.contentWindow.postMessage({ identity: AVIV, contentType: 'book', sort: 'like', follow: 'nerd' }, '*');
  });

  const lisa = document.getElementById('load-lisa');
  lisa?.addEventListener('click', function (ev) {
    ev.preventDefault();
    iframe.contentWindow.postMessage({ identity: demoKeys.lisa }, '*');
  });
})();
