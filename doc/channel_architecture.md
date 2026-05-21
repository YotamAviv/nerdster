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

A channel can be opened asking the server to omit certain statement types. Filtering happens on the server — excluded types are never transferred. This matters for bandwidth: in Nerdster, users dismiss thousands of items but rate dozens, so fetching peer content without dismiss statements saves significant data. Each token is fetched through exactly one channel — the signed-in user's stream through the full channel, peer streams through the no-dismiss channel. Channels with type exclusion are read-only; writes go through the full channel.

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

### Missing

- **Fanout between distinct variants**: when the same token is open in both distinct=true and distinct=false roots, a write through the distinct=true root must be immediately visible in the distinct=false root without a re-read. Not yet tested.

- **No over-reading after a write**: after a write, reading from the same channel must not go back to the server. The written data is already there.

- **Refresh flushes and clears all caches**: after the refresh button is pressed, all pending writes are drained to the server and all local caches are cleared. No stale data remains.

- **Fake backend filters the same way as the real one**: when tests run against the fake backend, type-exclusion must be applied at the source, not locally after the fact. Otherwise the unit tests aren't testing what the real system does.

- **Tests that bypass channels must say so**: some tests legitimately write directly to storage — to inject bad data, test error recovery, or simulate corruption. That's fine, but the test must document that it is intentionally bypassing the channel API and why.

### Tested elsewhere (not Dart channel infrastructure)

- **Server rejects a stale previous token**: if two independent app instances each read the same stream and then both try to write, `write2` rejects the second write because its `previous` token is no longer the current head. Tested in the Node.js backend tests.
