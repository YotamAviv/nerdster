/**
 * Nerdster write auth.
 *
 * Ed25519 signature verification (handled in write.js) is the only
 * authorization Nerdster needs. No session credential required.
 */

async function auth(req, res) {
  return {};
}

module.exports = { auth };
