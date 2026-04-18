# Dis Stream Separation — Design Doc

AI: Address

I do want to be 

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

Both streams maintain their own cryptographic chain (`previous` pointer). The existing
`DirectFirestoreWriter` / `DirectFirestoreSource` infrastructure is reused via two separate
instances — one per collection path. Both classes gain an optional `subcollection` parameter
(defaulting to `'statements'`) so the dis stream can target `dis/statements` without changing
any existing call sites.

### New `DismissStatement` Type

A new `DismissStatement` class is added. `ContentStatement` loses all awareness of dis/snooze:

- `ContentStatement`: `dismiss` field and related construction/parsing are removed.
- `DismissStatement`: `{ subject, dismiss: 'forever'|'snooze', time, I, previous, signature }`.
  Written to `/{delegateKey}/dis/statements`.

**Un-dis**: issue a `clear` statement pointing at the prior `DismissStatement` in the dis stream.
No new statement type needed.

**Snooze wake-up**: computed at read time — no write is emitted when a snooze wakes.

### Fetching

The dis stream is fetched for:
- The signed-in user's own delegate keys (`myDelegateKeys`), and
- The PoV identity's delegate keys when the hidden "use PoV's dises" setting is on.

Main content streams continue to be fetched for the full trusted network as before.

**Deferred — exporting dis statements**: dis statements are not purely local/private. Future work
should allow exporting them (visible published links on a delegate key page). Architecture keeps
the dis collection path regular and addressable. Plan:

- **Server**: Update the Cloud Function powering `export.nerdster.org` to accept an optional
  `subcollection` query param (default `'statements'`). When `subcollection=dis/statements` is
  passed, serve from `/{spec}/dis/statements` instead of `/{spec}/statements/statements`. Backward
  compatible — existing callers without the param see the same behavior as today.
- **Client**: In `node_details.dart`, add a second `KeyInfoView.show` call for the delegate, using
  `SourceFactory.forDis(delegateToken)` as the source and a `baseUrl` that includes
  `?subcollection=dis/statements`. Add a corresponding "Signed, Published Dismiss Statements" link
  in `KeyInfoView._buildStatementsLink`.
- **Bug to fix first**: `KeyInfoView._buildStatementsLink` shows the external link for both
  `FireChoice.emulator` and `FireChoice.prod`. In emulator mode the link opens
  `export.nerdster.org` which queries prod Firestore. Fix: only show the external link for
  `FireChoice.prod`; for emulator, show a clickable link to the local export endpoint
  (e.g. `http://localhost:5001/nerdster/us-central1/export?spec=...`) so the signed statements
  served by the emulator Cloud Function are visible, just as `export.nerdster.org` shows them
  in production. Only `FireChoice.fake` uses the inline display.

**Deferred — true PoV dis**: the ability to view from another's PoV including their dis stream is
desirable and the architecture supports it (PoV's delegate keys → PoV's dis stream). Deferred
because the setting is hidden and rarely used. See TODO.md.

### `myLiteralStatements` and the Dis Stream

When the signed-in user is viewing from a different PoV, the system still needs to show the user
their own reactions when they open the `RateDialog` or interact with a card. This is handled today
by fetching `myDelegateKeys` independently of the PoV network (in `feed_controller.dart:366-393`)
and building `myLiteralStatements` — a map from content key → the user's own `ContentStatement`s,
indexed by both literal and canonical key (`content_logic.dart:399-430`).

`myCanonicalDisses` is built from the same merged-my-statements pass (line 426-428) and currently
holds the user's dis-rate statements.

**After this change:**
- `myLiteralStatements` no longer contains any dis data (no dis in the main stream).
- `myCanonicalDisses` is replaced by a parallel `myDismissStatements` map built from the fetched
  dis stream, keyed the same way (by canonical content key).
- The `RateDialog` reads `myLiteralStatements` for reactions as before — unaffected.
- Dismissal state shown on the card is read from `myDismissStatements`.

### Minimizing Round Trips

`myDelegateKeys` is already resolved at the end of the trust pipeline step (step 1), before
content fetching begins. The dis stream fetch for those keys can be issued **in parallel with**
the existing content pipeline fetch (step 2 in `feed_controller.dart:398-420`). No extra serial
round trip is introduced — the dis fetch piggybacks on the same concurrency window.

If the PoV dis setting is on, the PoV's delegate keys are also known at that point and can be
fetched in the same parallel batch.

### UI Changes

Dis and rate are **decoupled in the UI**. A single user action never triggers two writes.

**`RateDialog`**: loses dis controls entirely; writes only to the main content stream.

**Phone / `isSmall=true` — swipe gesture**:
- Left swipe → snooze, right swipe → forever (same directions as today).
- Writes directly to the dis stream immediately. No dialog. No rating change.
- The swipe no longer touches the reaction; those are independent.

