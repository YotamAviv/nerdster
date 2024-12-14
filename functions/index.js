// I've lost track... 
// - some code snippets came from a tutorial: https://firebase.google.com/docs/functions/get-started
// - some code came from Google AI.
// 
// It used to be v1, then there may have been an upgrade, and some of the prototyping was 
// broken for a while.
//
// I often forget and then see it in the logs.. 
// .. something about running "npm install" in the functions directory.
// 
// TODO: Look into this warning about running "npm audit fix"
// 

const { logger } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const fetch = require("node-fetch");
const cheerio = require('cheerio'); // For HTML parsing

admin.initializeApp();

// These 2 functions are strictly for prototyping.
// To see it:
// - run the nerdster emulator
// - (the Nerdster app does not need to be running)
// Access this in a browser:
//   http://127.0.0.1:5001/nerdster/us-central1/addmessage/?text=foo
// You should see a document {original: foo, uppercase: FOO} in the "messages" collection in the
// Firestore emulator, maybe here:
//   http://127.0.0.1:4000/firestore/ 

// Take the text parameter passed to this HTTP endpoint and insert it into
// Firestore under the path /messages/:documentId/original
exports.addmessage = onRequest(async (req, res) => {
  const original = req.query.text;
  const db = admin.firestore();
  const writeResult = await db
      .collection("messages")
      .add({original: original});
  // Send back a message that we've successfully written the message
  res.json({result: `Message with ID: ${writeResult.id} added.`});
});

// Listens for new messages added to /messages/:documentId/original
// and saves an uppercased version of the message
// to /messages/:documentId/uppercase
exports.makeuppercase = onDocumentCreated("/messages/{documentId}", (event) => {
  // Grab the current value of what was written to Firestore.
  const original = event.data.data().original;

  // Access the parameter `{documentId}` with `event.params`
  logger.log("Uppercasing", event.params.documentId, original);

  const uppercase = original.toUpperCase();

  // You must return a Promise when performing
  // asynchronous tasks inside a function
  // such as writing to Firestore.
  // Setting an 'uppercase' field in Firestore document returns a Promise.
  return event.data.ref.set({uppercase}, {merge: true});
});

// This works and is used to develop fetchtitle below.
// Take the url parameter passed to this HTTP endpoint and insert it into
// Firestore under the path /urls/:documentId/url
exports.addurl = onRequest(async (req, res) => {
  const url = req.query.url;
  const db = admin.firestore();
  const writeResult = db
    .collection("urls")
    .add({ url: url });
  // Send back a message that we've successfully written the message
  res.json({ result: `Message with ID: ${writeResult.id} added.` });
});

// This is live and actively used by Nerdster to fetch HTML titles from URLs.
// Listens for new urls added to /urls/:documentId/url
// and saves the fetched title to /urls/:documentId/uppercase
exports.fetchtitle = onDocumentCreated("/urls/{documentId}", async (event) => {
  // Grab the current value of what was written to Firestore.
  const url = event.data.data().url;

  // Access the parameter `{documentId}` with `event.params`
  logger.log("fetching", event.params.documentId, url);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch URL: ${response.status}`);
  }

  const html = await response.text();
  const $ = cheerio.load(html);

  const title = $('title').text(); // .trim()?

  logger.log(title);

  return event.data.ref.set({ title }, { merge: true });
});


// from: Google AI: https://www.google.com/search?q=Firebase+function+HTTP+GET+export+collection&oq=Firebase+function+HTTP+GET+export+collection&gs_lcrp=EgZjaHJvbWUyBggAEEUYOTIGCAEQRRhA0gEIOTYzMmowajSoAgCwAgE&sourceid=chrome&ie=UTF-8
// Enter this in browser: http://127.0.0.1:5001/nerdster/us-central1/export2?token=<Nerdster delegate token>
// Expect: JSON export
// Deployed! Try at: https://us-central1-nerdster.cloudfunctions.net/export2?token=f4e45451dd663b6c9caf90276e366f57e573841b
// Updates from 10/18/24:
// - upgraded to v2 (in response to errors on command line)
// - mapped to https://export.nerdster.org/?token=f4e45451dd663b6c9caf90276e366f57e573841b
//   - https://console.cloud.google.com/run/domains?project=nerdster
//   - https://console.firebase.google.com/project/nerdster/functions/list
exports.export2 = onRequest(async (req, res) => {
  const token = req.query.token;
  if (!token) {
    return res.status(400).send('Missing collection name');
  }

  try {
    const db = admin.firestore();
    const collectionRef = db.collection(token).doc('statements').collection('statements');
    const snapshot = await collectionRef.get();

    const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json(data);
  } catch (error) {
    console.error(error);
    res.status(500).send('Error exporting collection');
  }
});


// TODO: Use HTTP POST for QR sign-in.

// - Nerdster functions:
//   - Implement an onRequest function that inserts into /sessions/doc/<session>/doc
//   - (JSON, not a string like the URL or message functions.)
// - Optional: Nerdster Google Cloud hosting:
//   - Map that function (see export2) to a URL like https://signin.nerdster.org
// - Nerdster code:
//   - Change to QR to include that URL
//     - will be different based on emulator / prod.
//   - DEFER: clean up Firebase / POST options and code.

// - Oneofus:
//   - Change code to POST to Nerdster functions instead of writing directly to Nerdster Firebase: 
//     - (Keep location the same: /sessions/doc/<session>/doc)
//   - Get the URL to write to from the Nerdster QR code.