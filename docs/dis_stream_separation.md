# Dis Stream Separation — Design Doc

## Problem

Dis (dismiss/snooze) statements currently live in the same Firestore statement stream as reactions
(likes, comments). Because the chain is linear, a dis statement **supersedes** any prior reaction
from the same delegate key. Consequences:

- To un-dis after a snooze wakes, the user must re-issue their reaction — a new rate statement with
  a new timestamp, which perturbs recent activity ordering for everyone.
- Code has been added to work around this (two-tier timestamps, `lastSignalActivity`, dis-exclusion
  guards in activity classification) rather than fixing the root cause.

## Desired Outcome

- Users can dis/snooze/un-dis directly from the content card, without touching their reaction.
- Dis/un-dis never affects recent activity ordering.
- The workaround code is removed.

---

## Architecture

### New Firestore Collection

Each delegate key gets a second, independent statement stream for dismissals only:

```
/{delegateKey}/dis/statements        ← new, dis only
/{delegateKey}/statements/statements ← existing, reactions only (no dis)
```

Both streams maintain their own cryptographic chain (`previous` pointer). The infrastructure for
multiple independent streams per key is provided by the `one-key-multiple-streams` change (now
on `main`):

- `DirectFirestoreWriter` and `DirectFirestoreSource` each have a `streamId` parameter
  (defaulting to `'statements'`) that selects which stream to write/read.
- `DirectFirestoreSource` and `CloudFunctionsSource` each have an `allStreams` parameter
  (defaulting to `['statements']`) listing all streams for that key. When a key has a
  non-null `revokeAt` token, the source searches `allStreams` in order to find it —
  so the cutoff time is applied correctly even if the revokeAt token lives in a different
  stream from the one being served.
- Nerdster delegate keys participate in two streams, so all sources for delegate keys declare
  `allStreams: ['statements', 'dis']`.

### New `DismissStatement` Type

A new `DismissStatement` class is added. `ContentStatement` loses all awareness of dis/snooze:

- `ContentStatement`: `dismiss` field and related construction/parsing are removed.
- `DismissStatement`: `{ statement: 'org.nerdster.dis', rate: <subject>, with: {dismiss: 'forever'|'snooze'}, time, I, previous, signature }`.
  Written to `/{delegateKey}/dis/statements`.

**Un-dis**: issue a `clear` DismissStatement (no `with.dismiss` field) pointing at the prior
statement in the dis stream. No new statement type needed.

**Snooze wake-up**: computed at read time — no write is emitted when a snooze wakes.

### Fetching

The dis stream is fetched for:
- The signed-in user's own delegate keys (`myDelegateKeys`), and
- The PoV identity's delegate keys when the hidden "use PoV's dises" setting is on (deferred).

Main content streams continue to be fetched for the full trusted network as before.

**Exporting dis statements**: The Cloud Function powering `export.nerdster.org` accepts an optional
`subcollection` query param (format: `docSeg/colSeg`, default `statements/statements`). Passing
`subcollection=dis/statements` serves `/{keyToken}/dis/statements` instead. `KeyInfoView` shows a
"Signed, Published Dismiss Statements" link for delegate keys using this param. Both the server
support and the client link are implemented.

`SourceFactory.forDis()` uses `DirectFirestoreSource` (not `CloudFunctionsSource`) since dis
statements are only fetched for the signed-in user's own delegates, where direct Firestore
access is available. If arbitrary delegate dis export is ever needed, `CloudFunctionsSource` with
`streamId: 'dis'` and `allStreams: ['statements', 'dis']` would be the right path.

**Deferred — true PoV dis**: the ability to view from another's PoV including their dis stream is
desirable and the architecture supports it (PoV's delegate keys → PoV's dis stream). Deferred
because the setting is hidden and rarely used. See TODO.md.

### `myLiteralStatements` and the Dis Stream

- `myLiteralStatements` no longer contains any dis data (no dis in the main stream).
- `myCanonicalDisses` is replaced by a parallel `myDismissStatements` map built from the fetched
  dis stream, keyed by canonical content key.
- The `RateDialog` reads `myLiteralStatements` for reactions as before — unaffected.
- Dismissal state shown on the card is read from `myDismissStatements`.

### Minimizing Round Trips

`myDelegateKeys` is resolved at the end of the trust pipeline step, before content fetching
begins. The dis stream fetch is issued **in parallel with** the content pipeline fetch — no extra
serial round trip.

### UI Changes

Dis and rate are **decoupled in the UI**. A single user action never triggers two writes.

**`RateDialog`**: loses dis controls entirely; writes only to the main content stream.

**Phone / `isSmall=true` — swipe gesture**:
- Left swipe → snooze, right swipe → forever.
- Writes directly to the dis stream immediately. No dialog. No rating change.

**Larger interface / `isSmall=false` — card toggle**:
- A 3-way dis toggle (none → snooze → forever → none) appears on the card.
- Write timing: the write to the dis stream happens after a short countdown. One write,
  reflecting the final toggled state at expiry.
- Commit on dispose: if the card is scrolled off-screen while a pending state exists, write
  immediately on card dispose.

---

## What Gets Removed (Workaround Code)

All removed:

| Location | What was removed |
|----------|------------------|
| `content_logic.dart` | `isQualifiedActivity = false` guard for dis-rate statements; `myCanonicalDisses` population from main stream |
| `model.dart` | `lastSignalActivity` field; dis-exclusion in `_checkIsDismissed` |
| `feed_controller.dart` | `DisFilterMode.ignore` sort path using `lastSignalActivity` |
| `content_statement.dart` | `dismiss` field, related construction/parsing |
| `rate_dialog.dart` | Dis/snooze controls |
| `test/logic/signal_sort_unit_test.dart` | Deleted (tested the workaround, not needed) |

---

## Migration

**We cannot migrate existing data** — users' private delegate keys are inaccessible.

Strategy:
- **Ignore** the `dismiss` field on all existing `ContentStatement` documents. No code reads it;
  old dis data silently becomes inert.
- New dis statements are written exclusively to `/{delegateKey}/dis/statements`.
- Old dismissed items will reappear in feeds; users re-dismiss via the card toggle.

---

## Deferred Items (TODO.md)

- **True PoV dis**: fetch and apply PoV's dis stream when the hidden setting is enabled.
- **Exporting dis for arbitrary keys**: `SourceFactory.forDis()` currently only works for the
  signed-in user's own delegate keys. Supporting export for arbitrary keys would require
  `CloudFunctionsSource<DismissStatement>` with `streamId: 'dis'` and
  `allStreams: ['statements', 'dis']`.
