/**
 * write — Firebase onCall endpoint
 *
 * Appends a signed statement to an issuer's statement stream in Firestore.
 * Uses orderBy for chain validation (not transactional — has TOCTOU race on
 * concurrent writes from multiple devices).
 *
 * Lazily seeds `head`/`headTime` on the stream document if missing, and keeps
 * them current after every write. This lets write2 (transactional) safely
 * coexist once all streams have `head` (via lazy seeding or backfill_head.js).
 *
 * Shared file — keep identical across nerdster14, oneofusv22.
 */

const admin = require('firebase-admin');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

async function handleWrite(data) {
  const { statement, collection } = data ?? {};

  if (!statement || typeof statement !== 'object') throw new Error('missing statement');
  if (!collection || typeof collection !== 'string') throw new Error('missing collection');
  if (!verifyStatementSignature(statement)) throw new Error('invalid statement signature');

  const iToken = await keyToken(statement['I']);
  const token = await statementToken(statement);
  const clientPrevious = statement['previous'] ?? null;
  const clientTime = statement['time'] ?? null;

  const db = admin.firestore();
  const streamRef = db.collection(iToken).doc(collection);
  const statementsRef = streamRef.collection('statements');

  // Use head field if present; fall back to orderBy to lazily seed it.
  const streamDoc = await streamRef.get();
  let currentHead, currentHeadTime;
  if (streamDoc.exists && streamDoc.data().head !== undefined) {
    currentHead = streamDoc.data().head ?? null;
    currentHeadTime = streamDoc.data().headTime ?? null;
  } else {
    const latestSnap = await statementsRef.orderBy('time', 'desc').limit(1).get();
    currentHead = latestSnap.empty ? null : latestSnap.docs[0].id;
    currentHeadTime = latestSnap.empty ? null : (latestSnap.docs[0].data()['time'] ?? null);
  }

  if (clientPrevious !== currentHead) {
    throw new Error(`previous mismatch: expected ${currentHead}, got ${clientPrevious}`);
  }
  if (currentHeadTime !== null && clientTime !== null && clientTime <= currentHeadTime) {
    throw new Error(`time ordering violation: ${clientTime} must be > ${currentHeadTime}`);
  }

  await statementsRef.doc(token).set(statement);
  await streamRef.set({ head: token, headTime: clientTime }, { merge: true });

  console.log(`[write] token=${token} issuer=${iToken} stream=${collection}`);
  return { token };
}

module.exports = { handleWrite };
