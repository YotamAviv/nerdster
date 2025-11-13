/**
 * home.js
 *
 * Small, unobtrusive glue code for the landing page that posts messages to the
 * embedded Nerdster app iframe. This file intentionally keeps the runtime
 * behaviour minimal and documents the message contract for maintainers.
 *
 * IFRAME_ORIGIN: the expected origin of the embedded app used when calling
 * window.postMessage(msg, IFRAME_ORIGIN) and when validating incoming messages.
 *
 * Outgoing message shape (example):
 * {
 *   identity: { crv: 'Ed25519', kty: 'OKP', x: 'BASE64URL' },
 *   contentType?: 'book',
 *   sort?: 'like',
 *   follow?: 'nerd'
 * }
 *
 * Incoming messages: only objects from IFRAME_ORIGIN are accepted; handlers
 * should validate the structure before acting.
 */
(function () {
  const IFRAME_ORIGIN = 'https://nerdster.org';
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
