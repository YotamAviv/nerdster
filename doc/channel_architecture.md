# Channel Architecture: Statement Writers, Readers, and the Coupling Invariant

## The Core Invariant

Every statement stream is a linked list. Each statement carries a `previous` field
pointing to the prior statement's token. Writing to a stream requires knowing the
current head — and that knowledge must stay in sync with what the server has.

If a writer and a reader are decoupled, the writer can act on a stale head and
fork the chain. The fix is structural: make it impossible to write without going
through something that also reads and tracks the head.

---

## Current State

### `StatementChannel` (oneofus_common)

The right abstraction already exists:

```dart
abstract class StatementChannel<T extends Statement>
    implements StatementSource<T>, StatementWriter<T> {
  void clear();
}
```

A `StatementChannel` is both reader and writer — you can only write through
something that also reads. `CachedSource` is the concrete implementation: it
caches statement history, tracks the head, and serializes writes per issuer via
a queue.

### `SourceFactory` (nerdster14)

`SourceFactory` is the intended single entry point and correctly returns
`StatementChannel` to all callers. However, it has two caches:

```dart
static final Map<String, StatementChannel> _sourceCache = {};
static final Map<String, StatementWriter> _writerCache = {};
```

The `_writerCache` is the problem — it creates writers independently of channels.
Inside `_cachedSource`, a `StatementWriter` is created first via `_cachedWriter`,
then handed to `CachedSource`. This means the writer object exists separately in
memory, tracked by its own cache. Even if no caller ever sees it directly, the
internal structure allows writers to be detached.

### Concrete Classes Are All Public

`CloudFunctionsWriter`, `DirectFirestoreWriter`, `CloudFunctionsSource`,
`DirectFirestoreSource`, and `CachedSource` are all public classes. Nothing
prevents another coder from importing and instantiating them directly, bypassing
`SourceFactory` and the coupling invariant entirely. This has caused bugs before.

### ONE-OF-US.NET

Constructs `CachedSource` inline in `app_shell.dart` — no factory. The writer
and source are created separately and handed to `CachedSource`. Structurally
identical to Nerdster, but without even a factory to guide usage.

### HabloTengo

Has `HabloChannel` — a single class that owns both reading and writing, caches
the stream head, and serializes writes internally. The closest thing to the
intended design. Callers get a `HabloChannel` from `_getChannel()` in
`contact_service.dart`; there is no separate writer.

HabloTengo also went further on the server side.

---

## The CF-Side Race (Nerdster / ONE-OF-US)

The current write Cloud Function for Nerdster and ONE-OF-US:

1. Queries Firestore for the latest statement (ordered by time)
2. Checks that the client-supplied `previous` matches
3. Writes the new statement

Steps 1-3 are not atomic. Two devices writing concurrently can both read the
same head, both pass the check, and both succeed — forking the chain.
There is a TODO comment in `write.js` acknowledging this.

Client-side queuing in `CachedSource` prevents the race within a single session,
but not across devices or multiple tabs.

### HabloTengo's Fix

HabloTengo stores the stream head as a field on the stream document and uses a
Firestore transaction:

```javascript
await db.runTransaction(async (tx) => {
  const streamDoc = await tx.get(streamRef);
  const currentHead = streamDoc.exists ? (streamDoc.data().head ?? null) : null;
  if (clientPrevious !== currentHead) {
    const err = new Error('Chain race: retry');
    err.code = 409;
    throw err;
  }
  tx.set(streamRef.collection('statements').doc(token), statement);
  tx.set(streamRef, { head: token }, { merge: true });
});
```

The check-and-set is atomic. A 409 signals the client to re-fetch and retry.
Neither Nerdster nor ONE-OF-US leverages this approach yet.

---

## Proposed Direction

### 1. Abstract channels, private implementations

