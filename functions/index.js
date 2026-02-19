
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
  extractTitle,
  extractImages
} = require('./metadata_fetchers');
const { parseUrlMetadata } = require('./url_metadata_parser');

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

/**
 * "Magic Paste" - Smart URL Parser.
 * Fetches the URL and extracts metadata (Title, Year, Author, Image, ContentType)
 * using Schema.org (JSON-LD), OpenGraph, or standard HTML tags.
 */
exports.magicPaste = onCall(async (request) => {
  const url = request.data.url;
  logger.info(`[magicPaste] CALL RECEIVED for URL: ${url}`); // DEBUG

  try {

    // Explicit timeout using Promise.race to guarantee control flow resumes
    let html;
    try {
      const timeoutMs = 15000; // 15s timeout

      const fetchAndRead = async () => {
        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Referer': 'https://www.google.com/'
          }
        });
        if (!response.ok) {
          logger.warn(`[magicPaste] HTTP status: ${response.status} (attempting to parse anyway)`);
        }
        return await response.text();
      };

      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => {
          reject(new Error('Fetch timeout'));
        }, timeoutMs)
      );

      html = await Promise.race([fetchAndRead(), timeoutPromise]);
    } catch (e) {
      if (e.message === 'Fetch timeout') logger.warn(`[magicPaste] Fetch timed out after 15s`);
      return {
        title: "Error: Fetch timeout",
        contentType: 'article',
        canonicalUrl: url,
        error: "Fetch timeout"
      }
    }

    logger.info(`[magicPaste] HTML length: ${html.length}`);

    // Parse metadata from the fetched HTML
    let metadata = await parseUrlMetadata(url, html);

    // Safety: ensure no undefined values are returned (Cloud Functions can be picky)
    if (metadata) {
      metadata = JSON.parse(JSON.stringify(metadata));
    }

    logger.info(`[magicPaste] parseUrlMetadata returned: ${JSON.stringify(metadata)}`);


    if (metadata && metadata.title) {
      logger.info(`[magicPaste] Successful. Title: "${metadata.title}"`);
      // Ensure contentType is set, default to article if missing
      if (!metadata.contentType) metadata.contentType = 'article';

      // Flatten image object to simple URL string for Firebase Functions Web compatibility
      if (metadata.image && typeof metadata.image === 'object') {
        metadata.image = metadata.image.url || metadata.image.contentUrl || null;
      }

      return metadata;
    } else {
      logger.info(`[magicPaste] All methods found no title.`);
    }

  } catch (eFallback) {
    logger.error(`[magicPaste] Exception: ${eFallback.message}`);

    // Even on error, return something valid so client doesn't crash with null pointer
    return {
      title: "Error: " + eFallback.message, // For debugging in UI
      contentType: 'article',
      canonicalUrl: url,
      error: eFallback.message
    }
  }

  // Graceful Failure default
  logger.info(`[magicPaste] All methods failed. Returning generic object.`);
  return {
    title: "",
    contentType: 'article',
    canonicalUrl: url
  };
});

// REMOVED BROKEN magicPaste2
// exports.magicPaste2 = ...

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

