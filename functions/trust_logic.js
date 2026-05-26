/**
 * trust_logic.js — JavaScript port of trust_logic.dart
 *
 * Implements the same greedy BFS as the Dart Nerdster.
 * Source interface: { fetch(fetchMap: {[token]: null}) => Promise<{[token]: statement[]}> }
 */

const { getToken } = require('./jsonish_util');

const kSinceAlways = '<since always>';
const kDefaultMaxDegrees = 6;
const kTrustVerbs = ['trust', 'block', 'replace', 'clear', 'delegate'];

function permissivePathRequirement(_distance) {
  return 1;
}

function defaultPathRequirement(distance) {
  if (distance <= 3) return 1;
  if (distance <= 4) return 2;
  return 3;
}

function strictPathRequirement(distance) {
  if (distance <= 2) return 1;
  if (distance <= 3) return 2;
  return 3;
}

// ---------------------------------------------------------------------------
// Statement parsing
// ---------------------------------------------------------------------------

function getVerbSubject(s) {
  for (const verb of kTrustVerbs) {
    if (s[verb] != null) return { verb, subject: s[verb] };
  }
  return null;
}

async function parseStatements(statements) {
  return Promise.all(statements.map(async (s) => {
    const iToken = await getToken(s.I);
    const vs = getVerbSubject(s);
    const subjectToken = vs ? await getToken(vs.subject) : null;
    return {
      iToken,
      subjectToken,
      subjectPubKey: vs?.subject ?? null,
      verb: vs?.verb ?? null,
      revokeAt: s.with?.revokeAt ?? null,
      endpoint: s.with?.endpoint?.url ?? null,
      moniker: s.with?.moniker ?? null,
      raw: s,
    };
  }));
}

// ---------------------------------------------------------------------------
// Path-finding (node-disjoint BFS)
// ---------------------------------------------------------------------------

function _findShortestPath(start, end, graph, excluded) {
  const queue = [[start]];
  const visited = new Set([start, ...excluded]);

  while (queue.length > 0) {
    const path = queue.shift();
    const node = path[path.length - 1];
    if (node === end) return path;
    for (const neighbor of (graph.get(node) || [])) {
      if (!visited.has(neighbor)) {
        visited.add(neighbor);
        queue.push([...path, neighbor]);
      }
    }
  }
  return null;
}

function _findNodeDisjointPaths(root, target, graph, limit) {
  const paths = [];
  const excludedNodes = new Set();
  const usedPathStrings = new Set();

  while (paths.length < limit) {
    const path = _findShortestPath(root, target, graph, excludedNodes);
    if (!path) break;
    const pathString = path.join('->');
    if (usedPathStrings.has(pathString)) break;
    paths.push(path);
    usedPathStrings.add(pathString);
    for (let i = 1; i < path.length - 1; i++) excludedNodes.add(path[i]);
  }
  return paths;
}

// ---------------------------------------------------------------------------
// Core reducer — always rebuilds from scratch using all accumulated statements.
// Only current.pov is used from the current graph; everything else is recomputed.
// ---------------------------------------------------------------------------

