(function () {
  const iframe = document.getElementById('flutterApp');

  // Choose iframe src at runtime. Useful so you don't have to edit HTML to
  // point at localhost during development.
  const origin = location.origin;
  // Forward all query params from the parent URL to the iframe so any dev
  // flags (like ?fire=emulator) are preserved automatically.
  const search = location.search || '';
  const iframeUrl = search ? `${origin}${search}` : `${origin}/`;
  iframe.src = iframeUrl;
  console.info('home.js: iframe src set to', iframeUrl);

  // existing demo handlers
  const aviv = document.getElementById('load-aviv');
  aviv.addEventListener('click', function (ev) {
    ev.preventDefault();
    const AVIV = { crv: 'Ed25519', kty: 'OKP', x: 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo' };
    iframe.contentWindow.postMessage({ identity: AVIV, contentType: 'book', sort: 'like', follow: 'nerd' }, '*');
  });

  const lisa = document.getElementById('load-lisa');
  lisa.addEventListener('click', function (ev) {
    ev.preventDefault();
    const LISA = { crv: 'Ed25519', kty: 'OKP', x: 'Ky4CcNdcoRi_OSA3Zr8OYgVoKDnGPpQwiZLtzYDIwBI' };
    iframe.contentWindow.postMessage({ identity: LISA }, '*');
  });
})();
