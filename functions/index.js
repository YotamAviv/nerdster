
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
const { Timestamp } = require("firebase-admin/firestore");
// const cheerio = require('cheerio'); // For HTML parsing
const { decode } = require('html-entities'); // Import the decode function

admin.initializeApp();

/*
Try:
https://www.panningtheglobe.com/ottolenghis-roast-chicken-zaatar-sumac/

The code that uses "cheerio" works, but I favor myExtractTitle atm.
*/
function myExtractTitle(htmlString) {
  const match = htmlString.match(/<title>(.*?)<\/title>/i); // Non-greedy match
  let title = match ? match[1].trim() : null;
  title = decode(title);
  return title;
}
exports.cloudfetchtitle = onCall(async (request) => {
  const url = request.data.url;

  const response = await fetch(url);
  const html = await response.text();

  // const $ = cheerio.load(html);
  // // Select the <title> tag and get its text content
  // let title = $('title').text();
  // // AI to remove junk that isn't the title. I don't understand why I need this.
  // // 1. Attempt to split by the brand separator " | "
  // let parts = title.split(' | ');
  // if (parts.length > 1) {
  //   title = parts[0].trim(); // Take the part before the separator
  // } else {
  //   // 2. Fallback: If the brand separator isn't present, look for a hyphen
  //   parts = title.split(' - ');
  //   if (parts.length > 1) {
  //     title = parts[0].trim();
  //   } else {
  //     // 3.  Fallback: If still not found, remove any characters after and including "Email"
  //     const emailIndex = title.indexOf('Email');
  //     if (emailIndex > -1) {
  //       title = title.substring(0, emailIndex).trim();
  //     }
  //   }
  // }

  let title = myExtractTitle(html);
  title = title.trim();
  // logger.log(`title=${title}`);
  return { "title": title };
});

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

async function getToken(input) {
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
    const subjectToken = await getToken(subject);
    const otherSubject = getOtherSubject(s);
    const otherToken = otherSubject != null ? await getToken(otherSubject) : null;
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
  const orderStatements = params.orderStatements != 'false'; // true by default for demo.
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


// ------------- stream 

// Async streaming (parallel)
/*
Plan dicussion, points..
- reconsider the 'spec' stuff; mabye always pass a map of token2revoked 
  - typical:    {token: revoked, token: null, token: revoked, token: null}
  - unexpected: [{token: revoked}, token, {token: revoked}, token]
- This should be the export API
  - detect if allows or use a param: stream or return list
- Only 2 requirements:
  - demo (Nerster shows statement export link)
  - Nerdster backend
- if request starts with ["{", "["] then it's JSON; otherwise, it's a single token.
  - or token=, 
- short aliases?
  - t: token
  - ts: tokenspec
- Demo: Nice to just use ?token=<token>
- Different entry points (/export/, /stream/) or different params (?stream=true)
  - JSON input? (unlike ?token=<token>)

  TEST: (seem to work)
http://127.0.0.1:5001/nerdster/us-central1/statements?spec=[{"f4e45451dd663b6c9caf90276e366f57e573841b":"c2dc387845c6937bb13abfb77d9ddf72e3d518b5"}]
http://127.0.0.1:5001/nerdster/us-central1/statements?spec=[{"f4e45451dd663b6c9caf90276e366f57e573841b":"c2dc387845c6937bb13abfb77d9ddf72e3d518b5"}]&omit=["statement","I"]
http://127.0.0.1:5001/nerdster/us-central1/statements?spec=["f4e45451dd663b6c9caf90276e366f57e573841b"]
http://127.0.0.1:5001/nerdster/us-central1/statements?spec=[{"f4e45451dd663b6c9caf90276e366f57e573841b":"c2dc387845c6937bb13abfb77d9ddf72e3d518b5"},"b6741d196e4679ce2d05f91a978b4e367c1756dd"]
http://127.0.0.1:5001/nerdster/us-central1/statements?spec=[{"f4e45451dd663b6c9caf90276e366f57e573841b":"c2dc387845c6937bb13abfb77d9ddf72e3d518b5"},"b6741d196e4679ce2d05f91a978b4e367c1756dd"]&omit=["statement","I"]
*/
exports.export = functions.https.onRequest((req, res) => {
  // QUESTIONABLE: I've seen and ignored this stuff:
  // if (!req.acceptsStreaming) ...
  // if (req.headers['content-type'] === 'application/stream+json') ...
  // response.writeHead(200, {
  //   'Content-Type': 'application/stream+json',
  //   'Transfer-Encoding': 'chunked' // Important for streaming
  // });
  res.set('Access-Control-Allow-Origin', '*'); // CORS header.. Allow all origins
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive'
  });
  try {
    if (!req.query.spec) throw new HttpsError('required: spec');
    const specString = decodeURIComponent(req.query.spec);
    // logger.log(`specString=${specString}`);
    // list or just 1
    // list items are <String> or <String, String?>{}
    let specs;
    if (/^\s*[\[{"]/.test(specString)) {
      // starts with [, {, or " → looks like JSON
      specs = JSON.parse(specString);
    } else {
      specs = specString;
    }
    if (!Array.isArray(specs)) specs = [specs];
    // logger.log(`specs=${JSON.stringify(specs)}`);

    // CODE: call decodeURIComponent on all values in params (but I don't even know what type of object params is)
    const params = req.query;
    // const omit = req.query.omit ? JSON.parse(decodeURIComponent(params.omit)) : null;
    const omit = req.query.omit ? params.omit : null;

    let count = 0;
    const all = specs.map(
      async (spec) => {
        // logger.log(`spec=${JSON.stringify(spec)}`);
        var token2revoked;
        if (typeof spec === 'string') {
          token2revoked = { [spec]: null };
        } else {
          token2revoked = spec;
        }
        // logger.log(`token2revoked=${JSON.stringify(token2revoked)}`);

        const token = Object.keys(token2revoked)[0];
        // logger.log(`token2revoked=${JSON.stringify(token2revoked)}`);
        const statements = await fetchh(token2revoked, params, omit);
        const result = { [token]: statements };
        const sOut = JSON.stringify(result);
        res.write(`${sOut}\n`);
        count++;
        if (count == specs.length) {
          res.end();
          res.status(200);
          // logger.log(`end`);
        }
      },
    );
  } catch (error) {
    console.error(error);
    res.status(500).send(`Error: ${error}`); // BUG: Error [ERR_HTTP_HEADERS_SENT]: Cannot set headers after they are sent to the client
  }
});

/*
Just prototype
http://127.0.0.1:5001/nerdster/us-central1/streamnums
*/
exports.streamnums = functions.https.onRequest((req, res) => {
  // if (!req.acceptsStreaming) {
  //   const error = 'no streaming';
  //   console.error(error);
  //   res.status(500).send(`Error: ${error}`);
  //   return;
  // }

  // Add the following line to set the CORS header
  res.set('Access-Control-Allow-Origin', '*'); // Allow all origins
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive'
  });
  let count = 0;
  const intervalId = setInterval(() => {
    if (count < 10) {
      var out = { 'data': count };
      var sOut = JSON.stringify(out);
      res.write(`${sOut}\n`);
      count++;
    } else {
      clearInterval(intervalId);
      res.end();
    }
  }, 300);
});


exports.listCollections = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const collections = await db.listCollections();
  const collectionIds = collections.map((col) => col.id);
  res.status(200).json({ collections: collectionIds });
});