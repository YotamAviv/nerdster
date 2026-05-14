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
Three options:

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

**Option C (pre-registered allowlist):** pre-register known foreign domains in `main.dart` at
startup, alongside `one-of-us.net`. Assumes all endpoints follow the `https://export.${domain}`
convention. In `trust_pipeline.dart`, look up the key's domain from `FedKey` and call the
existing `channelFactory.getChannel<TrustStatement>(domain, 'statements')` — no new helper needed.
Keys whose domain is not registered are skipped.

```dart
// main.dart — register foreign domain at startup
channelFactory.register(
  domain: 'karennet.net',
  exportUrl: 'https://export.karennet.net',
);

// trust_pipeline.dart — derive domain from FedKey endpoint URL, fall back to native
final endpointUrl = FedKey.find(key)?.endpoint['url'] ?? kNativeUrl;
final domain = Uri.parse(endpointUrl).host.replaceFirst('export.', '');
final source = channelFactory.getChannel<TrustStatement>(domain, 'statements');
```

Tradeoff: Nerdster becomes an explicit allowlist — it only follows trust chains into domains
it knows about. This is arguably a security feature. No dynamic source creation needed.

Option A is the right call for a fully dynamic demo; Option C is cleaner if the set of
trusted foreign domains is known at build time.

### 3. `FirebaseConfig.resolveUrl` — register foreign redirects

In emulator mode, `main.dart` already calls:
```dart
FirebaseConfig.registerRedirect('https://export.one-of-us.net', 'http://127.0.0.1:5002/...');
```

Add a redirect for each foreign endpoint used in the demo:
```dart
FirebaseConfig.registerRedirect(
  'https://export.karennet.net',
  'http://127.0.0.1:5004/karennet/us-central1/export',
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
| karennet.net  | 8082      | 5004      | `http://127.0.0.1:5004/.../export` |

The second emulator can reuse the oneofus `firebase.json` / `functions/` directory with
a different project name and port overrides passed on the CLI.

---

## Demo data — foreign keys in the Simpsons scenario

Example: Marge and Luanne are foreign (their trust statements live on `karennet.net`).

### Changes required

**`demo_key.dart`** — `_signAndPush` hardcodes `kOneofusDomain`. Add an optional `trustDomain`
field to `DemoIdentityKey` (defaulting to `kOneofusDomain`) and use it:
```dart
channelFactory.getChannel<TrustStatement>(trustDomain, 'statements')
```

**`simpsons_demo.dart`** — two things for Marge and Luanne:
1. Register them as `FedKey`s with the foreign endpoint — so trust statements *about* them
   carry the right endpoint (already handled by `TrustStatement.make()` looking up `FedKey`)
2. Create them with `trustDomain: kForeignDomain` — so their own trust statements are written
   to the foreign channel

**`simpsons_demo_generator.dart`** — add a third `channelFactory.register()` for the foreign
domain, same pattern as the existing nerdster + oneofus registrations. Writes go via HTTP POST
(crypto-signed, no Firebase credentials needed).

No changes to `ChannelFactory`, Cloud Functions, or the phone app.

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
{"key": <pubkey>, "url": "https://export.karennet.net"}
```

When the ONE-OF-US.NET phone app scans this, `FedKey.fromPayload()` already handles it.
The resulting trust statement carries the foreign endpoint. No phone app changes needed.

For the demo, the foreign character's QR can be generated by displaying
`FedKey(pubKey, {'url': 'https://export.karennet.net'}).toPayload()` as a QR.

---

## Deployed (real web) demo — gaps not yet addressed

The demo sections above describe a local emulator setup only. For a demo running on the real
web, the following are not yet covered:

1. **Foreign service needs to be deployed** — a real second Firebase project with CF deployed,
   not an emulator. Which project, how to deploy it, and what URL it would have are TBD.

2. **Demo data must be written to the foreign service** — `simpsons_demo_generator` writes via
   HTTP POST to Cloud Functions (crypto-signed statements, no Firebase credentials needed).
   A third `channelFactory.register()` with the foreign domain's `functionsUrl` is all that's
   required — same pattern as the existing nerdster + oneofus registrations.

3. **Nerdster deployment** — how to run or deploy Nerdster with the foreign domain
   pre-registered (Option C) or with the `sourceFor()` helper (Option A) pointing to real
   endpoints is not yet addressed.

CORS is already handled — deployed CFs set `Access-Control-Allow-Origin: *`.

---

## Summary of changes

| Area | Change | Effort |
|------|--------|--------|
| `trust_pipeline.dart` | Group BFS fetch by endpoint; call per-domain channel | Medium |
| `main.dart` (Nerdster) | Register foreign domain + emulator redirect (Option A: add `sourceFor()`) | Small |
| `demo_key.dart` | Add `trustDomain` field to `DemoIdentityKey`; use in `_signAndPush` | Small |
| `simpsons_demo.dart` | Register Marge/Luanne as `FedKey`s; create with `trustDomain` | Small |
| `simpsons_demo_generator.dart` | Add third `channelFactory.register()` for foreign domain | Small |
| Second emulator | Start script + port config | Small |
| `ChannelFactory` / `oneofus_common` | No changes needed | — |
| Phone app | No changes needed | — |
| Cloud Functions | No changes needed | — |

The largest piece is the trust pipeline grouping (§1). Everything else is wiring.
