/**
 * Statement Fetcher
 *
 * Logic for fetching statements from Firestore and handling statement-specific
 * operations like distinctness filtering.
 */

const admin = require('firebase-admin');
const { order, getToken } = require('./jsonish_util');
const { statementsRef } = require('./schema');

const verbs = [
  'trust', 'delegate', 'clear', 'rate', 'follow', 'censor',
  'relate', 'dontRelate', 'equate', 'dontEquate', 'replace', 'block',
  'set',
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

    // Include statement type so DismissStatements (org.nerdster.dis) and ContentStatements
    // (org.nerdster) don't collide on the same subject token.
    const stmtType = s.statement;
    const key = otherToken
      ? stmtType + ':' + (subjectToken < otherToken ? subjectToken + otherToken : otherToken + subjectToken)
      : stmtType + ':' + subjectToken;

    if (seen.has(key)) continue;
    seen.add(key);
    distinct.push(s);
  }
  return distinct;
}

/**
 * Resolves a revokeAt token to a timestamp string, or null if not found.
 * All statements live in the 'statements' stream (see statementsRef in schema.js) — there is only one stream per key.
 * "<since always>" and any non-matching token both return null (revoke since genesis).
 */
async function resolveRevokeAtTime(revokeAtValue, collectionRef) {
  if (!revokeAtValue) return undefined;
  // short lived legacy format {revokeAt, streams} back when we tried supporing dis/statements streams.
  // DEFER: Clean up and remove once ONE-OF-US.NET phone app is updated and in the field.
  if (typeof revokeAtValue === 'object') revokeAtValue = revokeAtValue.revokeAt;
  
  if (typeof revokeAtValue !== 'string') return undefined;
  const snap = await collectionRef.doc(revokeAtValue).get();
  return snap.exists ? snap.data().time : null;
}

/**
 * Fetches statements from Firestore with various filters.
 *
 * PERFORMANCE CRITICAL: the omit/excludeTypes parameter exists because users dismiss
 * thousands of items but rate only dozens. Peer streams must omit dismiss statements
 * or the bandwidth cost becomes prohibitive.
 */
async function fetchStatements(token2revokeAt, params = {}, omit = []) {
  const { checkPrevious, distinct, orderStatements = true, includeId, after, excludeTypes } = params;

  if (!token2revokeAt) throw new Error('Missing token2revokeAt');
  const token = Object.keys(token2revokeAt)[0];
  const revokeAtValue = token2revokeAt[token];

  if (!token) throw new Error('Missing token');
  if (checkPrevious && !includeId) throw new Error('checkPrevious requires includeId');

  const db = admin.firestore();

  const collectionRef = statementsRef(db, token, 'statements');

  let revokeAtTime;
  if (revokeAtValue) {
    revokeAtTime = await resolveRevokeAtTime(revokeAtValue, collectionRef);
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

  // Exclude statement types
  if (excludeTypes) {
    const types = Array.isArray(excludeTypes) ? excludeTypes : [excludeTypes];
    statements = statements.filter(s => !types.includes(s.statement));
  }

  if (distinct && distinct !== 'false') {
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
};
