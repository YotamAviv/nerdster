#!/usr/bin/env node
/**
 * backfill_head.js — one-time migration for the transactional write CF.
 *
 * For every stream document in Firestore ({issuerToken}/{streamKey}), reads the
 * most recent statement and writes its token + time as `head` / `headTime` on
 * the stream doc. Subsequent writes use these fields in a transaction instead of
 * the non-transactional orderBy query.
 *
 * Run against the emulator first, then against prod before deploying write.js.
 *
 * Usage:
 *   node bin/backfill_head.js              # prod (uses application default credentials)
 *   node bin/backfill_head.js --emulator   # local emulator at 127.0.0.1:8080
 *   node bin/backfill_head.js --dry-run    # print what would change, write nothing
 */

const admin = require('../functions/node_modules/firebase-admin');

const emulator = process.argv.includes('--emulator');
const dryRun = process.argv.includes('--dry-run');

if (emulator) {
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  console.log(`Using emulator at ${process.env.FIRESTORE_EMULATOR_HOST}`);
}

admin.initializeApp({ projectId: 'nerdster' });
const db = admin.firestore();

async function backfill() {
  const rootCollections = await db.listCollections();
  let streams = 0;
  let updated = 0;
  let skipped = 0;

  for (const colRef of rootCollections) {
    const streamDocs = await colRef.listDocuments();

    for (const streamRef of streamDocs) {
      streams++;

      const statementsRef = streamRef.collection('statements');
      const snap = await statementsRef.orderBy('time', 'desc').limit(1).get();
      if (snap.empty) continue;

      const latest = snap.docs[0];
      const headToken = latest.id;
      const headTime = latest.data().time ?? null;

      const streamDoc = await streamRef.get();
      if (streamDoc.exists &&
          streamDoc.data().head === headToken &&
          streamDoc.data().headTime === headTime) {
        skipped++;
        continue;
      }

      const path = `${colRef.id}/${streamRef.id}`;
      console.log(`${dryRun ? '[dry]' : '[set]'} ${path}: head=${headToken}`);

      if (!dryRun) {
        await streamRef.set({ head: headToken, headTime }, { merge: true });
      }
      updated++;
    }
  }

  console.log(`\nDone. ${streams} streams scanned, ${updated} updated, ${skipped} already current.`);
}

backfill().catch(e => { console.error(e); process.exit(1); });
