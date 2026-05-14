# Key Federation — Phase 2: Making It Work

Goal: end-to-end demo where some trust-graph keys live at a foreign endpoint, and the
Nerdster BFS fetches their statements from that foreign URL rather than from
`export.one-of-us.net`.

---

## What Phase 1 already provides

- `FedKey` class + static registry populated automatically as trust statements are parsed.
- `TrustStatement.make()` always writes `endpoint` to the `with` clause.
- `FirebaseConfig.registerRedirect(prod, local)` — transparent emulator URL rewriting.
- `ChannelFactory` has `readAuthHook` support for per-domain auth.

What Phase 1 does NOT do: the BFS trust pipeline uses a **single**
`StatementSource<TrustStatement>` for all identity fetches, hardwired to
`export.one-of-us.net`. Every key in the graph is fetched from the same place.

---

## The core problem: single-source trust pipeline

`packages/nerdster_common/lib/trust_pipeline.dart`:

```dart
final newStatementsMap = await source.fetch(fetchMap);   // all keys, one URL
```

`source` is `channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements')`
registered in `main.dart` with `exportUrl: 'https://export.one-of-us.net'`.

Foreign keys land in `fetchMap` alongside native keys and get fetched from the wrong URL.

---

## Required changes

### 1. Trust pipeline — group by endpoint before fetching

Split the pending-key batch by endpoint URL, then call `source.fetch()` once per group.

```dart
// Pseudocode
Map<String, Map<String, String?>> byEndpoint = {};
for (final key in keysToFetch) {
  final url = FedKey.find(key)?.endpoint['url'] ?? kNativeUrl;
  byEndpoint.putIfAbsent(url, () => {})[key.value] = null;
}
for (final entry in byEndpoint.entries) {
  final source = sourceFor(entry.key);          // see §2
  final results = await source.fetch(entry.value);
  // merge results…
}
```

The bootstrapping order is safe: we learn a key's endpoint from the trust statement
that mentions it, and that statement is parsed before we queue the key for BFS expansion.

### 2. Dynamic source creation — `sourceFor(url)`

`ChannelFactory` routes by domain, not by URL. Foreign endpoints are unknown at startup.
Two options:

**Option A (simpler):** a small helper outside `ChannelFactory`:

```dart
final _sourcesCache = <String, CloudFunctionsSource<TrustStatement>>{};

CloudFunctionsSource<TrustStatement> sourceFor(String exportUrl) {
  return _sourcesCache.putIfAbsent(exportUrl, () =>
    CloudFunctionsSource<TrustStatement>(
      baseUrl: FirebaseConfig.resolveUrl(exportUrl),
      verifier: OouVerifier(),
      skipVerify: skipVerify,
    ));
}
```

**Option B:** extend `ChannelFactory.register()` to accept a list of extra export URLs and
cache sources for them. More architectural but adds complexity.

Option A is the right call for a demo.

### 3. `FirebaseConfig.resolveUrl` — register foreign redirects

In emulator mode, `main.dart` already calls:
```dart
FirebaseConfig.registerRedirect('https://export.one-of-us.net', 'http://127.0.0.1:5002/...');
```

Add a redirect for each foreign endpoint used in the demo:
```dart
FirebaseConfig.registerRedirect(
  'https://export.foreign-service.com',
  'http://127.0.0.1:5004/foreign-project/us-central1/export',
);
```

---

## The demo "foreign" service

For the demo we need a second trust-statement endpoint. The simplest option:

**Run a second oneofus emulator instance on different ports.**

The CF code is identical; only the Firebase project name and ports differ.
Port plan:

| Service              | Firestore | Functions | Export URL (emulator)            |
|----------------------|-----------|-----------|----------------------------------|
| one-of-us.net (native) | 8080    | 5002      | `http://127.0.0.1:5002/.../export` |
| foreign-service.com  | 8082      | 5004      | `http://127.0.0.1:5004/.../export` |

The second emulator can reuse the oneofus `firebase.json` / `functions/` directory with
a different project name and port overrides passed on the CLI.

---

## Demo data — foreign keys in the Simpsons scenario

In `simpsons_demo.dart`, designate some characters as "foreign":

```dart
// Before creating these keys, register them as foreign FedKeys.
// Then doTrust() will pick up the foreign endpoint automatically.
FedKey(foreignCharacter.publicKeyJson, {'url': 'https://export.foreign-service.com'});

await lisa.doTrust(TrustVerb.trust, foreignCharacter, moniker: 'Foreign Friend');
// → trust statement will carry endpoint: {"url": "https://export.foreign-service.com"}
```

The foreign character's own trust statements must be written to the second emulator
(not to the native one). This requires a second `channelFactory` registration or
writing directly to the second Firestore emulator.

The demo generator (`simpsons_demo_generator.dart`) already connects to two emulators
(nerdster + oneofus). Adding a third connection for the foreign emulator follows the same
pattern.

---

## CORS

The Nerdster web app (`localhost:8765`) will make XHR requests to the second emulator.
Firebase emulators accept all origins by default — no extra config needed for local demo.

For a deployed demo with a real second domain, the foreign CF export function needs:
```javascript
res.setHeader('Access-Control-Allow-Origin', 'https://nerdster.org');
```
The existing `export.js` already sets `res.setHeader('Access-Control-Allow-Origin', '*')`.
Nothing to add.

---

## Phone app / QR scanning

When a user displays their QR with the federated checkbox enabled, the payload is:
```json
{"key": <pubkey>, "url": "https://export.foreign-service.com"}
```

When the ONE-OF-US.NET phone app scans this, `FedKey.fromPayload()` already handles it.
The resulting trust statement carries the foreign endpoint. No phone app changes needed.

For the demo, the foreign character's QR can be generated by displaying
`FedKey(pubKey, {'url': 'https://export.foreign-service.com'}).toPayload()` as a QR.

---

## Summary of changes

| Area | Change | Effort |
|------|--------|--------|
| `trust_pipeline.dart` | Group BFS fetch by endpoint; call `sourceFor(url)` per group | Medium |
| `main.dart` (Nerdster) | Add `sourceFor()` helper + foreign redirect registration | Small |
| `simpsons_demo.dart` | Register some characters as foreign FedKeys before `doTrust()` | Small |
| `simpsons_demo_generator.dart` | Connect third emulator for foreign-service writes | Small |
| Second emulator | Start script + port config | Small |
| `ChannelFactory` / `oneofus_common` | No changes needed | — |
| Phone app | No changes needed | — |
| Cloud Functions | No changes needed | — |

The largest piece is the trust pipeline grouping (§1). Everything else is wiring.
