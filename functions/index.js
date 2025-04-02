
/*
Exporting statements is for both [Nerdster, ONE-OF-US.NET].

Cloud functions are all for for the Nerdster web-app, not ONE-OF-US.NET phone app, but this is 
used by the Nerdster to read from ONE-OF-US.NET, and so it needs to be pushed out there, too.

I often forget and then see it in the logs.. (to run in the functions directory)
npm install
npm install --save firebase-functions@latest
npm audit fix
*/

const { logger } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require("node-fetch");
const cheerio = require('cheerio'); // For HTML parsing
const { Timestamp } = require("firebase-admin/firestore");

admin.initializeApp();

exports.cloudfetchtitle = onCall(async (request) => {
  const url = request.data.url;
  // logger.log(`cloudfetchtitle: ${request.data} `);
  const response = await fetch(url);
  if (!response.ok) {
    throw new functions.https.HttpsError("unavailable", "Failed to fetch URL",
      { 'status': response.status });
  }
  const html = await response.text();
  const $ = cheerio.load(html);
  const title = $('title').text(); // .trim()?
  return { "title": title };
});

// Jsonish.dart'ish needs here in JavaScript:
// - sort keys for pretty exports for demo ("statement", "time", "I", "trust", "with", "previous", "signature")
// - sort keys for distinct subjects ("contentType", "author", "title")
// Statement.dart'ish needs here in JavaScript:
// - get subject of verb for distinct based on subjects.

// HTTP POST for QR signin (not 'signIn' (in camelCase) - that breaks things).
// The Nerdster should be listening for a new doc at collection /sessions/doc/<session>/
// The phone app should POST to this function (it used to write directly to the Nerdster Firebase collection.)
exports.signin = onRequest((req, res) => {
  const session = req.body.session;
  const db = admin.firestore();
  return db
    .collection("sessions")
    .doc("doc")
    .collection(session)
    .add(req.body).then(() => {
      res.status(201).json({});
    });
});

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

// -----------  --------------------------------------------------------//

// ONE-OF-US.NET has those statements and those verbs, but... just union (Nerdster, ONE-OF-US)  
const verbs = [
  'trust',
  'delegate',
  'clear',
  'rate',
  'follow',
  'censor',
  'relate',
  'dontRelate',
  'equate',
  'dontEquate',
  'replace',
  'block',
];

function getVerbSubject(j) {
  for (var verb of verbs) {
    if (j[verb] != null) {
      return [verb, j[verb]];
    }
  }
  return null;
}

function getOtherSubject(j) {
  if ('with' in j && 'otherSubject' in j['with']) {
    return j['with']['otherSubject'];
  }
}

// -----------  --------------------------------------------------------//

// Considers subject of verb (input[verb]) and otherSubject (input[with][otherSubject]) if present.
async function makedistinct(input) {
  var distinct = [];
  var already = new Set();
  for (var s of input) {
    var i = s['I'];
    const [verb, subject] = getVerbSubject(s);
    const subjectToken = await keyToken(subject);
    const otherSubject = getOtherSubject(s);
    const otherToken = otherSubject != null ? await keyToken(otherSubject) : null;
    const combinedKey = otherToken != null ?
      ((subjectToken < otherToken) ? subjectToken.concat(otherToken) : otherToken.concat(subjectToken)) :
      subjectToken;
    if (already.has(combinedKey)) continue;
    already.add(combinedKey);
    distinct.push(s);
  }
  return distinct;
}

// fetchh: gratuitous h to avoid naming conflict with node-fetch
async function fetchh(token2revokeAt, params = {}, omit = {}) {
  const checkPrevious = params.checkPrevious != null;
  const distinct = params.distinct != null;
  const orderStatements = params.orderStatements != 'false'; // On by default for demo.
  const includeId = params.includeId != null;
  const after = params.after;

  if (!token2revokeAt) throw 'Missing token2revokeAt';
  const token = Object.keys(token2revokeAt)[0];
  const revokeAt = token2revokeAt[token];
  if (!token) throw 'Missing token';
  if (checkPrevious && !includeId) throw 'checkPrevious requires includeId';

  const db = admin.firestore();
  const collectionRef = db.collection(token).doc('statements').collection('statements');

  var revokeAtTime;
  if (revokeAt) {
    const doc = collectionRef.doc(revokeAt);
    const docSnap = await doc.get();
    if (docSnap.data()) {
      revokeAtTime = docSnap.data().time;
    } else {
      return [];
    }
  }

  var snapshot;
  if (revokeAtTime && after) {
    var error = `Unimplemented: revokeAtTime && after`;
    logger.error(error);
    throw error;
  } else if (revokeAtTime) {
    snapshot = await collectionRef.where('time', "<=", revokeAtTime).orderBy('time', 'desc').get();
  } else if (after) {
    // logger.log(`after=${after}`)
    snapshot = await collectionRef.where('time', ">", after).orderBy('time', 'desc').get();
  } else {
    snapshot = await collectionRef.orderBy('time', 'desc').get();
  }

  var statements;
  if (includeId) {
    statements = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  } else {
    statements = snapshot.docs.map(doc => doc.data());
  }

  if (checkPrevious) {
    // Validate notary chain, decending order
    var first = true;
    var previousToken;
    var previousTime;
    for (var d of statements) {
      if (first) {
        first = false; // no check
      } else {
        if (d.id != previousToken) {
          var error = `Notarization violation: ${d.id} != ${previousToken}`;
          logger.error(error);
          throw error;
        }

        if (d.time >= previousTime) {
          var error = `Not descending: ${d.time} >= ${previousTime}`;
          logger.error(error);
          throw error;
        }
      }
      previousToken = d.previous;
      previousTime = d.time;
    }
  }

  if (omit) {
    for (var s of statements) {
      for (const key of omit) {
        delete s[key];
      }
    }
  }

  if (distinct) {
    statements = await makedistinct(statements);
  }

  // order statements
  if (orderStatements) {
    var list = [];
    for (const statement of statements) {
      const ordered = order(statement);
      list.push(ordered);
    }
    statements = list;
  }

  return statements;
}