The factory should be the only way to get a channel. Callers should receive an
abstract `StatementChannel<T>`, never a concrete `CachedSource`,
`CloudFunctionsWriter`, or `DirectFirestoreWriter`. The concrete classes should
be package-private (or moved into the factory's file), making it structurally
impossible to hold a writer without a coupled reader.

```
Before: CloudFunctionsWriter (public) → anyone can construct one
After:  CloudFunctionsWriter (private to factory) → can only appear inside a channel
```

The `_writerCache` in `SourceFactory` should go away. The writer is an
implementation detail of the channel, not a separately tracked object.

### 2. FireFactory as the single gatekeeper

`FireFactory` currently just maps domain → `(Firestore, Functions?)`. It could
become the top-level entry point for getting channels — `SourceFactory` collapses
into it, or `SourceFactory` delegates to it entirely. The idea of "all
`fireChoice` branching lives in one place" is right but currently split across
the two classes.

### 3. Adopt the transactional CF write for Nerdster / ONE-OF-US

Port HabloTengo's `head` field + transaction pattern to the shared `write.js`.
The client-side channel already knows how to handle a 409 (retry with fresh
head). Once the CF is transactional, the cross-device race is closed on both ends.

---

## Introducing the `head` Field on Existing Streams

HabloTengo was built with `head` from the start — every stream document has it.
Nerdster and ONE-OF-US have production streams with no `head` field. This needs
careful handling.

### The problem

The transactional CF reads `head` from the stream document:

```javascript
const currentHead = streamDoc.exists ? (streamDoc.data().head ?? null) : null;
```

For a stream with no `head` field, this resolves to `null` — meaning "genesis,
no prior statement." But the stream already has statements. The actual head is
some token deep in the chain.

Consequences:
- A client sending `previous: <actual-last-token>` would fail (server sees null)
- A client sending `previous: null` would incorrectly pass and fork the chain

### Options

**A. Backfill `head` before cutting over.**
A one-time migration script walks every stream document, follows the chain (or
orders by time), finds the latest statement token, and writes it as `head`.
The new transactional CF goes live only after backfill is complete. Clean, but
requires a migration window and careful ordering.

**B. Lazy initialization in the CF.**
If `head` is missing but the stream document exists, fall back to the old
non-transactional query (order by time, get latest token) to initialize `head`
within the same transaction. Avoids a migration window but re-introduces the
race temporarily on the first write to each legacy stream.

**C. Client sends both `previous` and `expectedHead`.**
Not worth the complexity — the whole point is the server owns this.

**D. Treat missing `head` as "uninitialized" and reject the write.**
Forces clients to call a separate `initHead` endpoint first. Too disruptive.

Option A requires a maintenance window — Firestore has no built-in write-pause,
and admin-SDK writes bypass security rules, so there is no way to freeze writes
without user impact. The only practical enforcement is temporarily deploying a
write CF that returns 503.

A cleaner alternative avoids the window entirely: a two-phase deploy.

**Phase 1**: Deploy a new CF that, when `head` is missing on the stream document,
falls back to the old non-transactional query to find the current head, completes
the write, and stores `head` atomically on the stream document. This is no worse
than current behavior for legacy streams, and leaves every stream it touches in
the correct transactional state afterward.

**Phase 2**: Run the backfill in the background to initialize `head` on all
remaining streams. Races are safe: if a write hits a stream before the backfill
does, the Phase 1 CF already initialized `head` correctly; if the backfill gets
there first, Phase 1's fallback is never reached.

Once backfill is complete the fallback code path is dead and can be removed in a
follow-up deploy. This is the recommended approach.

---

## Open Questions

- **`FireFactory` and channel should probably merge into one thing.** Currently
  `FireFactory` registers backends (Firestore, Functions) and `SourceFactory`
  uses them to build channels — two classes, two caches, split responsibility.
  A single class that both accepts backend registration and vends channels would
  be cleaner and harder to misuse. Tests would register a fake backend and get
  fake channels from the same object; `main()` would register real backends and
  get real channels.

  The symptom of the split is code like this (from a test):

  ```dart
  final trustSource =
      DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
  final graph = await TrustPipeline(trustSource).build(pov.id);
  ```

  This bypasses `SourceFactory` entirely, constructs a raw source directly from
  the factory, and hands it to `TrustPipeline` — no channel, no writer coupling,
  no cache sharing. It works for read-only pipeline tests but is exactly the
  anti-pattern the architecture should make impossible. If channels were the only
  thing the factory vended, this code couldn't be written this way.

- **Migration path**: `StatementChannel` exists but making implementations
  package-private is a Dart package boundary decision. Does this move into
  `oneofus_common`, or does each app/repo get its own factory that hides things?

- **ONE-OF-US.NET**: Has no factory today. Does it get `SourceFactory` too,
  or something simpler?

- **HabloTengo's `HabloChannel`**: Already close to the target. Does it become
  a model for a shared `TransactionalChannel` in `nerdster_common`, or stay
  app-specific?

- **Testing / backend registration**: The right model: whoever initializes the
  app — `main()` or a test harness — registers the appropriate backend with the
  factory. The factory is the only place that decision is made; nothing else in
  the codebase knows which backend is in use.

  ```dart
  // Fake run (?fire=fake) or test harness:
  FireFactory.register(domain, FakeFirebaseFirestore(), null);
  // Emulator or prod run:
  FireFactory.register(domain, FirebaseFirestore.instance, FirebaseFunctions.instance);
  ```

  This matters for Nerdster in particular: the web app can be run against a fake
  backend via URL params (`?fire=fake&demo=simpsonsDemo`, etc.), which is useful
  for development without a phone or emulator. `main()` reads the params and
  registers accordingly — it is not always registering real backends.

  The factory creates channels from whatever was registered. `FireChoice` as an
  enum collapses into the factory itself — no `if (fireChoice == fake)` anywhere
  else. Concrete writer/source classes become private to the factory.

  Per-project recommendations:

  - **Nerdster14**: Worth investing in. Fake mode is actively used both for web
    development (`?fire=fake&demo=...`) and for the test suite. The current
    `FireFactory` + `SourceFactory` + `FireChoice` is close — clean it up rather
    than replace it. Keep the fake path.

  - **ONE-OF-US.NET**: Don't invest in fake mode now. Phone-only, likely broken,
    no test suite that uses it. Hardcode emulator vs. prod in `main()` and revisit
    only if a proper test suite is added.

  - **HabloTengo**: Web-only; fake mode is not practical. Almost all logic lives
    in JavaScript Cloud Functions — there is nothing meaningful to fake on the
    Flutter side. Testing is always against prod or the emulator.

- **409 handling**: The transactional CF makes detection of chain races reliable,
  but a 409 should still surface via the `optimisticConcurrencyFailed` callback —
  not be silently retried. Automatic retry would swallow the signal that two
  writers raced, hiding a real conflict from the app and user. The callback path
  exists so the app can decide what to do (reload, warn the user). That contract
  should not change.


# Plan

Share the same factories and implementations across all 3 projects.
Do it once, not bit by bit, but one project at a time (Nerdster first). 
Test thoroughly.

Must be backward compatible with existing data for all 3 projects.

Code to go in oneofus_common

## Open questions:

Hablo read/write is different than the others requiring auth. How different does this make this? Factor or duplicate functionality.

## Factory

Find a good name for this new factory that might consume more than one factory things (FireFactory and SourceFactory) we already have.

Must be initialized with:
- fire choice

Can then provide a channel given:
- endpoint
- String streamKey
  For Oneofus and Nerster, this is a key token
  For Habloe this is token1_token2.
  Just call it a string. It shouldn't matter for the abstraction here.
- functions (unless Fake)

Keeps callers out of trouble:
- Caches the channels
- Has a global clearCache
- Has a global clearData (Fake only. this is what makes tests hermetic (reset between test cases))
- Internal source/writer classes are private

Impl:
- Contains endpoint mapping of prod endpoints to emulator details (port and such)
DEFER: Something fancier in case other developers join.

## Work

Fake channel (like direct source/writer) that acts like the CF backed channels.

### Cloud functions side

Use the lazy approach suggested above for adding "head".

### Client side

Fix bug with doubly cached writer mentioned above.

### Nerdster Dart unit tests

Initialize factor with fireChoice = FireChoice.fake.

### Nerdster Dart client 

Initialize factory with any fireChoice.

### Oneofus Dart client

Initialize factory with any fireChoice.

### Hablo Dart client

Intialize factory with emulator or prod only (depends on cloud CF implementations impossible to fake)

### Hablo Dart unit tests

N/A: Not Dart unit tests (only JavaScript unit tests and Dart integration tests against emulators)*.

AI: Comments below here: -------------------------

**Hablo auth vs Nerdster/ONE-OF-US auth:**
Nerdster and ONE-OF-US authorize writes via the Ed25519 signature on the statement itself — the CF verifies the signature, no separate session token.
Hablo requires a session auth payload (identity + sessionTime + sessionSignature) on every CF call (reads and writes) because contact data is private.
The shared channel interface can stay the same (push(json, signer)), but the factory needs a way to accept a session-credential provider for Hablo — absent for Nerdster/ONE-OF-US. How should the factory be initialized differently for Hablo?

Continued discussion: 
The Hablo Read and Write CFs necessarily need to be different files from Oneofus, Nerdster as auth needs to be enforced at the server layer.
Hablo currently reads and assembles data at the server layer for its front end and only provides plain read functionality to export the stream. 
There are 2 different authorizations Hablo needs
- export stream (identity/delegate)
- write to stream (identity/delegate)
Both of authorizations are per identity but they're different (write to your own only, ready depending on that identities trust graph)
Suggestion:
At the server side along with read and write include an abstract function called the read and write CF functions:
  bool auth(String streamKey)
Oneofus, Nerdster will always return true; Hablo will use its own complicated auth.

AI: The server-side `auth(req, streamKey)` abstraction is clean — shared write.js calls it, each project supplies its own implementation. Note: the signature will need `req` (not just streamKey) so the Hablo implementation can read the session credential from the request body.

On the client side this simplifies things: `HabloChannel` already attaches the auth payload to every request. The factory just needs to construct `HabloChannel` with a `SignInState` (or equivalent credentials object). Nerdster/ONE-OF-US channels need no credentials at construction. So the factory init doesn't need a special Hablo-specific parameter — it just constructs the right concrete channel type based on fireChoice, passing credentials only where needed.

Resolved: constructor parameter. Makes the dependency explicit and the factory testable without touching global state.


**CF change ordering:**
The lazy-head CF deploy is a prerequisite for the Nerdster client migration — it must go live before the updated Dart client does.

Answer: 
None of these projects gets a lot of traffic, especially write traffic, and so:
1) Deploy a disabled Write CF
2) Run backfil of "head" data per stream
3) Switch to the correct Write CF

