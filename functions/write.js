/**
 * write — HTTP POST endpoint
 *
 * Appends a signed statement to an issuer's statement stream in Firestore.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * REQUEST
 * ─────────────────────────────────────────────────────────────────────────────
 * POST {baseUrl}/write
 * Content-Type: application/json
 *
 * Body (Firebase callable envelope):
 * {
 *   "data": {
 *     "statement": <Statement>,   // required — the signed statement object
 *     "collection": <string>      // required — stream name, e.g. "statements" or "dis"
 *   }
 * }
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * STATEMENT FORMAT
 * ─────────────────────────────────────────────────────────────────────────────
 * A statement is a JSON object with the following fields:
 *
 * {
 *   "I":         <PublicKey>,   // issuer's public key (JSON object, canonically ordered)
 *   "time":      <ISO 8601>,    // statement timestamp
 *   "previous":  <token>,       // optional — token of the previous statement in this stream
 *                               //            omit (or null) for the first statement
 *   ...                         // verb-specific fields (verb, subject, object, etc.)
 *   "signature": <base64>       // Ed25519 signature over the canonically ordered statement
 *                               //   (excluding the "signature" field itself)
 * }
 *
 * The token of a statement is the SHA-1 of its canonical JSON representation
 * (all fields including signature, keys ordered deterministically).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * CHAIN INTEGRITY (previous + time)
 * ─────────────────────────────────────────────────────────────────────────────
 * Each issuer maintains an append-only chain per collection.
 * The server enforces:
 *   - First write: "previous" must be absent or null.
 *   - Subsequent writes: "previous" must equal the token of the latest statement
 *     currently in the stream (ordered by "time" desc).
 *   - "time" must be strictly greater than the latest statement's time, so the
 *     stream can always be fetched in strict descending order.
 * Concurrent writes by the same issuer are serialized by the client-side write
 * queue in CloudFunctionsWriter.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SECURITY
 * ─────────────────────────────────────────────────────────────────────────────
 * No Firebase Auth or App Check is required — the endpoint is publicly callable.
 * Authorization is provided entirely by the Ed25519 signature: the server verifies
 * the signature before writing, so only the holder of the private key can append
 * to a given issuer's stream.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FIRESTORE PATH
 * ─────────────────────────────────────────────────────────────────────────────
 * {token(I)} / {collection} / statements / {token(statement)}
 *
 * The issuer token scopes each write to the issuer's own subtree.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * RESPONSE
 * ─────────────────────────────────────────────────────────────────────────────
 * 200 OK: { "result": { "token": <statementToken> } }
 * Error: HTTP 500, body contains error message (previous mismatch, bad signature, etc.)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * EMULATOR BASE URLs
 * ─────────────────────────────────────────────────────────────────────────────
 * Nerdster:    http://127.0.0.1:5001/nerdster/us-central1
 * ONE-OF-US:  http://127.0.0.1:5002/one-of-us-net/us-central1
 */

const admin = require('firebase-admin');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

async function handleWrite(data, context) {
  const { statement, collection } = data ?? {};

  if (!statement || typeof statement !== 'object') {
    throw new Error('missing statement');
  }
  if (!verifyStatementSignature(statement)) {
    throw new Error('invalid statement signature');
  }

  const iToken = await keyToken(statement['I']);
  const token = await statementToken(statement);
  const db = admin.firestore();

  const statementsRef = db
    .collection(iToken)
    .doc(collection)
    .collection('statements');

  const latestSnap = await statementsRef.orderBy('time', 'desc').limit(1).get();
  const latestToken = latestSnap.empty ? null : latestSnap.docs[0].id;
  const latestTime = latestSnap.empty ? null : latestSnap.docs[0].data()['time'];
  const clientPrevious = statement['previous'] ?? null;
  const clientTime = statement['time'] ?? null;

  if (latestToken === null && clientPrevious !== null) {
    throw new Error('genesis check failed: statement.previous must not be set for first write');
  }
  if (latestToken !== null && clientPrevious !== latestToken) {
    throw new Error(`previous mismatch: expected ${latestToken}, got ${clientPrevious}`);
  }
  if (latestTime !== null && clientTime !== null && clientTime <= latestTime) {
    throw new Error(`time ordering violation: ${clientTime} must be > ${latestTime}`);
  }

  await statementsRef.doc(token).set(statement);

  return { token };
}

module.exports = { handleWrite };
