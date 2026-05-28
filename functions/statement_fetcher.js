/**
 * Statement Fetcher
 *
 * Logic for fetching statements from Firestore and handling statement-specific
 * operations like distinctness filtering.
 */

const admin = require('firebase-admin');
const { order, getToken } = require('./jsonish_util');
const { statementsRef, delegateStreamKey } = require('./schema');

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
async function fetchStatements(token2revokeAt, params = {}, omit = [], db = null) {
  const { checkPrevious, distinct, orderStatements = true, includeId, after, excludeTypes, limit } = params;

  if (!token2revokeAt) throw new Error('Missing token2revokeAt');
  const token = Object.keys(token2revokeAt)[0];
  const revokeAtValue = token2revokeAt[token];

  if (!token) throw new Error('Missing token');
  if (checkPrevious && !includeId) throw new Error('checkPrevious requires includeId');

  db = db || admin.firestore();

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
  if (limit) query = query.limit(limit);

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

/**
 * Fetches multiple streams in parallel.
 * Returns token → statements[] on success, token → { error } on per-token failure.
 * JS-layer equivalent of oneofusSource.fetch() — same shape, no HTTP.
 */
async function fetchStatementsBatch(token2revokeAt, params = {}, omit = [], db = null) {
  const entries = Object.entries(token2revokeAt);
  const settled = await Promise.allSettled(
    entries.map(([token, revokeAt]) => fetchStatements({ [token]: revokeAt }, params, omit, db))
  );
  return Object.fromEntries(
    entries.map(([token], i) => {
      const r = settled[i];
      return [token, r.status === 'fulfilled' ? r.value : { error: r.reason.message }];
    })
  );
}

/** Merges k pre-sorted (time descending) arrays into one. */
function mergeDesc(arrays) {
  const ptrs = arrays.map(() => 0);
  const result = [];
  for (;;) {
    let best = -1;
    for (let i = 0; i < arrays.length; i++) {
      if (ptrs[i] < arrays[i].length &&
          (best === -1 || arrays[i][ptrs[i]].time > arrays[best][ptrs[best]].time))
        best = i;
    }
    if (best === -1) break;
    result.push(arrays[best][ptrs[best]++]);
  }
  return result;
}

/**
 * Fetches statements from all delegate streams for a canonical identity.
 * Uses the resolver's public API to get delegates, equivalence group, and constraints.
 */
async function fetchDelegateStatements(resolver, identityToken, params = {}, db = null) {
  const delegates = resolver.getDelegatesForIdentity(identityToken);
  if (delegates.length === 0) return [];

  const group = resolver.getEquivalenceGroup(identityToken);
  const fetchParams = { ...params };
  if (resolver.maxStatements !== Infinity) fetchParams.limit = resolver.maxStatements;

  const arrays = await Promise.all(group.flatMap(idToken =>
    delegates.map(async (delegateToken) => {
      const constraint = resolver.getConstraintForDelegate(delegateToken) ?? null;
      const key = delegateStreamKey(delegateToken, idToken);
      return fetchStatements({ [key]: constraint }, fetchParams, [], db);
    })
  ));

  return mergeDesc(arrays);
}

module.exports = {
  fetchStatements,
  fetchStatementsBatch,
  fetchDelegateStatements,
  makedistinct,
};
