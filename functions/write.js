/**
 * write — shared HTTP POST endpoint (onRequest)
 *
 * Appends a signed statement to an issuer's statement stream in Firestore
 * using an atomic transaction on the stream's `head` field, eliminating the
 * TOCTOU race of the previous orderBy-based approach.
 *
 * Auth is delegated to the project-supplied function:
 *   auth(req, res) → truthy on success, or sends error response and returns null.
 * For Nerdster, Ed25519 signature verification is the only auth needed (see auth_nerdster.js).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * REQUEST
 * ─────────────────────────────────────────────────────────────────────────────
 * POST {baseUrl}/write
 * Content-Type: application/json
 *
 * Body:
 * {
 *   "statement":  <Statement>,   // required
 *   "collection": <string>       // required — stream name, e.g. "statements" or "dis"
 * }
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FIRESTORE PATH
 * ─────────────────────────────────────────────────────────────────────────────
 * {token(I)} / {collection} / statements / {token(statement)}
 *
 * The stream doc {token(I)}/{collection} carries a `head` field (token of the
 * most recent statement) and `headTime` field (its ISO-8601 time), used by the
 * transaction to enforce chain integrity without an extra document read.
 *
 * Run bin/backfill_head.js once before deploying to seed `head`/`headTime` on
 * all existing streams.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * RESPONSE
 * ─────────────────────────────────────────────────────────────────────────────
 * 200: { "token": <statementToken> }
 * 400: bad request (missing fields, invalid signature, time ordering violation)
 * 409: chain race — client should fetch latest head and retry
 * 500: unexpected server error
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SHARED FILES (keep identical across nerdster14, oneofusv22)
 * ─────────────────────────────────────────────────────────────────────────────
 * write.js, verify_util.js, jsonish_util.js, statement_fetcher.js, export.js
 */

const admin = require('firebase-admin');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

/**
 * Returns an HTTP request handler for the write endpoint.
 * @param {Function} auth - async (req, res) => truthy | null
 */
function makeWriteHandler(auth) {
  return async function handleWrite(req, res) {
    res.setHeader('Content-Type', 'application/json');

    const authResult = await auth(req, res);
    if (!authResult) return;

    const { statement, collection } = req.body ?? {};

    if (!statement || typeof statement !== 'object') {
      res.status(400).json({ error: 'missing statement' });
      return;
    }
    if (!collection || typeof collection !== 'string') {
      res.status(400).json({ error: 'missing collection' });
      return;
    }
    if (!verifyStatementSignature(statement)) {
      res.status(400).json({ error: 'invalid statement signature' });
      return;
    }

    const iToken = await keyToken(statement['I']);
    const token = await statementToken(statement);
    const clientPrevious = statement['previous'] ?? null;
    const clientTime = statement['time'] ?? null;

    const db = admin.firestore();
    const streamRef = db.collection(iToken).doc(collection);
    const statementsRef = streamRef.collection('statements');

    try {
      await db.runTransaction(async (tx) => {
        const streamDoc = await tx.get(streamRef);
        const currentHead = streamDoc.exists ? (streamDoc.data().head ?? null) : null;
        const currentHeadTime = streamDoc.exists ? (streamDoc.data().headTime ?? null) : null;

        if (clientPrevious !== currentHead) {
          const err = new Error(`chain race: expected ${currentHead}, got ${clientPrevious}`);
          err.code = 409;
          throw err;
        }
        if (currentHeadTime !== null && clientTime !== null && clientTime <= currentHeadTime) {
          const err = new Error(`time ordering violation: ${clientTime} must be > ${currentHeadTime}`);
          err.code = 400;
          throw err;
        }

        tx.set(statementsRef.doc(token), statement);
        tx.set(streamRef, { head: token, headTime: clientTime }, { merge: true });
      });
    } catch (e) {
      if (e.code === 409) {
        res.status(409).json({ error: e.message });
        return;
      }
      if (e.code === 400) {
        res.status(400).json({ error: e.message });
        return;
      }
      console.error('[write] transaction error:', e.message);
      res.status(500).json({ error: e.message });
      return;
    }

    console.log(`[write] token=${token} issuer=${iToken} stream=${collection}`);
    res.status(200).json({ token });
  };
}

module.exports = { makeWriteHandler };
