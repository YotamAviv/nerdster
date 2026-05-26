/**
 * Nerdster Cloud Functions — entry point
 *
 * Each function is implemented in its own file. This file only registers them.
 *
 * Deploy:
 *   firebase --project=nerdster deploy --only functions
 *
 * ONE-OF-US.NET functions live in oneofusv22/functions/ and are deployed from there.
 *
 * Shared files (keep identical across nerdster14, oneofusv22):
 *   write.js, write2.js, verify_util.js, jsonish_util.js, statement_fetcher.js, export.js
 *
 * Nerdster-only files:
 *   sign_in.js, fetch_images.js, magic_paste.js, core_logic.js,
 *   metadata_fetchers.js, url_metadata_parser.js,
 *   get_oou_cache.js, trust_pipeline.js, trust_logic.js, oneofus_source.js
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");  // onCall used by fetchImages, magicPaste
const { logger } = require("firebase-functions");
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const { handleWrite } = require('./write');
const { makeWrite2Handler } = require('./write2');
const { auth: writeAuth } = require('./write_auth');
const handleWrite2 = makeWrite2Handler(writeAuth);
const { handleSignIn } = require('./sign_in');
const { handleExport } = require('./export');
const { handleFetchImages } = require('./fetch_images');
const { handleMagicPaste } = require('./magic_paste');

exports.write = onCall(async (request) => {
  try {
    return await handleWrite(request.data);
  } catch (e) {
    throw new HttpsError('internal', e.message);
  }
});

exports.write2 = onRequest({ cors: true }, async (req, res) => {
  await handleWrite2(req, res);
});

exports.fetchImages = onCall(async (request) => {
  try {
    return await handleFetchImages(request.data, logger);
  } catch (e) {
    if (e.message && (e.message.startsWith("Missing subject") || e.message.startsWith("Subject must have"))) {
      throw new HttpsError("invalid-argument", e.message);
    }
    throw new HttpsError("internal", e.message);
  }
});

exports.magicPaste = onCall(async (request) => {
  return await handleMagicPaste(request.data, logger);
});

exports.signin = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  return await handleSignIn(req, res);
});

exports.export = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  return await handleExport(req, res);
});

const { handleGetOouCache } = require('./get_oou_cache');

exports.getOouCache = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  await handleGetOouCache(req, res);
});
