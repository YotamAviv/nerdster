/**
 * Statement Fetcher
 *
 * Logic for fetching statements from Firestore and handling statement-specific
 * operations like distinctness filtering.
 */

const admin = require('firebase-admin');
const { order, getToken } = require('./jsonish_util');

const verbs = [
  'trust', 'delegate', 'clear', 'rate', 'follow', 'censor',
  'relate', 'dontRelate', 'equate', 'dontEquate', 'replace', 'block',
];

/**
 * Extracts the verb and subject from a statement.
 */
function getVerbSubject(j) {
  for (const verb of verbs) {
    if (j[verb] != null) return [verb, j[verb]];
  }
  return null;
}

/**
 * Extracts the 'other' subject if present.
 */
function getOtherSubject(j) {
  return j.with?.otherSubject;
}

/**
 * Filters a list of statements to keep only distinct ones based on verb/subject.
 */
async function makedistinct(input) {
  const distinct = [];
  const seen = new Set();

  for (const s of input) {
    const vs = getVerbSubject(s);
    if (!vs) continue;

    const [verb, subject] = vs;
    const subjectToken = await getToken(subject);
    const otherSubject = getOtherSubject(s);
    const otherToken = otherSubject ? await getToken(otherSubject) : null;

    // Create a stable key for the pair
    const key = otherToken
      ? (subjectToken < otherToken ? subjectToken + otherToken : otherToken + subjectToken)
      : subjectToken;

    if (seen.has(key)) continue;
    seen.add(key);
    distinct.push(s);
  }
  return distinct;
}

/**
 * Resolves a revokeAt value to a timestamp string, or null if not found.
 *
 * revokeAtValue may be:
 *   - null/undefined: no revocation (caller should not call this)
 *   - string: legacy format — look up the token in the primary collectionRef only.
 *             "<since always>" and any non-matching token both return null (revoke since genesis).
 *   - {revokeAt: token, streams: [streamId, ...]}: new format — search listed streams.
 *             streamId is the Firestore doc segment; the collection is always "statements".
 */
async function resolveRevokeAtTime(db, keyToken, revokeAtValue, primaryCollectionRef) {
  if (!revokeAtValue) return undefined; // no revocation

  if (typeof revokeAtValue === 'string') {
    // Legacy: search primary stream only. "<since always>" won't match anything → returns null.
    const snap = await primaryCollectionRef.doc(revokeAtValue).get();
    return snap.exists ? snap.data().time : null;
  }

  if (revokeAtValue.revokeAt) {
    // New format: search listed streams for the token.
    const streams = revokeAtValue.streams ?? ['statements'];
    for (const streamId of streams) {
      const ref = db.collection(keyToken).doc(streamId).collection('statements');
      const snap = await ref.doc(revokeAtValue.revokeAt).get();
      if (snap.exists) return snap.data().time;
    }
    return null; // not found in any stream → revoke since genesis
  }

  return undefined; // unrecognized format, ignore
}

/**
 * Fetches statements from Firestore with various filters.
 *
 * subcollection param format: "docSegment/colSegment" (default: "statements/statements")
 * This selects which stream to serve: {keyToken}/{docSegment}/{colSegment}/{statementToken}
 */
async function fetchStatements(token2revokeAt, params = {}, omit = []) {
  const { checkPrevious, distinct, orderStatements = true, includeId, after, subcollection } = params;

  if (!token2revokeAt) throw new Error('Missing token2revokeAt');
  const token = Object.keys(token2revokeAt)[0];
  const revokeAtValue = token2revokeAt[token];

  if (!token) throw new Error('Missing token');
  if (checkPrevious && !includeId) throw new Error('checkPrevious requires includeId');

  const db = admin.firestore();

  // Parse subcollection: "docSeg/colSeg", default "statements/statements"
  const subPath = (typeof subcollection === 'string' ? subcollection : null) || 'statements/statements';
  const slashIdx = subPath.indexOf('/');
  const docSeg = slashIdx >= 0 ? subPath.slice(0, slashIdx) : 'statements';
  const colSeg = slashIdx >= 0 ? subPath.slice(slashIdx + 1) : 'statements';

  const collectionRef = db.collection(token).doc(docSeg).collection(colSeg);

  let revokeAtTime;
  if (revokeAtValue) {
    revokeAtTime = await resolveRevokeAtTime(db, token, revokeAtValue, collectionRef);
    if (revokeAtTime === null) return []; // revoke since genesis
  }

  let query = collectionRef.orderBy('time', 'desc');
  if (revokeAtTime) {
    query = query.where('time', "<=", revokeAtTime);
  } else if (after) {
    query = query.where('time', ">", after);
  }

  const snapshot = await query.get();
  let statements = snapshot.docs.map(doc => {
    const data = doc.data();
    return includeId ? { id: doc.id, ...data } : data;
  });

  // Notarization check
  if (checkPrevious) {
    let prevToken, prevTime;
    for (const s of statements) {
      if (prevToken && s.id !== prevToken) {
        throw new Error(`Notarization violation: ${s.id} != ${prevToken}`);
      }
      if (prevTime && s.time >= prevTime) {
        throw new Error(`Ordering violation: ${s.time} >= ${prevTime}`);
      }
      prevToken = s.previous;
      prevTime = s.time;
    }
    if (!after && prevToken) {
      throw new Error(`Notarization violation: Chain ends prematurely at ${prevToken}`);
    }
  }

  // Omit keys
  if (omit && Array.isArray(omit)) {
    for (const s of statements) {
      for (const key of omit) delete s[key];
    }
  }

  if (distinct) {
    statements = await makedistinct(statements);
  }

  if (orderStatements) {
    statements = statements.map(order);
  }

  return statements;
}

module.exports = {
  fetchStatements,
  makedistinct,
  resolveRevokeAtTime,
};
