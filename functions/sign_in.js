/**
 * signin — HTTP POST endpoint
 *
 * Handles QR sign-in by writing session data to Firestore.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * REQUEST
 * ─────────────────────────────────────────────────────────────────────────────
 * POST {baseUrl}/signin
 * Content-Type: application/json
 *
 * Body:
 * {
 *   "session": <string>,   // required — session ID (used as Firestore sub-collection key)
 *   ...                    // remaining fields stored as-is
 * }
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FIRESTORE PATH
 * ─────────────────────────────────────────────────────────────────────────────
 * sessions / doc / {session} / {auto-id}
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * NOTE
 * ─────────────────────────────────────────────────────────────────────────────
 * Keep in sync with hablotengo/functions/sign_in.js. Hablo's version adds
 * identity key signature verification; the session write structure is identical.
 */

const admin = require('firebase-admin');
const { logger } = require("firebase-functions");

async function handleSignIn(req, res) {
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
}

module.exports = { handleSignIn };