AI: Simpler and cleaner than the lazy two-phase approach given low write traffic. Make the disabled CF return 503 with a clear message so clients surface a real error rather than silently misbehaving during the window.

**Fake channel seed:**
`clearData` resets state between tests. Does the fake also need a `seed`/`populate` affordance for loading demo data (Simpsons, etc.) before a test run, or does each test write its own data from scratch?

Answer: 
No seed / populate required.

AI: Resolved.

---

# Implementation Progress (branch: channels-refactor, as of 2026-05-07)

## What is done

### Client side (nerdster14 + oneofus_common)

- **`ChannelFactory` / `channelFactory`** — single entry point for all statement channels,
  in `oneofus_common/lib/channel_factory.dart`. Replaces `SourceFactory` and `FireFactory`
  in nerdster14. Initialized once in `main()` and in test `setUp`; all fireChoice branching
  lives here. `FireChoice` enum lives here too (not in a separate file).
- **`CachedSource`** — two bugs fixed:
  - `_inject` now applies `distinct()` so a clear-then-trust doesn't leave the old trust
    statement in cache.
  - `fetch()` with `revokeAt` now correctly filters in-memory when the token is in the
    full cache; falls through to the underlying source when the revokeAt token lives in a
    different stream (e.g. `dis`).
- **`CloudFunctionsWriter`** — `baseUrl` field renamed to `writeUrl`; now takes the full
  write URL directly (no `/write` appended inside). `ChannelFactory` constructs the URL as
  `${functionsUrl}/${writeEndpoint}`.