**Larger interface / `isSmall=false` — card toggle**:
- A 3-way dis toggle (none → snooze → forever → none) appears to the right of the react icon.
- When toggled away from the committed state, the card begins fading visually. Each subsequent
  toggle resets the countdown timer. Toggling back to the committed state cancels the timer and
  stops the fade — no write occurs.
- **Write timing**: the write to the dis stream happens only when the countdown expires. One write,
  reflecting the final toggled state at expiry.
- **Commit on dispose**: if the card is scrolled off-screen or the user navigates away while a
  pending (uncommitted) state exists, write immediately on card dispose.
- **Committed state**: whatever is already written in the dis stream for this subject. For an item
  that was snoozed and has since woken up, committed = `'snooze'` — toggling back to snooze is a
  no-op (no write). Toggling to `'forever'` writes a new forever statement. Toggling to `'none'`
  writes a `clear` against the prior snooze statement, permanently un-dismissing the item.

---

## What Gets Removed (Workaround Code)

| Location | What to remove |
|----------|----------------|
| `content_logic.dart:285-302` | `isQualifiedActivity = false` guard for dis-rate statements |
| `content_logic.dart:426-428` | `myCanonicalDisses` population from main stream |
| `model.dart` | `lastSignalActivity` field; dis-exclusion in `_checkIsDismissed` |
| `feed_controller.dart` | `DisFilterMode.ignore` sort path using `lastSignalActivity` |
| `content_statement.dart` | `dismiss` field, related construction/parsing |
| `rate_dialog.dart` | Dis/snooze controls |

---

## Migration

**We cannot migrate existing data** — users' private delegate keys are inaccessible.

Strategy:
- **Ignore** the `dismiss` field on all existing `ContentStatement` documents. No code reads it;
  old dis data silently becomes inert.
- New dis statements are written exclusively to `/{delegateKey}/dis/statements`.
- Old dismissed items will reappear in feeds; users re-dismiss via the card toggle.

---

## Affected Files

| File | Change |
|------|--------|
| `packages/oneofus_common/lib/direct_firestore_writer.dart` | Add optional `subcollection` param (default `'statements'`) |
| `packages/oneofus_common/lib/direct_firestore_source.dart` | Add optional `subcollection` param (default `'statements'`) |
| `lib/models/content_statement.dart` | Remove `dismiss` field and related logic |
| `lib/models/dismiss_statement.dart` | **New** — `DismissStatement` model |
| `lib/logic/content_pipeline.dart` | Add dis stream fetch for `myDelegateKeys` (parallel) |
| `lib/logic/content_logic.dart` | Remove dis from activity classification; build `myDismissStatements` from dis stream |
| `lib/models/model.dart` | Feed `_checkIsDismissed` from dis stream; remove `lastSignalActivity` |
| `lib/logic/feed_controller.dart` | Remove `lastSignalActivity` sort path; pass dis data into aggregation |
| `lib/ui/dialogs/rate_dialog.dart` | Remove dis controls |
| `lib/ui/content_card.dart` | Add 3-way toggle (large) + rewire swipe (phone) |
| `lib/demotest/demo_key.dart` | See below |
| `test/` | Migrate all dismiss-related tests (see below) |
| `bin/start_emulators.sh` / `bin/export_prod_data.sh` | No changes needed — `gcloud firestore export` exports the entire database; the new `dis/statements` sub-collection is included automatically |

### `DemoDelegateKey` changes (`lib/demotest/demo_key.dart`)

- `doRate()` / `makeRate()`: remove `dismiss` parameter.
- Add `doDismiss(subject, dismiss)` that builds a `DismissStatement` JSON and pushes it via the
  dis stream writer. `SourceFactory.getWriter()` needs to accept the `subcollection` param (or a
  separate registration) to return the dis-stream writer.
- `_localStatements` / `contentStatements`: remain content-only.
- Add `_localDisStatements` / `disStatements`: parallel list for `DismissStatement`s.
- `lib/demotest/test_util.dart`: remove `dismiss` param from `makeContentStatement` helper.

### SimpsonsDemo and test changes

- `simpsons_demo.dart`: replace all `doRate(dismiss: true, ...)` with `doDismiss(...)`. Any call
  that combined `dismiss` with `recommend`/`comment` in one statement must be split into a
  `doRate(recommend: ..., comment: ...)` and a separate `doDismiss(...)`.

---

## Deferred Items (TODO.md)

- **True PoV dis**: fetch and apply PoV's dis stream when the hidden setting is enabled. The fetch
  path is the same as `myDelegateKeys` — just swap in PoV's delegate keys.
