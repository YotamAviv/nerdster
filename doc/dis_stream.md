
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