// ----------------------- Firebase cloud functions called by Nerdster ------------------------- //

exports.cloudfetch = onCall(async (request) => {
  const token2revokeAt = request.data.token2revokeAt;
  try {
    return await fetchh(token2revokeAt, request.data, request.data.omit);
  } catch (error) {
    console.error(error);
    throw new HttpsError(error);
  }
});

exports.mcloudfetch = onCall(async (request) => {
  const token2revokeAt = request.data.token2revokeAt;
  const params = request.data;
  const omit = request.data.omit;
  try {
    var outs = [];
    // TODO: Async streaming (parallel): https://firebase.google.com/docs/functions/callable?gen=2nd
    for (const [token, revokeAt] of Object.entries(token2revokeAt)) {
      // logger.log(`token=${token}, revokeAt=${revokeAt}`);
      var out = await fetchh({ [token]: revokeAt }, params, omit);
      outs.push(out);
    }
    return outs;
  } catch (error) {
    console.error(error);
    throw new HttpsError(error);
  }
});

// ----------------------- JSON export ------------------------- //

// - Emulator-Nerdster-Yotam: http://127.0.0.1:5001/nerdster/us-central1/..
// - Emulator-Oneofus-Yotam: http://127.0.0.1:5002/one-of-us-net/us-central1/..
// - Prod-Nerdster-Yotam: https://us-central1-nerdster.cloudfunctions.net/..
// - Prod-Oneofus-Yotam: http://us-central1-one-of-us-net.cloudfunctions.net/..
//
// 10/18/24:
// - upgraded to v2 (in response to errors on command line)
// - mapped to https://export.nerdster.org
//   - https://console.cloud.google.com/run/domains?project=nerdster
//   - https://console.firebase.google.com/project/nerdster/functions/list

// DEFER: Use the 'i' over 'token2revokeAt' in cloud functions. (pros: save bytes, cons: bugs)
function i2token2revoked(i) {
  var token2revoked;
  if (typeof i === 'string') {
    token2revoked = { [i]: null };
  } else {
    token2revoked = i;
  }
  return token2revoked;
}

/*
* 1 token, many parameters
http://127.0.0.1:5001/nerdster/us-central1/export?token="f4e45451dd663b6c9caf90276e366f57e573841b"&distinct=true&includeId=true&&checkPrevious=true&orderStatements=false&after=2024-12-19T00:00:00.000Z&omit=["statement","previous","signature"]
* 1 token with revokedAt
http://127.0.0.1:5001/nerdster/us-central1/export?token={"f4e45451dd663b6c9caf90276e366f57e573841b":"c2dc387845c6937bb13abfb77d9ddf72e3d518b5"}
* with or without quotes works when just 1token
http://127.0.0.1:5002/one-of-us-net/us-central1/export?token=55c28752d220fa7188d77414f948382c41e36255&includeId
http://127.0.0.1:5002/one-of-us-net/us-central1/export?token="55c28752d220fa7188d77414f948382c41e36255"&includeId
* tokens: 2 with 1 revoked
http://127.0.0.1:5001/nerdster/us-central1/export?tokens=[{"f4e45451dd663b6c9caf90276e366f57e573841b":"c2dc387845c6937bb13abfb77d9ddf72e3d518b5"},"b6741d196e4679ce2d05f91a978b4e367c1756dd"]
*/
exports.export = onRequest(async (req, res) => {
  try {
    const params = req.query;
    const omit = req.query.omit ? JSON.parse(req.query.omit) : null;
    if (req.query.token) {
      if (req.query.tokens) throw new HttpsError('required: token xor tokens');
      var i;
      try {
        i = JSON.parse(req.query.token);
      } catch (e) {
        i = req.query.token;
      }
      const token2revoked = i2token2revoked(i);
      const out = await fetchh(token2revoked, params, omit);
      res.status(200).json(out);
    } else {
      if (!req.query.tokens) throw new HttpsError('required: token xor tokens');
      const is = JSON.parse(req.query.tokens);
      const outs = [];
      for (const i of is) {
        const token2revoked = i2token2revoked(i);
        const out = await fetchh(token2revoked, params, omit);
        outs.push(out);
      }
      res.status(200).json(outs);
    }
  } catch (error) {
    console.error(error);
    res.status(500).send(`Error: ${error}`);
  }

});
// TODO: remove
exports.export2 = exports.export;