- `writeEndpoint` defaults to `'write2'` in `ChannelFactory.register()`.
- `nerdster14/lib/fire_choice.dart` re-exports `ChannelFactory`, `channelFactory`,
  `FireChoice` from oneofus_common so existing call sites compile unchanged.

### Server side (nerdster14/functions)

- **`write.js`** — rewrote to use Firestore transaction on `head`/`headTime` stream field,
  eliminating the TOCTOU race. `makeWriteHandler(auth)` pattern: shared handler, project
  auth injected. Registered as `exports.write2` (`onRequest`, CORS enabled).
  **Not lazy**: requires `head` to be present on every stream doc before deployment —
  missing `head` is treated as genesis, which would corrupt existing streams. Backfill is
  a hard prerequisite.
- **`auth_nerdster.js`** — new file; trivial auth (signature verification in write.js is
  sufficient for Nerdster).
- `functions/index.js` updated accordingly.

### Server side (oneofusv22/functions)

- `write.js` — reverted / kept as original `onCall` handler. Old clients continue to work.
  The async `keyToken`/`statementToken` calls are now properly `await`-ed (bug fix).
- **`write2.js`** — new file; same `makeWrite2Handler(auth)` transactional pattern as
  nerdster14's write.js. Registered as `exports.write2` (`onRequest`, CORS enabled)
  alongside the old `exports.write`.