async function reduceTrustGraph(pov, byIssuer, { pathRequirement, maxDegrees = kDefaultMaxDegrees, fedRegistry } = {}) {
  const req = pathRequirement || defaultPathRequirement;

  // Pre-parse all statements so BFS iteration is synchronous
  const parsed = new Map(); // issuerToken -> [parsedStatement]
  for (const [token, statements] of byIssuer) {
    parsed.set(token, await parseStatements(statements));
  }

  // Register any foreign endpoints discovered in this round of statements
  if (fedRegistry) {
    for (const stmtList of parsed.values()) {
      for (const s of stmtList) {
        if (s.endpoint && s.subjectToken) fedRegistry.set(s.subjectToken, s.endpoint);
      }
    }
  }

  const distances = new Map([[pov, 0]]);
  const orderedKeys = [pov];
  const equivalent2canonical = new Map();
  const blocked = new Set();
  const paths = new Map();
  const notifications = [];
  const edges = new Map();
  const trustedBy = new Map();
  const graphForPathfinding = new Map();
  const visited = new Set([pov]);
  const monikers = new Map(); // canonicalToken → string[] (in BFS order, first = best)
  const pubKeys = new Map(); // token → pubKeyJson

  // Collect pubKeys from self-signed statements (delegate statements signed by identity key).
  for (const [token, stmts] of parsed) {
    for (const s of stmts) {
      if (s.iToken === token && !pubKeys.has(token)) {
        pubKeys.set(token, s.raw.I);
        break;
      }
    }
  }

  function resolveCanonical(token) {
    let cur = token;
    const seen = new Set([token]);
    while (equivalent2canonical.has(cur)) {
      cur = equivalent2canonical.get(cur);
      if (seen.has(cur)) break;
      seen.add(cur);
    }
    return cur;
  }

  function addToGraph(from, to) {
    if (!graphForPathfinding.has(from)) graphForPathfinding.set(from, new Set());
    graphForPathfinding.get(from).add(to);
  }

  let currentLayer = new Set([pov]);

  for (let dist = 0; dist < maxDegrees && currentLayer.size > 0; dist++) {
    const nextLayer = new Set();

    // --- STAGE 1: BLOCKS ---
    for (const issuerToken of currentLayer) {
      const stmts = parsed.get(issuerToken) || [];
      const decided = new Set();
      for (const s of stmts) {
        if (s.verb !== 'block') continue;
        if (decided.has(s.subjectToken)) continue;
        decided.add(s.subjectToken);
        if (s.subjectToken === pov) {
          notifications.push({ reason: 'Attempt to block your key.', raw: s.raw, isConflict: true });
          continue;
        }
        if (distances.has(s.subjectToken) && distances.get(s.subjectToken) <= dist) {
          notifications.push({ reason: `Attempt to block trusted key by ${issuerToken}`, raw: s.raw, isConflict: true });
        } else {
          blocked.add(s.subjectToken);
        }
      }
    }

    // --- STAGE 2a: REPLACES ---
    for (const issuerToken of currentLayer) {
      let stmts = parsed.get(issuerToken) || [];
      if (equivalent2canonical.has(issuerToken)) stmts = [];

      const edgeStmts = stmts.filter(s => {
        if (s.verb === 'clear') return false;
        if (s.verb !== 'replace' && s.verb !== 'delegate' && s.revokeAt != null) return false;
        return true;
      });
      edges.set(issuerToken, edgeStmts);

      const decided = new Set();
      for (const s of stmts) {
        if (s.verb !== 'replace') continue;
        if (s.revokeAt !== kSinceAlways) {
          throw new Error(`replace with revokeAt other than <since always> is not supported: ${s.revokeAt}`);
        }
        const oldKey = s.subjectToken;
        if (decided.has(oldKey)) continue;
        decided.add(oldKey);

        if (oldKey === pov) {
          notifications.push({ reason: 'Attempt to replace your key.', raw: s.raw, isConflict: true });
          continue;
        }
        if (blocked.has(oldKey)) {
          notifications.push({ reason: `Blocked key ${oldKey} is being replaced by ${issuerToken}`, raw: s.raw, isConflict: false });
          continue;
        }
        if (distances.has(oldKey) && distances.get(oldKey) < dist) {
          if (!equivalent2canonical.has(oldKey)) equivalent2canonical.set(oldKey, issuerToken);
          notifications.push({ reason: `Trusted key ${oldKey} is being replaced by ${issuerToken} (Replacement constraint ignored due to distance)`, raw: s.raw, isConflict: false });
          continue;
        }
        if (equivalent2canonical.has(oldKey)) {
          const existing = equivalent2canonical.get(oldKey);
          if (existing !== issuerToken) {
            notifications.push({ reason: `Key ${oldKey} replaced by both ${existing} and ${issuerToken}`, raw: s.raw, isConflict: true });
            continue;
          }
        }
        if (distances.has(oldKey)) {
          notifications.push({ reason: `Trusted key ${oldKey} is being replaced by ${issuerToken}`, raw: s.raw, isConflict: false });
        }
        equivalent2canonical.set(oldKey, issuerToken);
        addToGraph(issuerToken, oldKey);
        if (!visited.has(oldKey)) {
          visited.add(oldKey);
          distances.set(oldKey, dist + 1);
          orderedKeys.push(oldKey);
          nextLayer.add(oldKey);
        }
      }
    }

    // --- STAGE 2b: TRUSTS ---
    for (const issuerToken of currentLayer) {
      let stmts = edges.get(issuerToken) || [];
      if (equivalent2canonical.has(issuerToken)) stmts = [];

      const decided = new Set();
      for (const s of stmts) {
        if (s.verb !== 'trust') continue;
        if (decided.has(s.subjectToken)) continue;
        decided.add(s.subjectToken);

        if (blocked.has(s.subjectToken)) {
          notifications.push({ reason: `Attempt to trust blocked key by ${issuerToken}`, raw: s.raw, isConflict: true });
          continue;
        }

        const effectiveSubject = resolveCanonical(s.subjectToken);
        if (blocked.has(effectiveSubject)) continue;

        if (!trustedBy.has(effectiveSubject)) trustedBy.set(effectiveSubject, new Set());
        trustedBy.get(effectiveSubject).add(issuerToken);

        const requiredPaths = req(dist + 1);
        const searchLimit = Math.max(requiredPaths, strictPathRequirement(dist + 1));
        for (const i of trustedBy.get(effectiveSubject)) addToGraph(i, effectiveSubject);

        const foundPaths = _findNodeDisjointPaths(pov, effectiveSubject, graphForPathfinding, searchLimit);
        if (foundPaths.length >= requiredPaths) {
          // Collect moniker (BFS order ensures first seen = from closest issuer).
          if (s.moniker) {
            if (!monikers.has(effectiveSubject)) monikers.set(effectiveSubject, []);
            const list = monikers.get(effectiveSubject);
            if (!list.includes(s.moniker)) list.push(s.moniker);
          }
          // Collect pubKey: use subject directly when it's the canonical token.
          if (s.subjectPubKey && s.subjectToken === effectiveSubject && !pubKeys.has(effectiveSubject)) {
            pubKeys.set(effectiveSubject, s.subjectPubKey);
          }
          paths.set(effectiveSubject, foundPaths);
          if (!visited.has(effectiveSubject)) {
            visited.add(effectiveSubject);
            distances.set(effectiveSubject, dist + 1);
            orderedKeys.push(effectiveSubject);
            nextLayer.add(effectiveSubject);
          }
          if (effectiveSubject !== s.subjectToken) {
            distances.set(s.subjectToken, dist + 1);
            if (!visited.has(s.subjectToken)) {
              visited.add(s.subjectToken);
              orderedKeys.push(s.subjectToken);
              nextLayer.add(s.subjectToken);
            }
          }
        }
      }
    }

    currentLayer = nextLayer;
  }

  // Deduplicate notifications
  const uniqueNotifications = new Map();
  for (const n of notifications) {
    const vs = getVerbSubject(n.raw);
    const subjectToken = vs ? await getToken(vs.subject) : await getToken(n.raw.I);
    const key = `${subjectToken}:${n.reason}`;
    if (!uniqueNotifications.has(key)) uniqueNotifications.set(key, n);
  }

  return {
    pov,
    distances,
    orderedKeys,
    equivalent2canonical,
    blocked,
    paths,
    notifications: [...uniqueNotifications.values()],
    monikers,
    pubKeys,
  };
}

module.exports = { reduceTrustGraph, permissivePathRequirement, defaultPathRequirement, strictPathRequirement, kSinceAlways, kDefaultMaxDegrees };
