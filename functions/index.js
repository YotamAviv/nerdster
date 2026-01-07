
/**
 * Nerdster Cloud Functions
 * 
 * This file contains the entry points for all Cloud Functions used by Nerdster.
 * It is organized into:
 * 1. Callable Functions (v2 onCall) - Used by the Flutter app.
 * 2. HTTP Functions (v2 onRequest) - Used for external integrations and streaming.
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require('firebase-admin');
const fetch = require("node-fetch");
const cheerio = require('cheerio');

// Local Utilities
const { 
  fetchFromOpenLibrary, 
  fetchFromWikipedia, 
  fetchFromYouTube,
  extractTitle, 
  extractImages 
} = require('./metadata_fetchers');

const { executeFetchImages } = require('./core_logic');

const { fetchStatements } = require('./statement_fetcher');
const { parseIrevoke } = require('./jsonish_util');

// Initialization
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// ----------------------------------------------------------------------------
// 1. Callable Functions (v2 onCall)
// ----------------------------------------------------------------------------

/**
 * Fetches the canonical title from a URL to help establish a subject identity.
 * Fail Fast: Requires a valid URL.
 */
exports.fetchTitle = onCall(async (request) => {
  const url = request.data.url;
  if (!url || !url.startsWith('http')) {
    throw new HttpsError("invalid-argument", "A valid URL starting with http is required.");
  }

  try {
    logger.info(`[fetchTitle] Fetching: ${url}`);
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      timeout: 5000
    });

    if (!response.ok) {
      logger.error(`[fetchTitle] HTTP Error: ${response.status}`);
      return { "title": null };
    }

    const html = await response.text();
    const $ = cheerio.load(html);
    const title = extractTitle($, html);
    return { "title": title };
  } catch (e) {
    logger.error(`[fetchTitle] Error: ${e.message}`);
    return { "title": null };
  }
});

/**
 * Fetches high-quality images for a subject to enhance visual presentation.
 * This is dynamic and NOT part of the subject's identity.
 * Fail Fast: Requires a subject with a contentType.
 */
exports.fetchImages = onCall(async (request) => {
  try {
    // Determine maxImages from request or default to 1 (client optimized)
    const maxImages = request.data.maxImages || 1;
    return await executeFetchImages(request.data.subject, logger, maxImages);
  } catch (e) {
    if (e.message && (e.message.startsWith("Missing subject") || e.message.startsWith("Subject must have"))) {
      throw new HttpsError("invalid-argument", e.message);
    }
    throw new HttpsError("internal", e.message);
  }
});

// ----------------------------------------------------------------------------
// 2. HTTP Functions (v2 onRequest)
// ----------------------------------------------------------------------------

/**
 * Handles QR sign-in by adding session data to Firestore.
 */
exports.signin = onRequest({ cors: true }, async (req, res) => {
  const session = req.body.session;
  if (!session) {
    res.status(400).send("Missing session");
    return;
  }

  try {
    await admin.firestore()
      .collection("sessions")
      .doc("doc")
      .collection(session)
      .add(req.body);
    res.status(201).json({});
  } catch (e) {
    logger.error(`[signin] Error: ${e.message}`);
    res.status(500).send(e.message);
  }
});

/**
 * Exports statements as a JSON stream.
 * Mapped to https://export.nerdster.org
 * 
 * Note regarding errors:
 * If an error occurs while processing a specific key (e.g. notarization violation),
 * the stream will NOT terminate. Instead, it emits a specific error object for that key:
 * { "token": { "error": "Error message" } }
 * This allows the client to handle partial failures (some keys succeed, some fail)
 * and display appropriate notifications for the corrupted keys while showing
 * content for the valid ones.
 */
exports.export = onRequest({ cors: true }, async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  try {
    const specParam = req.query.spec;
    if (!specParam) throw new Error('Query parameter "spec" is required');

    const specString = decodeURIComponent(specParam);
    let specs = /^\s*[\[{"]/.test(specString) ? JSON.parse(specString) : specString;
    if (!Array.isArray(specs)) specs = [specs];

    const params = req.query;
    const omit = params.omit;

    for (const spec of specs) {
      let token = "unknown";
      try {
        const token2revoked = parseIrevoke(spec);
        token = Object.keys(token2revoked)[0];
        const statements = await fetchStatements(token2revoked, params, omit);
        
        res.write(JSON.stringify({ [token]: statements }) + '\n');
      } catch (e) {
         logger.error(`[export] Error processing ${typeof spec === 'string' ? spec : JSON.stringify(spec)}: ${e.message}`);
         res.write(JSON.stringify({ [token]: { error: e.message } }) + '\n');
      }
    }
    res.end();
  } catch (e) {
    logger.error(`[export] Error: ${e.message}`);
    // Note: If headers were already sent, we can't change status
    if (!res.headersSent) {
      res.status(500).send(`Error: ${e.message}`);
    } else {
      res.end();
    }
  }
});