- **`auth_oneofus.js`** — new file; trivial auth (same as auth_nerdster.js).

### Migration tooling

- **`bin/backfill_head.js`** (nerdster14) — seeds `head`/`headTime` on all existing
  Firestore streams. Supports `--emulator` and `--dry-run`. Run once against each project
  before `write2` receives real traffic. Already run against the nerdster emulator
  (1028 streams scanned, 553 updated).

### Tests

All tests pass:
- 113 Flutter unit tests (includes delegate_revocation_test with new cross-stream revokeAt
  test case)
- 22 oneofus_common package tests
- 18 backend (Node.js) tests
- Chrome widget test (cloud_source_web_test) — all permutations including concurrent write

---

## What is NOT done / next steps

### Deployment sequence (nerdster14 only for now)

Oneofus and Hablo are out of scope until nerdster is validated end-to-end.

1. **Transition branch** — create a branch with:
   - CF code from this branch (`write.js` as transactional `onCall` — same external
     interface as today, new internals). This does not exist yet; the current `write.js` in
     this branch is `onRequest` (`write2`), not `onCall`.
   - Client code from `main` (old callable format).
   - This represents the production state during the window after CF deploy and before all
     clients have refreshed.

2. **Test transition branch on emulators** — run full test suite using main-branch client
   against new CF code. This validates that existing clients keep working.

3. **Backfill** — run `bin/backfill_head.js --dry-run` against prod nerdster, then run for
   real. Must happen before the new CF goes live.

4. **Deploy nerdster CFs** — deploy `write2` (+ `auth_nerdster.js`) to production.
   Old `write` endpoint is unused by new clients but can be left or removed — nerdster14
   is web-only so client refresh is near-instant.

5. **Deploy oneofusv22 CFs** — deploy `write2` alongside old `write`. No backfill needed
   yet (nerdster demo writes to fresh streams; existing Oneofus streams used by real users
   continue using old `write`).

### Testing the transition (two-checkout approach)

No transition branch needed. Instead:

- **Checkout A** (main branch) — run `run_all_tests.sh`. This runs the old Flutter client
  code (onCall `write`, `{"data": {...}}` envelope). The test runner connects to whatever
  emulators are on the standard ports.
- **Checkout B** (channels branch) — start the emulators. They load channels-branch CF
  code (transactional `write` onCall + `write2` onRequest).

This exactly mirrors the production transition state: new CF already deployed, old clients
still running. No branch mixing, no artificial intermediate branch.

Prerequisite for this to work: nerdster's `write.js` on the channels branch must expose a
transactional `write` (`onCall`) alongside `write2` (`onRequest`). Currently only `write2`
exists; `write` was removed. Fix: extract the transaction core into a shared function
callable from both wrappers, and re-register `write` as onCall in index.js.

### Oneofus and Hablo

Not upgrading yet. Oneofus phone app clients take time to refresh. Hablo has its own auth
complexity. Both are deferred until nerdster is validated.


## FURTHER QUESTIONS / CLARIFICATIONS

Good morning,

Reaquint yourself with what's going on.

A couple of questions / clarifications:

None of our tests against the emulator write to existing data, and that's the critical thing that needs to be tested. Correct?
AI: Correct. The emulator tests always start fresh — demo identities (Lisa, Marge, etc.) write to brand-new streams that have no prior statements, so `head` is always null on first write, which is the genesis case. The transaction handles that correctly. The untested scenario is writing the *second* statement to a stream that already exists in Firestore but has no `head` field — i.e., exactly what every real user's stream looks like before backfill.


I can do this by restoring an export with PROD data from my own network and making sure I can rate, diss, ... That's necessary, correct?
AI: Yes, necessary. Restoring your own prod export to the emulator and attempting to write (rate, dis, etc.) against it is the right test. It exercises the code path where the stream doc exists, has existing statements, but `head` is null/missing — the critical pre-backfill case. The emulator's fresh-data tests don't cover this at all.


Furthermore, it's expected that old or new Dart code running against old data that has not yet been backfilled will fail. Correct?
I think that this is worth confirming, and so I'll plan to:
- try and write to my own exported PROD data from both old and new code on un-backfilled data and expect both to fail.

