
# Dismiss is not Rate

## Dis is not recent activity / new rating

Initially "rate" statements could have {with: {dis: true}}
But having the same statement type, verb, and subject they would resolve ("single disposition" ) and clobber (distincter) other ratings.
So we made it easy to dis and restate your rating, but that makes a dis from 1 user have another user see that as "recent activity"

## Flawed mult-streams
We separated out the rate statements and dismiss statements into 2 differnet streams.
We built infrastructure to suppport that, including revokeAt.

### It's flawed!
If a bad actor gets your private delegate key, he can completely invent the stream that is not the one that revokeAt refers to.

## Suggested fix

Use a different statement type for dismiss statements and keep them in the same stream as the content statements.
This can avoids having them clobber (see "singular disposition", distinct, distrincter.dart) other statements about the same subject.
The cloud fetch mechanism (see export.js) can have added filters to skip fetching dismiss statements that we don't care about, such as for other users that are not the active user whose disses we do care about.

AI: 
- read the relevant code
- confirm what you understand
- try to think of any flaws with the suggested fix
- make a plan of the work to do.
- Your contribution should be appended below here. Do not edit text above here

---

## AI contribution

### What I understand from the code

Dis statements already use a distinct statement type (`'org.nerdster.dis'`) separate from rate statements (`'org.nerdster'`). Both use `'rate'` as their subject field. The distincting logic (`distincter.dart`) is per-statement-type, so they don't clobber each other at that level.

The current problem is about *streams* and the revocation model. Statements are portable: they are trusted because of the signing key, not because of where they are hosted. The delegate statement points to the delegate key and an optional `revokeAt` token. That token can currently live in either the `statements/statements` stream or the `dis/statements` stream — it is not pinned to one. Revocation only covers the stream where the `revokeAt` token is found. With two streams, the revocation of one does not cover the other. With a compromised delegate key, an attacker can fabricate any number of signed streams of any type with arbitrary dates. The multi-stream design opens this door: once you accept that valid statements may come from more than one linked list, there is no principled way to exclude fantasy lists an attacker invents. The fix is to close that door — a single stream, a single linked list, with `revokeAt` pointing to a token in it. Anything outside that list is simply not considered.

`export.js` currently supports an arbitrary `subcollection` parameter for fetching from any stream — this is the flawed infrastructure that enables the multi-stream design. The client (`CloudFunctionsSource`) currently passes `subcollection=dis/statements` when fetching dis.

The feed controller fetches dis statements separately, only for the active user (and their delegates), not for peers. So peers' dis statements are never needed.

---

### The suggested fix

Write dis statements into the same stream as content statements (`statements/statements`) instead of a separate `dis/statements` stream. Since dis statements already use a distinct type (`'org.nerdster.dis'`), they will not clobber rate statements via the distincter. This closes the multi-stream door: there is one linked list, one `revokeAt` covers everything in it, and no other list is considered valid. To avoid pulling peers' dis statements during content fetches (we only ever need the active user's own dis statements), add a server-side filter in `export.js` to exclude dis-type statements on request.

### Notes and tradeoffs

**1. Avoid fetching peers' dis statements**
If dis statements move into `statements/statements`, fetching any peer's statement stream for content purposes will now include their dis statements. We never use peer dis statements. This is wasted bandwidth and processing. The suggestion anticipates this — the `export.js` filter — but that filter needs to be implemented and called correctly from the client side.

