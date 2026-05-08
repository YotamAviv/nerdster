/**
 * write2 — shared HTTP POST endpoint (onRequest), transactional
 *
 * Appends a signed statement to an issuer's statement stream in Firestore
 * using an atomic transaction on the stream's `head` field, eliminating the
 * TOCTOU race of the orderBy-based approach in write.js.
 *
 * Requires bin/backfill_head.js to have been run first to seed `head`/`headTime`
 * on all existing streams before this endpoint receives traffic.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * REQUEST
 * ─────────────────────────────────────────────────────────────────────────────
 * POST {baseUrl}/write2
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
 * most recent statement) and `headTime` field (its ISO-8601 time).
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
 * write2.js, verify_util.js, jsonish_util.js, statement_fetcher.js, export.js
 */

const admin = require('firebase-admin');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

/**
 * Returns an HTTP request handler for the write2 endpoint.
 * @param {Function} auth - async (req, res) => truthy | null
 */
function makeWrite2Handler(auth) {
  return async function handleWrite2(req, res) {
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
      console.error('[write2] transaction error:', e.message);
      res.status(500).json({ error: e.message });
      return;
    }

    console.log(`[write2] token=${token} issuer=${iToken} stream=${collection}`);
    res.status(200).json({ token });
  };
}

module.exports = { makeWrite2Handler };
