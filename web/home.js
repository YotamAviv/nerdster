// Attach event listeners for controls that post messages to the embedded app.
// Uses explicit targetOrigin and validates incoming messages.
(function () {
  const IFRAME_ORIGIN = 'https://nerdster.web.app';
  const iframe = document.getElementById('flutterApp');
  if (!iframe) return;

  function safePostMessage(msg) {
    try {
      iframe.contentWindow.postMessage(msg, IFRAME_ORIGIN);
    } catch (e) {
      console.warn('postMessage failed', e);
    }
  }

  const aviv = document.getElementById('load-aviv');
  if (aviv) {
    aviv.addEventListener('click', function (ev) {
      ev.preventDefault();
      safePostMessage({
        identity: { crv: 'Ed25519', kty: 'OKP', x: 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo' },
        contentType: 'book',
        sort: 'like',
        follow: 'nerd'
      });
    });
  }

  const lisa = document.getElementById('load-lisa');
  if (lisa) {
    lisa.addEventListener('click', function (ev) {
      ev.preventDefault();
      safePostMessage({
        identity: { crv: 'Ed25519', kty: 'OKP', x: 'Ky4CcNdcoRi_OSA3Zr8OYgVoKDnGPpQwiZLtzYDIwBI' }
      });
    });
  }

  // Validate messages received from the iframe. Only accept messages from the
  // configured origin and with expected structure.
  window.addEventListener('message', function (ev) {
    if (ev.origin !== IFRAME_ORIGIN) return; // ignore others
    const d = ev.data;
    // basic validation example: expect object with type property or known keys
    if (d && typeof d === 'object') {
      // handle or log for debugging
      // console.debug('message from iframe', d);
    }
  }, false);
})();
