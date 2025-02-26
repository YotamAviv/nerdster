const yotam_oneofus = require('../test/yotam-oneofus.json');
const yotam_nerdster = require('../test/yotam-nerdster.json');
const other = require('../test/other.json');

// TDOO: BUG: Need to special case on signature which always goes last.
// Test samples from Nerdster or ONE-OF-US are not going to have any unknown fields, and so need 
// to test on other fake samples as well.

// ----------- Code to copy/paste into <nerdster/oneofus>/functions/index.js -----------------//

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
  "censor": 9,
  "relate": 10,
  "dontRelate": 11,
  "equate": 12,
  "dontEquate": 13,
  "follow": 14,
  "with": 16,
  "other": 17,
  "moniker": 18,
  "revokeAt": 19,
  "domain": 20,
  "tags": 21,
  "recommend": 22,
  "dismiss": 23,
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

// ----------- the test --------------------------------------------------------//
async function main() {
  var passing = true;
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