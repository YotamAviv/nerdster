// [aviv] prototype works on emulator.
// I've lost track, but some code snippets came from a tutorial and others from Google AI.
// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

const { logger } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const fetch = require("node-fetch");
const cheerio = require('cheerio'); // For HTML parsing

admin.initializeApp();

// Take the text parameter passed to this HTTP endpoint and insert it into
// Firestore under the path /messages/:documentId/original
exports.addmessage = onRequest(async (req, res) => {
  // Grab the text parameter.
  const original = req.query.text;
  // Push the new message into Firestore using the Firebase Admin SDK.
  const writeResult = await getFirestore()
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

// Take the url parameter passed to this HTTP endpoint and insert it into
// Firestore under the path /urls/:documentId/url
exports.addurl = onRequest(async (req, res) => {
  // Grab the url parameter.
  const url = req.query.url;
  // Push the new message into Firestore using the Firebase Admin SDK.
  const writeResult = await getFirestore()
    .collection("urls")
    .add({ url: url });
  // Send back a message that we've successfully written the message
  res.json({ result: `Message with ID: ${writeResult.id} added.` });
});

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
// Enter this in browser: http://127.0.0.1:5001/nerdster/us-central1/export?token=<Nerdster delegate token>
// Expect: JSON export
// Deployed! Try at: https://us-central1-nerdster.cloudfunctions.net/export?token=f4e45451dd663b6c9caf90276e366f57e573841b
exports.export = functions.https.onRequest(async (req, res) => {
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