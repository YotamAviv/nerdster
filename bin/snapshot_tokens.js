#!/usr/bin/env node

/**
 * Snapshot and restore Firestore statements for a specific token.
 *
 * Firestore path: {token}/statements/statements/{docId}
 *
 * Uses Application Default Credentials (run `gcloud auth application-default login`).
 *
 * Usage:
 *   node bin/snapshot_tokens.js save    <project> <token> [output-file.json]
 *   node bin/snapshot_tokens.js restore <project> <token> <input-file.json>
 *
 * Example:
 *   node bin/snapshot_tokens.js save one-of-us-net abc123 snapshot_abc123.json
 *   node bin/snapshot_tokens.js restore one-of-us-net abc123 snapshot_abc123.json
 */

let admin;
try {
  admin = require('../functions/node_modules/firebase-admin');
} catch (_) {
  admin = require('firebase-admin');
}

const fs = require('fs');

const [, , command, project, token, file] = process.argv;

if (!command || !project || !token) {
  console.error('Usage: snapshot_tokens.js save|restore <project> <token> [file]');
  process.exit(1);
}

admin.initializeApp({ projectId: project });
const db = admin.firestore();

const collRef = () =>
  db.collection(token).doc('statements').collection('statements');

async function save() {
  const snapshot = await collRef().orderBy('time', 'desc').get();
  const docs = Object.fromEntries(snapshot.docs.map(doc => [doc.id, doc.data()]));

  const outFile = file || `snapshot_${token.substring(0, 12)}_${Date.now()}.json`;
  fs.writeFileSync(outFile, JSON.stringify(docs, null, 2));
  console.log(`Saved ${Object.keys(docs).length} documents to ${outFile}`);
}

async function restore() {
  if (!file || !fs.existsSync(file)) {
    console.error(`File not found: ${file}`);
    process.exit(1);
  }

  const docs = JSON.parse(fs.readFileSync(file, 'utf-8'));
  const ref = collRef();

  // Delete existing documents in batches
  const existing = await ref.get();
  if (!existing.empty) {
    const batch = db.batch();
    existing.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    console.log(`Deleted ${existing.size} existing documents`);
  }

  // Restore from snapshot in batches (max 500 per batch)
  const entries = Object.entries(docs);
  for (let i = 0; i < entries.length; i += 500) {
    const batch = db.batch();
    entries.slice(i, i + 500).forEach(([id, data]) => {
      batch.set(ref.doc(id), data);
    });
    await batch.commit();
  }
  console.log(`Restored ${entries.length} documents from ${file}`);
}

(async () => {
  try {
    if (command === 'save') await save();
    else if (command === 'restore') await restore();
    else {
      console.error(`Unknown command: ${command}. Use save or restore.`);
      process.exit(1);
    }
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
  process.exit(0);
})();
