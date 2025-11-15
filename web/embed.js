/* iframe init + demo-button wiring */
(function () {
  const iframe = document.getElementById('flutterApp');

  if (!iframe) return;

  // Choose iframe src at runtime so the HTML doesn't need editing for dev.
  const origin = location.origin;
  const search = location.search || '';
  const iframeUrl = search ? `${origin}${search}` : `${origin}/`;
  try {
    iframe.src = iframeUrl;
    console.info('embed.js: iframe src set to', iframeUrl);
  } catch (e) {
    console.warn('embed.js: failed to set iframe src', e);
  }

  // Demo buttons that postMessage into the embedded iframe
  const aviv = document.getElementById('load-aviv');
  aviv?.addEventListener('click', function (ev) {
    ev.preventDefault();
    const AVIV = { crv: 'Ed25519', kty: 'OKP', x: 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo' };
    try {
      iframe.contentWindow.postMessage({ identity: AVIV, contentType: 'book', sort: 'like', follow: 'nerd' }, '*');
    } catch (e) {
      console.warn('embed.js: failed to postMessage AVIV', e);
    }
  });

  const lisa = document.getElementById('load-lisa');
  lisa?.addEventListener('click', function (ev) {
    ev.preventDefault();
    const LISA = { crv: 'Ed25519', kty: 'OKP', x: 'Ky4CcNdcoRi_OSA3Zr8OYgVoKDnGPpQwiZLtzYDIwBI' };
    try {
      iframe.contentWindow.postMessage({ identity: LISA }, '*');
    } catch (e) {
      console.warn('embed.js: failed to postMessage LISA', e);
    }
  });
})();
