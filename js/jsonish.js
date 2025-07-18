const yotam_oneofus = require('../test/yotam-oneofus.json');
const yotam_nerdster = require('../test/yotam-nerdster.json');
const other = require('../test/other.json');

// Test samples from Nerdster or ONE-OF-US are not going to have any unknown fields, and so need 
// to test on other fake samples as well.

// key2order: Use jsonish_test.dart to generate this

// ----- Code from jsonish.js to copy/paste into <nerdster/oneofus>/functions/index.js ----------//

var key2order = {
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
  "with": 15,
  "other": 16,
  "moniker": 17,
  "revokeAt": 18,
  "domain": 19,
  "tags": 20,
  "recommend": 21,
  "dismiss": 22,
  "censor": 23,
  "stars": 24,
  "comment": 25,
  "contentType": 26,
  "previous": 27,
  "signature": 28
};

async function computeSHA1(str) {
  const buffer = new TextEncoder("utf-8").encode(str);
  const hash = await crypto.subtle.digest("SHA-1", buffer);
  return Array.from(new Uint8Array(hash))
    .map(x => x.toString(16).padStart(2, '0'))
    .join('');
}

function compareKeys(key1, key2) {
  // console.log(`compareKeys(${key1}, ${key2})`);
  // Keys we know have an order; others are ordered alphabetically below keys we know except signature.
  // TODO: Is that correct about 'signature' below unknown keys?
  const key1i = key2order[key1];
  const key2i = key2order[key2];
  var out;
  if (key1i != null && key2i != null) {
    out = key1i - key2i;
  } else if (key1i == null && key2i == null) {
    out = key1 < key2 ? -1 : 1;
  } else if (key1i != null) {
    out = -1;
  } else {
    out = 1;
  }
  // console.log(`compareKeys(${key1}, ${key2})=${out}`);
  return out;
}


function order(thing) {
  if (typeof thing === 'string') {
    return thing;
  } else if (typeof thing === 'boolean') {
    return thing;
  } else if (typeof thing === 'number') {
    return thing;
  } else if (Array.isArray(thing)) {
    return thing.map((x) => order(x));
  } else {
    const signature = thing.signature; // signature last
    const { ['signature']: excluded, ...signatureExcluded } = thing;
    var out = Object.keys(signatureExcluded)
      .sort((a, b) => compareKeys(a, b))
      .reduce((obj, key) => {
        obj[key] = order(thing[key]);
        return obj;
      }, {});
    if (signature) out.signature = signature;
    return out;
  }
}

async function keyToken(input) {
  if (typeof input === 'string') {
    return input;
  } else {
    const ordered = order(input);
    var ppJson = JSON.stringify(ordered, null, 2);
    var token = await computeSHA1(ppJson);
    return token;
  }
}

// Return {String token: String? revokedAt}
// Input can be:
// - Just a string token
// - A JSON String of a dictionary mapping token to revokeAt: {String token: String? revokeAt}
function parseIrevoke(i) {
  if (!i.startsWith('{')) {
    token = i;
    return { [token]: null };
  } else {
    var token2revoked = (JSON.parse(i));
    return token2revoked;
  }
}

// ----------- the test --------------------------------------------------------//
async function main() {
  var passing = true;

  const i1 = 'token123';
  const parsed1 = parseIrevoke(i1);
  const expected1 = { [i1]: null };
  if (JSON.stringify(parsed1) != JSON.stringify(expected1)) {
    console.log(`parsed1=${JSON.stringify(parsed1)}`);
    passing = false;
  }
  const i2 = '{"token123": null}';
  const parsed2 = parseIrevoke(i2);
  const expected2 = { [i1]: null };
  if (JSON.stringify(parsed2) != JSON.stringify(expected2)) {
    console.log(`parsed2=${JSON.stringify(parsed2)}`);
    passing = false;
  }
  const i3 = '{"token123": "token234"}';
  const parsed3 = parseIrevoke(i3);
  const expected3 = { [i1]: "token234" };
  if (JSON.stringify(parsed3) != JSON.stringify(expected3)) {
    console.log(`parsed3=${JSON.stringify(parsed3)}`);
    passing = false;
  }

  // console.log(data);
  for (const exported of [yotam_oneofus, yotam_nerdster, other]) {
    for (const statement of exported['statements']) {
      // Kludge: The server communicates token as "id" to us in the statement.
      const id = statement.id;
      delete statement.id;
      const token = await keyToken(statement);
      if (id != token) {
        console.log(`${id} != ${token}`);
        console.log(JSON.stringify(statement, null, 2));
        console.log(JSON.stringify(order(statement), null, 2));
        passing = false;
      }
    }
  }

  console.log(passing ? 'pass' : "FAIL");
}

main();