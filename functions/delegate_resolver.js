/**
 * delegate_resolver.js — JS port of delegates.dart
 *
 * Resolves which delegate keys belong to which identities, using the trust
 * graph produced by TrustPipeline. Handles key replacement (predecessors),
 * domain filtering, and duplicate-claim conflicts ("first one wins").
 *
 * maxStatements controls how many statements to fetch per stream:
 *   Hablotengo uses 1 — each stream holds a single snapshot contact card.
 *   Nerdster uses Infinity — full history is needed for feed construction.
 *
 * Domain is read from schema.js so this file is identical across repos.
 */

const { getToken } = require('./jsonish_util');
const { domain: DOMAIN } = require('./schema');

const kSinceAlways = '<since always>';

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

class DelegateResolver {
  constructor(graph, oouCache, { maxStatements = Infinity } = {}) {
    this._equivalent2canonical = graph.equivalent2canonical;
    this._oouCache = oouCache;
    this.maxStatements = maxStatements;
    this._delegateToIdentity = new Map();   // delegateToken → canonicalIdentityToken
    this._delegateConstraints = new Map(); // delegateToken → revokeAt (kSinceAlways or stmt ID)
    this._identityToDelegates = new Map(); // canonicalIdentityToken → [delegateToken]
    this._resolvedIdentities  = new Set();
    this.notifications = [];
  }

  /**
   * Returns all identity keys in the equivalence group for a canonical identity:
   * the canonical itself plus all predecessors (replaced keys, transitively).
   */
  getEquivalenceGroup(canonicalToken) {
    const group = new Set([canonicalToken]);
    let changed = true;
    while (changed) {
      changed = false;
      for (const [old, canonical] of this._equivalent2canonical) {
        if (group.has(canonical) && !group.has(old)) {
          group.add(old);
          changed = true;
        }
      }
    }
    return [...group];
  }

  /**
   * Resolves delegates for a canonical identity from the oouCache.
   * Merges statements from all keys in the equivalence group (most recent first),
   * so the freshest state for each delegate key is seen first.
   * "First one to claim a delegate key wins" — duplicate claims across identities
   * are silently dropped and recorded in notifications.
   */
  _resolveForIdentity(canonicalToken) {
    if (this._resolvedIdentities.has(canonicalToken)) return;

    const group = this.getEquivalenceGroup(canonicalToken);
    const allStatements = mergeDesc(group.map(k => this._oouCache.get(k) || []));

    for (const stmt of allStatements) {
      if (!stmt.delegate || stmt.with?.domain !== DOMAIN) continue;
      const delegateToken = getToken(stmt.delegate);
      if (this._delegateToIdentity.has(delegateToken)) {
        if (this._delegateToIdentity.get(delegateToken) !== canonicalToken) {
          this.notifications.push({
            reason: `Delegate ${delegateToken} already claimed by ${this._delegateToIdentity.get(delegateToken)}`,
            isConflict: true,
          });
        }
        continue;
      }

      if (stmt.with?.revokeAt != null) {
        this._delegateConstraints.set(delegateToken, stmt.with.revokeAt);
      }
      this._delegateToIdentity.set(delegateToken, canonicalToken);
      this._identityToDelegates.set(canonicalToken,
        [...(this._identityToDelegates.get(canonicalToken) || []), delegateToken]);
    }
    this._resolvedIdentities.add(canonicalToken);
  }

  /** Returns all delegate keys authorized by the given canonical identity. */
  getDelegatesForIdentity(canonicalToken) {
    this._resolveForIdentity(canonicalToken);
    return this._identityToDelegates.get(canonicalToken) || [];
  }

  /** Returns the canonical identity for a delegate key, or null. */
  getIdentityForDelegate(delegateToken) {
    return this._delegateToIdentity.get(delegateToken) ?? null;
  }

  /** Returns the revokeAt constraint for a delegate key, or null. */
  getConstraintForDelegate(delegateToken) {
    return this._delegateConstraints.get(delegateToken) ?? null;
  }

  /**
   * Resolves delegates for every canonical identity in the oouCache.
   * Call this before getAllDelegateTokens() to ensure complete coverage.
   */
  resolveAll() {
    for (const token of this._oouCache.keys()) {
      if (!this._equivalent2canonical.has(token)) {
        this._resolveForIdentity(token);
      }
    }
  }

  /** Returns all delegate tokens across all resolved identities. */
  getAllDelegateTokens() {
    return new Set(this._delegateToIdentity.keys());
  }

}

module.exports = { DelegateResolver };
