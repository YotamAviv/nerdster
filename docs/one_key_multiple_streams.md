# One Key, Multiple Streams

## Background

Each key in the oneofus system accumulates a notary chain: a linked list of signed
statements where each statement commits to the hash of its predecessor. This chain
ensures that no one can silently insert, reorder, or delete statements after the fact.

Currently each key holds exactly one such chain, stored at the Firestore path:

```
{keyToken}/statements/statements/{statementToken}
```

Nerdster has found a need for additional streams per key (e.g., dismiss statements in a
separate stream from content statements). This document generalizes that pattern.

## Problem Statement

When a key is compromised, a user can express that they want all of its statements revoked
up to a designated point in time. That point is identified by a **revokeAt token** — the
hash of a specific statement signed by that key. To apply it, the system must find that
statement to extract its timestamp, then exclude from all streams any statement whose time
is later than that timestamp.

With a single stream per key, the revokeAt token is always in that stream.
With multiple streams per key, the revokeAt token may be in **any** of them.

At the code level, this creates two problems:

1. **Path parameterization**: `DirectFirestoreSource` and `DirectFirestoreWriter` hardcode
   `'statements'` as the Firestore path segment. They need to accept which stream to operate
   on as a parameter.

2. **Cross-stream revocation**: The export API and `DirectFirestoreSource` currently look up
   the revokeAt token only in the stream being served. With multiple streams, the token may
   not be there, and the system incorrectly concludes the key is revoked since genesis.

## Terminology

| Term               | Meaning                                                                                                                      |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| **Key**            | A cryptographic keypair. Identified by its public key token (hash of the JWK).                                               |
| **Stream**         | An independent notary chain belonging to a key. Identified by a `streamId`.                                                  |
| **streamId**       | A short string naming a stream, e.g. `"statements"`, `"dis"`.                                                                |
| **revokeAt token** | A statement hash used to establish the revocation cutoff time for a key. May exist in any of the key's streams.              |
| **revokeAt time**  | The timestamp of the statement identified by the revokeAt token. Statements signed by that key after this time are excluded. |

## Firestore Layout

Each stream for a key lives at:

```
{keyToken}/{streamId}/statements/{statementToken}
```

The existing default stream uses `streamId = "statements"`, which maps to the legacy path
`{keyToken}/statements/statements` — no migration needed for existing data.

## Core Design

### Protocol

The export endpoint (`export.one-of-us.net`, `export.nerdster.org`) is a public API used
by third-party services, not just our Dart code. Any multi-stream revocation solution must
be expressible through this protocol. Our Dart implementation uses this protocol in the
same way any other client would.

The current `spec` format for revocation is:

```
spec={"keyToken": "revokeAtStatementToken"}
```

The server looks up `revokeAtStatementToken` in the stream's collection to get its time,
then filters to statements with `time ≤ that time`. With multiple streams per key, the
token might not be in the collection being served — lookup fails.

**The fix**: extend the spec value to carry the list of streams the server should search:

```json
{ "keyToken": { "revokeAt": "docId", "streams": ["statements", "dis"] } }
```

The server searches `streams` in order until it finds the token, then applies the time
cutoff. Third parties pass whatever streams they know about for that key.

The legacy string shorthand `{"keyToken": "docId"}` remains valid and is treated as
`streams: ["statements"]` — the single-stream default.

Note: the most common case is no revocation at all (`revokeAt` is absent). The server
special-cases this and performs no stream lookups.

**Performance**: server does 1–N extra Firestore point-reads per revoked key before the
main collection query. Point-reads by document ID are cheap. Revoked keys are rare.

The most common case is no revokeAt at all — the key has never been compromised and all
its statements are valid ("since always"). In the spec this key appears as a bare string
(`"keyToken"`) with no object wrapper and no revokeAt field. The server performs no stream
lookups for these keys.


### `StatementSource.fetch` — no interface change

The `fetch` signature stays as `Map<String, String?>` (token → revokeAt token or null).
Each implementation handles resolution in the way natural to its access path:

- `CloudFunctionsSource`: encodes `streams` in the spec and lets the server resolve.
- `DirectFirestoreSource`: resolves the token itself by searching `allStreams` (see below).

TODO: rename the parameter from `keys` to `token2revokeAt` for clarity, consistent with
the Cloud Function naming.

## API Changes

### `DirectFirestoreSource`

Add `streamId` and `allStreams` constructor parameters:

