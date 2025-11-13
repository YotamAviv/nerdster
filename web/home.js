(function () {
  function assert(cond, msg) {
    if (!cond) throw new Error(msg || 'Assertion failed');
  }

  const iframe = document.getElementById('flutterApp');
  assert(iframe, 'home.js: iframe #flutterApp not found');
  assert(iframe.contentWindow, 'home.js: iframe has no contentWindow');

  const aviv = document.getElementById('load-aviv');
  assert(aviv, 'home.js: #load-aviv not found');
  aviv.addEventListener('click', function (ev) {
    ev.preventDefault();
    const AVIV = { crv: 'Ed25519', kty: 'OKP', x: 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo' };
    iframe.contentWindow.postMessage({ identity: AVIV, contentType: 'book', sort: 'like', follow: 'nerd' }, '*');
  });

  const lisa = document.getElementById('load-lisa');
  assert(lisa, 'home.js: #load-lisa not found');
  lisa.addEventListener('click', function (ev) {
    ev.preventDefault();
    const LISA = { crv: 'Ed25519', kty: 'OKP', x: 'Ky4CcNdcoRi_OSA3Zr8OYgVoKDnGPpQwiZLtzYDIwBI' };
    iframe.contentWindow.postMessage({ identity: LISA }, '*');
  });
})();
