/* crypto.js — wire two iframes and demo controls
   Behavior inspired by embed.js and home2.js
*/
(async function () {
  const iframe = document.getElementById('flutterApp');

  // Set iframe src to current origin (or origin+search) like embed.js
  const origin = location.origin;
  const search = location.search || '';
  const iframeUrl = search ? `${origin}${search}` : `${origin}/`;

  const verify = `{
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "zL9yVkfRj6Pt4qWy9KoUq_p0ff7s4p-Qm1aeGghlJGU"
  },
  "declaration": "I am not a robot!",
  "signature": "51b0c2ea2554c42a2f6ef3aa47cd54d864da66d1ff40da21b94c5062a2b03eb9f5b3eb79b1a2515ae2e1699583dc9222c8f5a309bb3bf33d101e2e3ea3bc8804"
}`;

  const verfyParam = encodeURIComponent(verify);
  const sep = iframeUrl.includes('?') ? '&' : '?';
  iframe.src = iframeUrl + sep + 'verify=' + verfyParam;
  console.info('crypto.js: iframeUrl=', iframeUrl);
})();
