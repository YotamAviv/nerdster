# Channel Architecture: Statement Writers, Readers, and the Coupling Invariant

## Design Principles

1. **Tests use the API the way production callers do.** If production code calls `push()` and then reads from a channel, the test should do the same. Tests don't poke Firestore directly to work around something the API should handle.

2. **Each piece does its own job and nothing else.** The server filters what you ask it to filter. The cache holds what you've fetched plus what you've written locally. The channel is a typed view of the cache. Nothing doubles up on someone else's job.

3. **Optimistic means the caller never waits for the network.** `push()` returns with the result. The network write happens in the background. No exceptions, no callers that partially wait.

4. **A channel is a typed view; the root is the storage.** All typed views of a stream share one underlying cache. A write is immediately visible through any typed view — no re-read needed.

5. **`excludeTypes` tells the server what to omit.** It is a server-side parameter. A local filter that achieves the same result is not the same thing.

6. **Don't fix one thing by breaking another.** If fixing A requires violating an invariant in B, the design needs rethinking — not a trade-off.

7. **`clear()` is what the refresh button calls.** It drains pending writes so the server is current, then wipes the local cache so the next read comes from the server.


My (human) updates:

- FakeFirestore is there specifically for testing.
It should act like the cloud variants (emulator and prod) so that we can test using unit intead of integration tests.
It is worthwhile to make the FakeFirestore act like the other so that it can be used to test as much as possible.

- Test should test the infrastructure using the API the way callers do. If tests fail, fix the infrastructure, not work around broken tests.
That said, we have tests that are not trying to test the channel infrastructure at all but are trying to test the content pipeline, the delegate resolver, tag equivalence, or something else entirely. Those tests may be trying to work around the channel infrastructure, and it's okay to, if necessary, document that and let them.

- Optimistic concurrency
  - It means something, and it's important. A caller with a stale cache cannot be allowed to write. This, too, needs to be tested.
  - It's there to make the UI responsive, like AJAX. The whole point is to succeed quickly. If we fail later, it's okay to crash.

- Some tests exist or should be added to test not just correct outcomes but that we didn't cheat to get there.
We've had situations where the AI takes a shortcut and drops important charcteristics mentioned above (responsiveness, saving bandwith, optimistic concurrency).
And so we need tests that use back door methods to verify that things not only give the correct result but don't violate how they're supposed to work
  - Optimistic concurrency vioations should fail
  - Over fetching data from the server should fail
  - Awaiting write completion should fail

- Server-sde "excludeTypes" is important. That said, channels don't have to support every possible use. In our case, channels with an excludeType can be read-only. We don't need to bend over backwards to support writing to an excludeType restricted channel.

- The UI has a "refresh" button for a reason, and it should be async, clear the cache of any pending writes (flush) and then load. We should not refresh for no good reason.

Immediate goal:
- Much of the code is old and can be removed.
  - We should do a pass and toss out some old functionality (eg. dumpStatements)
  - We should figure out what needs to be tested for channel infrastructure correctness, document that as a doc, and then make sure we have tests to exactly what we want to test. We don't need to maintain irrelevant, older, existing tests.
    - Partial identity revokeAt is gone, for example.
    - We're done figuring out GreedyBFS. We should test it but as much as we were when we didn't understand it.

- Supported use case - changing PoV
When we change Point of View, there may be some new channels that we need to have fetch, some that were fetched but now respect a different revokeAt statement, some that are no longer used.
We don't want to be wasteful and fetch it all from scratch, but it's okay to not be perfect; for example, if we had a channel fetched until a revokeAt value and now we have a different revokeAt value from a new PoV, it's okay to re-fetch the whole thing, but it's not okay to re-fetch everything.

---

## The Core Invariant

Every statement stream is a linked list. Each statement carries a `previous` field
pointing to the prior statement's token. Writing to a stream requires knowing the
current head — and that knowledge must stay in sync with what the server has.

Correct writes require knowing the current head, which requires reading. A channel couples the two so that writing without knowing the current stream state is structurally impossible.

---

## What Channels Provide

A channel is the single entry point for reading and writing a statement stream. Reading and writing are coupled: you can only write through something that also reads and tracks the stream head. This makes it structurally impossible to write with a stale head within a single app instance.

```dart
abstract class StatementChannel<T extends Statement>
    implements StatementSource<T>, StatementWriter<T> {
  Future<void> clear();
}
```

### Optimistic writes — performance with correctness

A write returns immediately with the result visible in the local cache. The network write happens in the background. The UI never waits for a server round-trip.

Correctness is preserved server-side: if the local head is stale (another app instance already advanced the stream), the server rejects the write with a conflict error. The error surfaces to the app via an error callback; it is not silently retried.

### Write access requires a signer