```dart
class DirectFirestoreSource<T extends Statement> implements StatementSource<T> {
  final String streamId;
  final List<String> allStreams;

  DirectFirestoreSource(this._fire, {
    this.streamId = 'statements',
    this.allStreams = const ['statements'],
    StatementVerifier? verifier,
    this.skipVerify,
  }) : verifier = verifier ?? OouVerifier();
```

The collection reference becomes:

```dart
final CollectionReference<Json> collectionRef =
    _fire.collection(token).doc(streamId).collection('statements');
```

For revokeAt resolution, search `allStreams` in order:

```dart
DateTime? limitTime;
if (limitToken != null) {
  for (final sid in allStreams) {
    final ref = _fire.collection(token).doc(sid).collection('statements');
    final doc = await ref.doc(limitToken).get();
    if (doc.exists && doc.data() != null) {
      limitTime = DateTime.parse(doc.data()!['time']);
      break;
    }
  }
  if (limitTime == null) {
    results[token] = []; // token not found in any stream → revoked since genesis
    return;
  }
}
```

### `DirectFirestoreWriter`

Add a `streamId` constructor parameter (default `"statements"`):

```dart
class DirectFirestoreWriter<T extends Statement> implements StatementWriter<T> {
  final String streamId;

  DirectFirestoreWriter(this._fire, {this.streamId = 'statements'});
```

The collection reference in `push` and `_writeOptimistic` becomes:

```dart
final CollectionReference<Map<String, dynamic>> fireStatements =
    _fire.collection(issuerToken).doc(streamId).collection('statements');
```

### `CloudFunctionsSource`

Gains `streamId` (maps to the server's `subcollection` param) and `allStreams` (the
streams list embedded in revokeAt spec objects):

```dart
CloudFunctionsSource<DismissStatement>(
  baseUrl: FirebaseConfig.contentUrl,
  verifier: OouVerifier(),
  streamId: 'dis',                    // → subcollection=dis/statements
  allStreams: ['statements', 'dis'],   // → included in revokeAt spec object
)
```

When building the spec, for any key with a revokeAt token, the source emits:

```json
{ "keyToken": { "revokeAt": "docId", "streams": ["statements", "dis"] } }
```

Keys without a revokeAt are still emitted as plain strings.

### Server: `statement_fetcher.js`

Handle both the legacy string format and the new object format:

```js
const revokeAtValue = token2revokeAt[token];
let revokeAtTime;

if (typeof revokeAtValue === 'string') {
  // Legacy: search current stream only
  // Triggered by a spec like:
  //   ?spec=[{"<token1>":"<token2>"}]
  // e.g.: ?spec=[{"<token1>":"<token2>"}]&subcollection=statements/statements
  const docSnap = await collectionRef.doc(revokeAtValue).get();
  revokeAtTime = docSnap.exists ? docSnap.data().time : null;
  if (!revokeAtTime) return [];

} else if (revokeAtValue?.revokeAt) {
  // New: search listed streams for the token
  // Triggered by a spec like:
  //   ?spec=[{"<token1>":{"revokeAt":"<token2>","streams":["<stream1>","<stream2>"]}}]
  // e.g. fetching the "dis" stream for a key, where the revokeAt token may be in either stream:
  //   ?spec=[{"<token1>":{"revokeAt":"<token2>","streams":["statements","dis"]}}]&subcollection=dis/statements
  const streams = revokeAtValue.streams ?? ['statements'];
  for (const streamId of streams) {
    const slashIdx = streamId.indexOf('/');
    const doc = slashIdx >= 0 ? streamId.slice(0, slashIdx) : streamId;
    const col = slashIdx >= 0 ? streamId.slice(slashIdx + 1) : 'statements';
    const ref = db.collection(token).doc(doc).collection(col);
    const snap = await ref.doc(revokeAtValue.revokeAt).get();
    if (snap.exists) { revokeAtTime = snap.data().time; break; }
  }
  if (!revokeAtTime) return [];
}

if (revokeAtTime) {
  query = query.where('time', '<=', revokeAtTime);
}
```

Update `openapi.yaml` to document the new spec value format.

### `SourceFactory` (Nerdster-specific)

