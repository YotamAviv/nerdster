
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
  const subject = request.data.subject;
  if (!subject) {
    throw new HttpsError("invalid-argument", "Missing subject object.");
  }
  
  const contentType = subject.contentType;
  if (!contentType) {
    throw new HttpsError("invalid-argument", "Subject must have a contentType.");
  }

  const url = subject.url || "";
  const author = subject.author || "";
  const type = contentType.toLowerCase();
  
  let title = subject.title || "";
  let images = [];

  logger.info(`--- fetchImages: ${type} | ${title} ---`);

  // 1. YouTube check
  if (url && (url.includes('youtube.com') || url.includes('youtu.be'))) {
    const ytImages = fetchFromYouTube(url);
    images = [...images, ...ytImages];
  }

  // 2. Fetch HTML if URL is present
  if (url && url.startsWith('http')) {
    try {
      const response = await fetch(url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
        timeout: 5000
      });
      if (response.ok) {
        const html = await response.text();
        const $ = cheerio.load(html);
        const scrapedTitle = extractTitle($, html);
        if (!title) title = scrapedTitle;
        const scrapedImages = extractImages($, url);
        images = [...images, ...scrapedImages];
      }
    } catch (e) {
      logger.error(`[fetchImages] HTML Fetch Error: ${e.message}`);
    }
  }

  // 3. Smart Fetch (Wikipedia/OpenLibrary) for specific types
  const smartTypes = ['book', 'movie', 'person', 'place', 'work', 'video'];
  if (title && (images.length === 0 || smartTypes.includes(type))) {
    // Skip hash-like titles (e.g. content-addressed IDs)
    if (!/^[0-9a-f]{32,40}$/i.test(title)) {
      let searchTitle = title.replace(/ - Amazon\.com:.*$/i, '').replace(/ - YouTube$/i, '').trim();
      let cleanAuthor = (author && author.length < 50) ? author : "";

      if (type === 'book') {
        let ol = await fetchFromOpenLibrary(searchTitle, cleanAuthor);
        if (ol.length === 0 && searchTitle.includes(':')) {
          ol = await fetchFromOpenLibrary(searchTitle.split(':')[0].trim(), cleanAuthor);
        }
        images = [...ol, ...images];
      }
      
      // Fallback or supplement with Wikipedia
      if (images.length === 0 || type !== 'book') {
        let wiki = await fetchFromWikipedia(searchTitle);
        if (wiki.length === 0 && searchTitle.includes(':')) {
          wiki = await fetchFromWikipedia(searchTitle.split(':')[0].trim());
        }
        images = [...wiki, ...images];
      }
    }
  }

  // Final cleanup: unique, valid URLs
  images = [...new Set(images)].filter(img => img && typeof img === 'string' && img.startsWith('http'));
  
  return {
    "title": title,
    "image": images.length > 0 ? images[0] : null,
    "images": images
  };
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
 */
exports.export = onRequest({ cors: true }, async (req, res) => {
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive'
  });

  try {
    const specParam = req.query.spec;
    if (!specParam) throw new Error('Query parameter "spec" is required');

    const specString = decodeURIComponent(specParam);
    let specs = /^\s*[\[{"]/.test(specString) ? JSON.parse(specString) : specString;
    if (!Array.isArray(specs)) specs = [specs];

    const params = req.query;
    const omit = params.omit;

    for (const spec of specs) {
      const token2revoked = parseIrevoke(spec);
      const token = Object.keys(token2revoked)[0];
      const statements = await fetchStatements(token2revoked, params, omit);
      
      res.write(JSON.stringify({ [token]: statements }) + '\n');
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

