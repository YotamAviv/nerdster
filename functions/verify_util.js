/**
 * Ed25519 signature verification for one-of-us statements.
 *
 * Mirrors the Dart logic in:
 *   oneofus_common/lib/crypto/crypto25519.dart  →  _PublicKey.verifySignature()
 *   oneofus_common/lib/oou_verifier.dart        →  OouVerifier.verify()
 *   oneofus_common/lib/jsonish.dart             →  Jsonish.makeVerify()
 */

const crypto = require('crypto');
const { order, computeSHA1 } = require('./jsonish_util');

/**
 * Computes the cleartext that was signed: canonical pretty-print without the signature field.
 */
function statementCleartext(statement) {
  const withoutSig = Object.fromEntries(
    Object.entries(statement).filter(([k]) => k !== 'signature')
  );
  return JSON.stringify(order(withoutSig), null, 2);
}

/**
 * Computes the token (SHA1) of a statement including its signature.
 */
function statementToken(statement) {
  return computeSHA1(JSON.stringify(order(statement), null, 2));
}

/**
 * Computes the token of a key (JWK object), used for chain matching.
 */
function keyToken(jwk) {
  return computeSHA1(JSON.stringify(order(jwk), null, 2));
}

/**
 * Verifies the Ed25519 signature on a single statement.
 * The statement's `I` field must be a JWK ({"crv":"Ed25519","kty":"OKP","x":"..."}).
 * The `signature` field must be a lowercase hex string.
 *
 * Returns true if valid, false if invalid or malformed.
 */
function verifyStatementSignature(statement) {
  try {
    const jwk = statement['I'];
    if (!jwk || typeof jwk !== 'object') return false;
    const signatureHex = statement['signature'];
    if (!signatureHex || typeof signatureHex !== 'string') return false;

    const publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
    const cleartext = statementCleartext(statement);
    const sigBytes = Buffer.from(signatureHex, 'hex');

    return crypto.verify(null, Buffer.from(cleartext), publicKey, sigBytes);
  } catch {
    return false;
  }
}

module.exports = { verifyStatementSignature, statementCleartext, statementToken, keyToken };