```dart
static StatementSource<ContentStatement> forContent() {
  if (fireChoice == FireChoice.fake) {
    return DirectFirestoreSource<ContentStatement>(
      FireFactory.find(kNerdsterDomain),
      streamId: 'statements',
      allStreams: ['statements', 'dis'],
      skipVerify: Setting.get<bool>(SettingType.skipVerify),
    );
  }
  return CloudFunctionsSource<ContentStatement>(
    baseUrl: FirebaseConfig.contentUrl,
    verifier: OouVerifier(),
    streamId: 'statements',
    allStreams: ['statements', 'dis'],
    skipVerify: Setting.get<bool>(SettingType.skipVerify),
  );
}

static StatementSource<DismissStatement> forDis() {
  if (fireChoice == FireChoice.fake) {
    return DirectFirestoreSource<DismissStatement>(
      FireFactory.find(kNerdsterDomain),
      streamId: 'dis',
      allStreams: ['statements', 'dis'],
      skipVerify: Setting.get<bool>(SettingType.skipVerify),
    );
  }
  return CloudFunctionsSource<DismissStatement>(
    baseUrl: FirebaseConfig.contentUrl,
    verifier: OouVerifier(),
    streamId: 'dis',
    allStreams: ['statements', 'dis'],
    skipVerify: Setting.get<bool>(SettingType.skipVerify),
  );
}
```

## Tests

The following tests should be added to `oneofus_common/test/` using `FakeFirebaseFirestore`.

### 1. Independent writes

```
write C1 to stream "statements"
write D1 to stream "dis"
fetch "statements" → [C1]
fetch "dis" → [D1]
```

### 2. Cross-stream isolation

```
write C1 to "statements"
fetch "dis" → []
```

### 3. revokeAt within the same stream

```
write C1, C2 to "statements"  (C2 newer, C2.previous = C1)
fetch "statements" with revokeAt=C1.token, allStreams=["statements"] → [C1]
// C2 excluded
```

### 4. revokeAt token in a different stream

```
write C1, C2 to "statements"  (time(C1) < time(C2))
write D1 to "dis"              (time(C1) < time(D1) < time(C2))
fetch "statements" with revokeAt=D1.token, allStreams=["statements","dis"] → [C1]
// server/source finds D1 in "dis", uses time(D1) as cutoff → C2 excluded
fetch "dis" with revokeAt=D1.token, allStreams=["statements","dis"] → [D1]
// D1 is at the cutoff, included
```

### 5. revokeAt token not found in any stream

```
fetch with revokeAt="<unknown>", allStreams=["statements","dis"] → []
```

### 6. Backward compatibility — source

```
DirectFirestoreSource (no streamId, no allStreams) → reads from "statements", identical to current behavior
```

### 7. Backward compatibility — writer

```
DirectFirestoreWriter (no streamId) → writes to "statements", identical to current behavior
```

## Upgrade Path

### oneofus_common

- Add `streamId` and `allStreams` parameters to `DirectFirestoreSource` (both default to
  `['statements']` — no breaking change).
- Add `streamId` and `allStreams` parameters to `CloudFunctionsSource`.
- Add `streamId` parameter to `DirectFirestoreWriter` (defaults to `'statements'`).
- Update `DirectFirestoreSource` revokeAt resolution to search `allStreams`.
- Add tests above to `oneofus_common/test/`.

### Nerdster

- Update `SourceFactory.forContent()` to pass `allStreams: ['statements', 'dis']`.
- Add `SourceFactory.forDis()`.
- Update server `statement_fetcher.js` to support the new object spec format.
- Update `openapi.yaml`.

### ONE-OF-US.NET

- No immediate change needed. Trust pipeline uses the default `streamId = "statements"`
  with `allStreams = ['statements']` — identical to current behavior.
- If/when ONE-OF-US.NET adds a second stream, it sets `allStreams` accordingly.

### hablotengo

- Same as ONE-OF-US.NET.

## Open Questions

- Should dis statements carry a `"statement": "org.nerdster.dis"` type field? This would
  allow the export function to filter by type. Currently deferred.

---

## Appendix: Rejected Option — Client Pre-resolves revokeAt to a Time

An alternative design was considered and rejected: instead of passing the revokeAt token
to the server (or resolving it within `DirectFirestoreSource`), the client resolves the
token to a timestamp first and passes the timestamp directly.

**Spec format:**
```json
{ "keyToken": { "revokeAtTime": "2024-01-15T10:30:00.000Z" } }
```

**`StatementSource.fetch` signature change:**
```dart
// Was:
Future<Map<String, List<T>>> fetch(Map<String, String?> token2revokeAt);
// Would become:
Future<Map<String, List<T>>> fetch(Map<String, DateTime?> token2revokeAtTime);
```

**Why rejected**: This makes `StatementSource` simpler but pushes complexity to all
callers, requires a separate `StatementTokenResolver` abstraction, and changes the
interface in a breaking way for ONE-OF-US.NET and hablotengo. Most importantly, it is
not usable by third-party HTTP clients that lack direct Firestore access. Option A
(server-side resolution with `streams` list) solves the problem at the protocol level
and is accessible to all clients.
