/**
 * Jsonish Utilities
 * 
 * Core logic for handling "Jsonish" objects, including canonical ordering,
 * token generation (SHA1), and fetching statements from Firestore.
 */

const crypto = require('crypto');

/**
 * Canonical order for keys in a statement.
 *
 * ⚠️  CRITICAL — MUST STAY IN SYNC WITH DART:
 *   oneofus_common/lib/jsonish.dart  →  Jsonish.keysInOrder
 *
 * The integers here must exactly match the indexOf() positions from the Dart list.
 * To regenerate, enable the 'print key2order' unit test in jsonish_test.dart
 * (change `if (false)` to `if (true)`) and run:
 *   flutter test packages/oneofus_common/test/jsonish_test.dart --name "print key2order"
 * Then paste the output here.
 *
 * Last synced output:
 *   endpoint: 27, comment: 28, contentType: 29, previous: 30, signature: 31
 */
const key2order = {
  "statement": 0,
  "time": 1,
  "I": 2,
  "trust": 3,
  "block": 4,
  "replace": 5,
  "delegate": 6,
  "clear": 7,
  "rate": 8,
  "relate": 9,
  "dontRelate": 10,
  "equate": 11,
  "dontEquate": 12,
  "follow": 13,
  "enter": 15, // hablotengo: contact entry verb (not used here, kept in sync)
  "set": 16, // hablotengo: set named field verb (not used here, kept in sync)
  "with": 17,
  "other": 18,
  "moniker": 19,
  "revokeAt": 20,
  "domain": 21,
  "tags": 22,
  "recommend": 23,
  "dismiss": 24,
  "censor": 25,
  "stars": 26,
  "endpoint": 27,
  "comment": 28,
  "contentType": 29,
  "previous": 30,
  "signature": 31
};

/**
 * Computes SHA1 hash of a string.
 */
async function computeSHA1(str) {
  return crypto.createHash('sha1').update(str).digest('hex');
}

/**
 * Compares two keys based on the canonical order.
 */
function compareKeys(key1, key2) {
  const i1 = key2order[key1];
  const i2 = key2order[key2];
  if (i1 != null && i2 != null) return i1 - i2;
  if (i1 == null && i2 == null) return key1 < key2 ? -1 : 1;
  return i1 != null ? -1 : 1;
}

/**
 * Recursively orders an object's keys canonically.
 */
function order(thing) {
  if (thing === null || typeof thing !== 'object') return thing;
  
  if (Array.isArray(thing)) {
    return thing.map(order);
  }

  const signature = thing.signature;
  const keys = Object.keys(thing).filter(k => k !== 'signature').sort(compareKeys);
  
  const out = {};
  for (const key of keys) {
    out[key] = order(thing[key]);
  }
  if (signature) out.signature = signature;
  return out;
}

/**
 * Generates a unique token for a thing (string or object).
 */
async function getToken(input) {
  if (typeof input === 'string') return input;
  const ordered = order(input);
  return await computeSHA1(JSON.stringify(ordered, null, 2));
}

/**
 * Normalizes an 'I' parameter into a map of token to revokeAt ID.
 * Accepts a simple token string, a JSON string of a dictionary, 
 * or an already-parsed dictionary.
 * Returns { [token]: revokeAtId | null }
 */
function parseIrevoke(i) {
  if (!i) return {};
  if (typeof i === 'object') return i;
  if (!i.startsWith('{')) {
    return { [i]: null };
  } else {
    return JSON.parse(i);
  }
}

module.exports = {
  key2order,
  computeSHA1,
  compareKeys,
  order,
  getToken,
  parseIrevoke
};