**2. Abandon (don't migrate) istoric dis statements**
not a big deal.

**3. revokeAt scope covers all statement types in the stream**
With dis in the same stream as content, revoking the stream (e.g., on key rotation) revokes both content and dis statements simultaneously. This is the right behavior.

---

### Scope note

The infrastructure (`oneofus_common` package, cloud functions) is shared across Nerdster, Oneofus, and Hablo. Removing multi-stream support will eventually affect all three, but do not focus on them now. Only update:
- the `oneofus_common` package inside the **Nerdster** repo (`packages/oneofus_common/`)
- the cloud functions inside the **Nerdster** repo (`functions/`)

Integration tests that use the emulator may cause confusion: if the Nerdster emulator functions are updated but the Oneofus emulator functions are not (or vice versa), tests that cross the boundary may behave unexpectedly. Be aware of this. Updating the Oneofus emulator functions may turn out to be necessary as part of this work.

### Plan

1. **`export.js` / `statement_fetcher.js`**: Add an optional `excludeTypes` query parameter (e.g. `excludeTypes=org.nerdster.dis`) that filters out statements of those types before returning. Remove the `subcollection` parameter entirely.

2. **`CloudFunctionsSource` (Dart)**: Add an optional `excludeTypes` parameter and pass it through to the export URL. The channel factory is infrastructure and stays ignorant of Nerdster specifics — the caller (`feed_controller.dart`) decides what to exclude.

3. **`DismissStatement` write path**: Change the Firestore write target from `dis/statements` to `statements/statements`.

4. **`feed_controller.dart`**: Re-engineer to fetch each user's stream exactly once. For peers, pass `excludeTypes=org.nerdster.dis` so dis statements are excluded. For the active user, fetch the full stream (no exclusion) and split content and dis statements by type client-side. Remove the separate `disSource` channel.

5. **`CloudFunctionsSource` / `allStreams`**: Remove the `allStreams: ['statements', 'dis']` multi-stream revokeAt logic — no longer needed with a single stream.

6. **Testing**: Run existing tests as-is — they should all pass. This change must not alter any dis/rate behavior.

## Optimistic concurrency issues

- For the signed in user, we need dis and rate statements. We should fetch the entire stream, which will give us the head, no problem. We can write rate or dis statements to it and keep the head maintained correctly.
- For other users, we don't need the disses, and we won't be writing at all. We don't need the head; that said, it wouldn't hurt to have it. Or maybe use a read-only channel.

This is non-trivial. Here is the solution.

### The mixed-stream head problem

The naive implementation creates a `CachedSource<ContentStatement>` and a `CachedSource<DismissStatement>` for the same Firestore stream. Each instance tracks its own "head" — the token of the most-recently-seen statement of its type. After a dis statement is written, the content channel's cached head is stale (it still points to whatever content statement was last, not to the dis statement that just landed). The next content write uses that stale head as `previous`, and Firestore rejects it with an optimistic-locking failure.

### FilteredChannel architecture

The fix is one shared root per stream and lightweight typed facades over it.

**Root channel** — `CachedSource<Statement>` (one per domain/stream-key): fetches and caches all statement types together. Its `_fullCache[issuerToken]` always reflects the true linked list, and head tracking is always correct because every write goes through this single instance.

**`FilteredChannel<T>`** — a stateless facade:
- `fetch()` delegates to the root and filters the result with `whereType<T>()`, then applies `d.distinct()` within that type.
- `push()` delegates directly to the root. The root's push queue serializes all writes per issuer, so the head is always up to date regardless of which typed facade initiated the write.

`ChannelFactory.getChannel<T>(domain, stream)` looks up (or creates) the root and wraps it in a fresh `FilteredChannel<T>`. Multiple callers for the same stream all share the same underlying root.

### Distinct key collision

`distinct()` keeps only the latest statement per (issuer, subject) pair. With a mixed stream, a `ContentStatement` rating subject S and a `DismissStatement` dismissing subject S both produce the same key (`iToken:subjectToken`) — so one silently clobbers the other. The fix: prefix the key with the statement type.

- `ContentStatement.getDistinctSignature` → `content:iToken:subjects...`
- `DismissStatement.getDistinctSignature` → `dis:iToken:subjectToken`

This also matters on the server side. The CF's `makedistinct` function uses a subject-token-only key (no statement type) and iterates only over a hardcoded verb list that does not include `dismiss` — so DismissStatements were silently dropped when distinct was applied server-side. The root channel avoids this entirely by passing `distinct=false` to the CF. All distinct logic happens client-side in `FilteredChannel.fetch()`, where it is type-aware and correct.

The CF had a secondary bug: the boolean param `distinct=false` was passed as the string `'false'`, which is truthy in JavaScript. Fixed by checking `distinct && distinct !== 'false'`.


AI: TODO: Explain what is fetched from the server (CFs) to render the content stream on the Nerdster, specifically if we only fetch dismiss statements for some delegate keys while fetching the entire streams of content and dis statements for others/

The short answer is: we fetch full streams (content + dis) for everyone, and filter client-side. There is no per-key differentiation at the server.

`feed_controller.dart` creates two channels over the same stream:

- `contentSource = getChannel<ContentStatement>(kNerdsterDomain, 'statements')`
- `disSource   = getChannel<DismissStatement>  (kNerdsterDomain, 'statements')`

Both are `FilteredChannel<T>` facades over the **same** `CachedSource<Statement>` root (same domain + streamKey → same entry in `_rootChannels`). The root fetches all statement types from the CF for every delegate key it is asked about.

`contentSource.fetch(allDelegateKeys)` — called for every delegate of every trusted identity in the PoV graph — pulls the full mixed stream from the CF and the root caches it. `FilteredChannel<ContentStatement>` then applies `whereType<ContentStatement>()` locally; the peer's DismissStatements are fetched but silently discarded.

`disSource.fetch(myDelegateKeys)` — called only for the active user's own delegate keys — goes to the same root. If those keys were already in the root's cache from the content fetch, no CF call is made at all. The FilteredChannel then applies `whereType<DismissStatement>()` to extract only the active user's dis statements.

So the server always sees full-stream requests. The distinction between "only fetch dis for some keys" lives entirely client-side: `whereType` on the FilteredChannel determines which statement type each caller sees, and the shared root ensures no duplicate CF calls are made for keys that appear in both fetches.

## TAKE 2

The write-head problem only applies when the **same key is written through multiple channels**. Peer delegate keys are never written to. That is the unlock.

Split the delegate keys into two groups and give each group its own root:

**My delegate keys (signed-in user's delegates)**
- One root — full stream, no `excludeTypes`. Writable.
- `FilteredChannel<ContentStatement>` over this root gives content.
- `FilteredChannel<DismissStatement>` over this root gives dis.
- Both share the root, so head tracking is always correct for writes.

**Peer delegate keys (everyone else)**
- A separate root — passes `excludeTypes=['org.nerdster.dis']` to the CF. Read-only.
- `FilteredChannel<ContentStatement>` over this root gives content only.
- No dis statements are fetched or cached. No writes ever happen here, so a stale head is irrelevant.

**What changes**

`ChannelFactory`: include `excludeTypes` in the root cache key (e.g. `'$domain/$streamKey:excl=${excludeTypes.join(",")}'`). This naturally produces two separate roots for the same Firestore stream when called with different `excludeTypes` values. Writes always go through the root that was created without `excludeTypes` (my keys), so head tracking stays correct.

`feed_controller`: split `delegateKeysToFetch` into `myDelegateKeys` and `peerDelegateKeys`. Pass both sets to `ContentPipeline.fetchDelegateContent`, which takes two sources (`myDelegateSource`, `peerDelegateSource`) and routes each key set to the appropriate source internally. There is no merge step outside the pipeline.