Every write must be signed with the private key of the issuing identity or delegate. A channel that belongs to a stream the app cannot sign for (e.g., Nerdster reading trust data from one-of-us.net, where the user's identity key lives) is effectively read-only. There is no structural enforcement of this at the channel level — it is enforced by the absence of a signer.

### Type exclusion — server-filtered, read-only

### This is critical for performance
Nerdster: users dismiss thousands of items but rate dozens, so fetching peer content without dismiss statements saves significant data. 

A channel can be opened asking the server to omit certain statement types. Filtering happens on the server — excluded types are never transferred. Each token is fetched through exactly one channel — the signed-in user's stream through the full channel, peer streams through the no-dismiss channel. Channels with type exclusion are read-only; writes go through the full channel.

### Two roots for the same stream

A stream may be opened with two different configurations (e.g., distinct=true and distinct=false for the same token). In this case the same token appears in both roots and a write through one must fan out to the other so both stay current. The distinct=false root (full history view, e.g. for a key-replacement flow) should be read-only; writes go through the distinct=true root.

### Change of point of view

When the point of view changes (different identity, or a different revocation boundary), only the channels whose configuration has changed are re-fetched. The rest keep their cached data. Re-fetching everything on a PoV change is not acceptable.

---

# Implementation Notes (channels-refactor, deployed 2026-05-08)

- **`ChannelFactory`** (`oneofus_common/lib/channel_factory.dart`) — single entry point for all statement channels; replaces `SourceFactory` and `FireFactory` in nerdster14.
- **`write2`** — transactional Cloud Function using a `head`/`headTime` field on each stream document. Eliminates the TOCTOU race. Requires `head` to be present before deployment; `bin/backfill_head.js` seeds it on existing streams.
- **Old `write` endpoint** — kept on both projects for backward compatibility with clients that haven't upgraded.

---

## Deployment log

### 2026-05-08 ~09:45 PDT

- **CFs deployed to production** — both nerdster14 and oneofusv22. `write` (lazy onCall)
  and `write2` (transactional onRequest) live on both projects.
- **Backfill run** — `bin/backfill_head.js` executed against prod for both projects.
  All existing streams now have `head`/`headTime`.
- **New Dart code deployed to Nerdster** — channels branch live. Clients now use `write2`.
  `pubspec.yaml` version/build number bumped (not yet committed to repo).
- **Full test suite passed** — `bin/run_all_tests.sh` green on both nerdster14 and
  oneofusv22 after deployment.

### Next steps

- Commit the `pubspec.yaml` version bump to the channels branch.
- Oneofus and Hablo Dart client upgrades — deferred. Oneofus phone clients take time to
  refresh; Hablo has its own auth complexity. Both continue using the old `write` endpoint
  indefinitely until upgraded.

---

## Channel Infrastructure: What Needs to Be Tested

Tests must verify not just correct results but that the infrastructure achieves them correctly — no over-fetching, no waiting on network writes, no optimistic concurrency violations.

### Covered

| Behavior | Test |
|----------|------|
| A write is visible locally before the network confirms it | covered |
| A write is visible immediately via any typed view — no re-read needed | covered |
| Refresh drains pending writes before wiping the local cache | covered |
| distinct=false: all statements accumulate in the cache | covered |
| distinct=true: a new statement about the same subject(s) supersedes the previous one | covered |
| Fanout between distinct variants: write through distinct=true fans out to distinct=false | covered |
| No over-reading after a write — pushed data served from cache, not re-fetched | covered |
| clearCache() drains all pending writes and clears all channel caches | covered |
| Fake backend applies excludeTypes at source, not as a local filter | covered |

### Tested elsewhere (not Dart channel infrastructure)

- **Server rejects a stale previous token**: if two independent app instances each read the same stream and then both try to write, `write2` rejects the second write because its `previous` token is no longer the current head. Tested in the Node.js backend tests.

### Notes

- **Tests that bypass channels must say so**: some tests legitimately write directly to storage — to inject bad data, test error recovery, or simulate corruption. That's fine, but the test must document that it is intentionally bypassing the channel API and why.

---

## Waiting for write completion

### The exception to principle 3

`ChannelFactory(fireChoice, optimisticWrites: false)` makes `push()` return only once the
network write has landed, and complete with an error if it failed. This is a deliberate,
documented exception to design principle 3 above ("the caller never waits for the
network"). **Do not "fix" it, and do not add a test asserting that no caller ever awaits
write completion without excluding this mode.**

Who uses it: the ONE-OF-US.NET identity app, and only it. Nerdster and hablotengo keep
the default (`true`) — they take rapid repeated writes (dismiss, snooze, dismiss, snooze)
and cannot block the UI on each one.

Why the identity app needs it: every statement there is a deliberate act the user must be
told the outcome of, and one caller has a hard ordering requirement.
`SignInService.signIn` publishes a `delegate` statement and then hands the service the
delegate key pair; the service looks that statement up the moment it signs the user in.
If the write is still in flight, the service reports "Delegate key not associated". See
`oneofus/doc/write_completion.md`.

`ChannelFactory.onWriteError` still fires in this mode, in addition to the caller learning
of the failure. The optimistic `_inject` has already fanned out to sibling roots by the
time a write fails, and only that handler clears them.

### The layers underneath

Read side:

| | cached | transport | visibility |
|---|---|---|---|
| `_CloudFunctionsSource` | no | GET `export.[domain]`; verifies signatures, handles `revokeAt`, seed bag | private (`rawSourceForTesting` is a token-gated escape hatch) |
| `DirectFirestoreSource` | no | Firestore direct | public, `FireChoice.fake` only |
| `_CachedSource` | yes | wraps either | private, reached via `getChannel` |

Write side:

| | transport | who supplies `previous` | visibility |
|---|---|---|---|
| `_CloudFunctionsWriter` | POST `write.[domain]` | caller must | private |
| `DirectFirestoreWriter` | Firestore transaction | self-discovers (`orderBy('time','desc').limit(1)`) | public, fake/emulator only |

`_CloudFunctionsWriter` with no `optimisticConcurrencyFailed` callback is already a
minimal synchronous writer: sign, POST, throw on failure. It is private, and unlike the
source there is no accessor for it.

`_CachedSource` is in the identity app's write path for one reason: head tracking.
`functions/write.js` rejects a `previous` that does not equal the server head, so the
cloud writer's caller must know the head. `_CachedSource` knows it as
`_fullCache[issuer].first.token` — the cache is a side effect of that job, not the point.

### Considered and deferred: a cache-free writer for the identity app

A layer built for background commits and optimistic concurrency, with a flag to switch
that off, is not the simplest thing the identity app could use. The shape that would
remove the exception:

1. `channelFactory.getWriter<T>(exportUrl, streamKey)` returning the bare cloud writer.
   An accessor, not a public class — the factory owns the emulator redirect for
   `write.one-of-us.net` and any `writeAuthHook`.
2. No head discovery in the writer. `previous` stays optional on the `StatementWriter`
   interface (`DirectFirestoreWriter`'s self-discovery is used by
   `oneofus/integration_test/bidirectional_trust_test.dart` and is fine there) but the
   cloud writer asserts it was supplied. A writer that *can* read is a writer that a later
   change will make read on every write, with nothing at the call site to show it.
3. Reads stay on `getChannel`: it already handles federated endpoints, `revokeAt`, and
   verification, and a read cache is harmless.
4. An app-owned holder of {writer, head} — no cache, inject, fanout, queues, or optimism —
   so the identity app's three push sites keep their current shape:
   `app_shell._executePush`, `SignInService.signIn`, and the `replace_flow` loop that
   re-publishes N statements each chaining onto the last.
5. `optimisticWrites` disappears. The REP INVARIANT in `oneofus/lib/ui/app_shell.dart`
   loses its cache clauses. The user-facing failure path stays — a write can still fail
   (two phones, a CF error) and the user must still be told to reload everything — but it
   moves into `_executePush`'s catch instead of a library callback. Today a failed write
   there shows *two* dialogs, the snackbar from `_executePush` and the modal from
   `oneofusWriteErrorFunc`; consolidating would give one.

Deferred because the bug needed one behavior changed, while this changes the identity
app's data flow, three push sites, and a package shared by three repos. The remaining
benefit is simplicity, not correctness.

### Traps for whoever picks it up

- The head must come from the **raw** fetch result, not from `myStatements`.
  `_loadAllData` strips `clear` statements before storing it, so if the newest statement is
  a `clear`, `myStatements.first` is the wrong token and the next write is rejected.
  Server-side `distinct` is safe: it deduplicates by verb+subject keeping the most recent,
  so the raw fetch's first element is the head.
- A head is only valid for an *unfiltered* fetch. A channel created with `excludeTypes` may
  not return the stream's head at all — which is why the Nerdster's peer content channel is
  a separate root with its own cache.
- `statement_fetcher.js` returns statements time-descending, so `first` is the head.
  `orderStatements` in the export params is about JSON *key* order, not statement order.
- The core invariant section above allows publishing during another publish; the channel
  serializes per issuer and chains the injects. Sequential awaited pushes off a head holder
  chain fine, but two genuinely overlapping un-awaited pushes would read the same head and
  one would be rejected. Preserving today's behavior needs a per-issuer future chain in the
  holder.
- `Tester` (`oneofus/lib/demotest`, demo and video data) pushes through the channel and is
  typed `StatementWriter?`. It pushes as identities whose history was never fetched, which
  is in tension with `_CachedSource.push`'s `assert(_fullCache.containsKey(issuerId))`.