AI: Correct for the new code (write2 / transactional onCall). Missing `head` is treated as genesis (null), so a client sending `previous: <actual-last-token>` gets a 409 chain race, and a client sending `previous: null` would incorrectly succeed and fork the chain. Either way it's broken.

The OLD code (un-backfilled data): works fine. It uses `orderBy time desc limit 1`, ignores `head` entirely, so missing `head` does not affect it.

However there is a post-backfill problem with the old code: once backfill seeds `head` on all streams, any write through the old `write.js` (which doesn't update `head`) leaves `head` stale. The next `write2` call reads that stale `head`, gets a 409 chain race, and the transactional endpoint is broken. Every old-client write sabotages `head`.

Fix applied: `oneofusv22/functions/write.js` now updates `head`/`headTime` after every successful write (while still using `orderBy` for the chain check). Both endpoints keep `head` current, so they are safe to run side by side.

Confirming the failure on un-backfilled data with the new code is exactly the right test to run before backfilling prod.


What's the difference between onRequest and onCall?
AI: Both are Firebase Cloud Function HTTP endpoints. The difference is the protocol layer:

`onCall` — Firebase callable protocol. The client uses the Firebase SDK (`FirebaseFunctions.instance.httpsCallable('write')`). The SDK automatically wraps the request body as `{"data": {...}}` and unwraps the response from `{"result": {...}}`. Errors come back as structured `HttpsError` objects. Auth tokens are attached automatically if the user is signed in to Firebase Auth.

`onRequest` — plain HTTP. The client sends a raw POST with whatever body it wants and reads the raw response. No SDK envelope, no automatic auth. Our `CloudFunctionsWriter` uses this: it POSTs `{"statement": ..., "collection": ...}` and reads `{"token": ...}` directly.

The callable protocol is convenient when you're already using the Firebase SDK and want structured error handling. The plain HTTP approach is simpler, more portable, and doesn't require the Firebase client SDK on the caller side.


## FURTHER QUESTIONS / CLARIFICATIONS 2

Reality:
- we can't quickly upgrade all clients phone or webapp
- we can quickly upgrade all CFs
- nerdster uses the same Dart libraries to read from Oneofus and Nerdster
- nerdster doesn't write to Oneofus
- new clients will be broken trying to call write2 if it's not there.
- write2 is transactional and depends on "head" being in the data.

Updated plan:
- upgrade write.js in both Nerdster and Oneofus to be lazy about "head"
  - add it if it's missing
  - keep it updated if it's there
  - (not transactional)
- push write.js (identical) to both projects
- run the backfill without taking down either apps
- at this point, all data streams should have correct "head" (barring unlikely transaction failures)
- update both projects (one at a time) to use the new Dart libraries that use write2.js which:
  - must have "head" exist on all streams
  - is transactional.

Testing:
- in my local environment
- export PROD data to emulators
- run old Nerdster code from main branch and verify writes work
- run the backfill script on the emulators
- run old Nerdster code from main branch and verify writes work
- run new Nerdster code from channels branch and verify writes work.  

AI RESPONSE:

The plan is sound. A few reactions:

**The lazy init gap.** The fix to `oneofusv22/write.js` already updates `head` after every write, but it doesn't initialize `head` lazily when it's missing. The user's plan correctly identifies this gap: write.js also needs to fall back to `orderBy` when `head` is absent and seed it. Without that, the lazy write.js is only half-implemented.

**Nerdster14's write.js already went the wrong direction.** The current `write` (onCall) in nerdster14 calls `writeCore`, which is fully transactional and treats missing `head` as genesis. That means it would fail for any old client writing to an un-backfilled stream. It needs to be converted to the lazy/non-transactional approach before deploying, otherwise backfill is a hard prerequisite for nerdster14's old endpoint too.

**The files can and should be identical.** They were identical in main. The `makeWriteHandler` factory pattern introduced in nerdster14's channels branch caused the divergence, but that pattern only belongs in `write2`, not in the old `write` endpoint. The lazy write.js is a plain onCall handler and can be copy-identical across both projects.

**Backfill is still required before write2 gets traffic.** Even with lazy init, inactive streams that never receive a write through the old endpoint will never get `head`. write2 would 409 on them. Backfill still needs to run before any client is pointed at write2 — it's just no longer a prerequisite for deploying the CF.

**Testing plan is complete.** The key step is verifying that old code still works against backfilled data — it should, since orderBy doesn't use `head`. That's the regression check.
