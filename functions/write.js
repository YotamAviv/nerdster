/**
 * write — transactional statement append, shared by onCall (write) and onRequest (write2)
 *
 * Appends a signed statement to an issuer's statement stream in Firestore
 * using an atomic transaction on the stream's `head` field, eliminating the
 * TOCTOU race of the previous orderBy-based approach.
 *
 * Auth for the onRequest path is delegated to the project-supplied function:
 *   auth(req, res) → truthy on success, or sends error response and returns null.
 * For Nerdster, Ed25519 signature verification is the only auth needed (see auth_nerdster.js).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FIRESTORE PATH
 * ─────────────────────────────────────────────────────────────────────────────
 * {token(I)} / {collection} / statements / {token(statement)}
 *
 * The stream doc {token(I)}/{collection} carries a `head` field (token of the
 * most recent statement) and `headTime` field (its ISO-8601 time).
 *
 * Run bin/backfill_head.js once before deploying to seed `head`/`headTime` on
 * all existing streams. Not lazy: missing `head` is treated as genesis and will
 * corrupt existing streams if backfill hasn't run.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SHARED FILES (keep identical across nerdster14, oneofusv22)
 * ─────────────────────────────────────────────────────────────────────────────
 * verify_util.js, jsonish_util.js, statement_fetcher.js, export.js
 * (write.js diverges: nerdster14 uses onRequest/write2 pattern; oneofusv22 keeps
 * the original onCall write.js and adds write2.js as a separate file)
 */

const admin = require('firebase-admin');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

/**
 * Core transaction. Validates and appends the statement.
 * Throws with err.code 400 or 409 for client errors; plain Error for server errors.
 * @returns {{ token: string }}
 */
async function writeCore(statement, collection) {
  if (!statement || typeof statement !== 'object') {
    const err = new Error('missing statement');
    err.code = 400;
    throw err;
  }
  if (!collection || typeof collection !== 'string') {
    const err = new Error('missing collection');
    err.code = 400;
    throw err;
  }
  if (!verifyStatementSignature(statement)) {
    const err = new Error('invalid statement signature');
    err.code = 400;
    throw err;
  }

  const iToken = await keyToken(statement['I']);
  const token = await statementToken(statement);
  const clientPrevious = statement['previous'] ?? null;
  const clientTime = statement['time'] ?? null;

  const db = admin.firestore();
  const streamRef = db.collection(iToken).doc(collection);
  const statementsRef = streamRef.collection('statements');

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

  console.log(`[write] token=${token} issuer=${iToken} stream=${collection}`);
  return { token };
}

/**
 * onCall handler — for existing clients using the Firebase callable protocol.
 * Throws; the caller (index.js) maps err.code to HttpsError.
 */
async function handleWriteCallable(data) {
  const { statement, collection } = data ?? {};
  return await writeCore(statement, collection);
}

/**
 * onRequest handler factory — for new clients using write2.
 * @param {Function} auth - async (req, res) => truthy | null
 */
function makeWriteHandler(auth) {
  return async function handleWrite(req, res) {
    res.setHeader('Content-Type', 'application/json');

    const authResult = await auth(req, res);
    if (!authResult) return;

    try {
      const result = await writeCore(req.body?.statement, req.body?.collection);
      res.status(200).json(result);
    } catch (e) {
      const status = e.code === 409 ? 409 : e.code === 400 ? 400 : 500;
      if (status === 500) console.error('[write] error:', e.message);
      res.status(status).json({ error: e.message });
    }
  };
}

module.exports = { handleWriteCallable, makeWriteHandler };
