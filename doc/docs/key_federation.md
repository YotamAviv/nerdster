# Key Federation

## Overview

The ONE-OF-US.NET network currently hardcodes `export.one-of-us.net` as the source for all
trust statements. Key Federation is a design extension that allows identity keys to be
**federated** with other organizations — meaning their trust statements are published to and
fetched from a different endpoint.

The ONE-OF-US.NET phone app itself will always publish to `export.one-of-us.net`. The goal of
this work is to define a protocol that allows third-party organizations to build their own
compatible apps and infrastructure, so that ONE-OF-US.NET account holders can
- vouch for people whose keys are federated elsewhere
- be vouched for by people whose keys are federated elsewhere
- replace their key with a key federated elsewhere

---

## Terminology

- **Endpoint**: the JSON object describing where a key's trust statements are published.
  For ONE-OF-US.NET native keys: `{"url": "https://export.one-of-us.net"}`.
  Third-party keys may carry additional fields, e.g. `{"url": "...", "version": 1}`.
- **FedKey**: an identity key paired with its endpoint. The only required field in the
  endpoint is `"url"`. Any additional fields are preserved as-is.
- **Native key**: a key whose endpoint URL is `https://export.one-of-us.net`.

---

## Protocol Design

### Vouch statements carry the endpoint

The `endpoint` field is added to the `with` clause of trust (vouch) statements.

Vouch statement `with` clause fields:

| Field      | Required | Description |
|------------|----------|-------------|
| `moniker`  | Yes      | Human-readable name for the vouched key |
| `endpoint` | No       | Endpoint object for the vouched key. Absence defaults to `{"url": "https://export.one-of-us.net"}`. |
| `comment`  | No       | Free-text note about why this person is being vouched for |
| `revokeAt` | No       | ISO timestamp after which this vouch expires |

Example:

```json
{
  "trust": <their public key>,
  "with": {
    "moniker": "Alice",
    "endpoint": {"url": "https://export.one-of-us.net"},
    "comment": "Met at RustConf 2024",
    "revokeAt": "2027-01-01T00:00:00Z"
  }
}
```

**Backward compatibility:** Existing statements without an `endpoint` field
default to `{"url": "https://export.one-of-us.net"}`. Existing statements with the
old `home: "export.one-of-us.net"` string format (none exist yet in the wild) would
be parsed as no endpoint and likewise default. Migration is both unnecessary and
impossible: existing statements are signed by private keys we don't hold.

### QR codes and invitation links carry the endpoint

When a key owner displays their QR code or generates an invitation link, the payload
includes their endpoint object alongside the public key:

```json
{
  "key": <public key>,
  "url": "https://export.one-of-us.net"
}
```

**Backward compatibility:** Existing QR codes and invitation links that contain just a
bare public key JSON (`{"crv":...,"kty":"OKP","x":...}`) are treated as native
(`export.one-of-us.net`). `FedKey.fromPayload()` handles both formats.

Examples:
- old invitation links in people's emails
- old QR codes distributed in a variety of ways

### vouch.html

`nerdster14/web/vouch.html` is **protocol-agnostic** — it decodes whatever base64 JSON
the URL hash contains, renders it as a QR code, and puts the raw JSON in the copy-paste
textarea. It handles both old (bare key) and new (`{key, url, ...}`) payloads without
any changes. **No update needed.**

### Each organization operates its own infrastructure

The ONE-OF-US.NET phone app publishes to `export.one-of-us.net`. Third-party organizations
build and operate their own apps and backends. There is no requirement that third parties
use our API design — the protocol for how a service stores and serves statements is up to each
organization. Our own implementation is documented in
[`openapi.yaml`](../../nerdster14/functions/openapi.yaml), served live at
[`export.one-of-us.net/openapi.yaml`](https://export.one-of-us.net/openapi.yaml).

### Key replacement across endpoints

Key replacement uses the existing `replace` statement: the **new key** signs a statement
claiming the old key. Under Key Federation, the two keys may have different endpoints.
No new protocol is needed — the `replace` statement is unchanged. The only requirement is
that the trust pipeline can fetch statements from the old key's foreign endpoint, which is
part of Full Federation Support.

---

## Backward Compatibility

### QR code format

The current QR code contains just the raw public key JSON (`{"crv":...,"kty":...,"x":...}`).
Changing it to a wrapped object `{"key":..., "url":...}` is a **breaking format change**:
an old app scanning a new-format QR will fail to parse it as a key.

The breaking change only occurs when the app **shows** a QR code or **sends** an invitation
in the new format. Scanning/parsing the new format is always safe to ship first.

Rollout plan:
- **Phase 1:** Ship a new app version that can scan both old and new formats, but still
  shows the old bare-key format. No user impact. A checkbox on the Advanced screen
  (default off) enables showing the new wrapped format.
- **Phase 2:** Ship a follow-up version that always shows the new wrapped format. Only
  safe once virtually all users are on Phase 1 or later.

**Vouch statements are unaffected.** Adding `endpoint` to vouch `with` clauses is purely
additive — existing signed statements default to the native endpoint and remain valid
indefinitely. No version adoption concern there.

---

## Implementation — Phase 1 *(complete as of 2026-03-23)*

**Phase 1 is complete.** All items below have shipped. The only remaining gate to Phase 2
is flipping the federated QR/invitation checkbox default from *off* to *on*.

---

### `oneofus_common` *(changes applied to both repo copies)*

- [x] **`FedKey` class** (`keys.dart`): `(pubKeyJson: Json, endpoint: Map<String, dynamic>)` pair.
  - Static registry `Map<IdentityKey, FedKey>`; `FedKey.find(IdentityKey) → FedKey?`.
  - `FedKey.fromPayload(json)`: parses old (bare key) and new (`{key, url, ...}`) formats;
    defaults to `kNativeEndpoint` when endpoint absent.
  - Constructor auto-registers in registry.
  - `IdentityKey get identityKey` — typed getter (no raw `token` string getter).
  - `bool get isNative` — true when `endpoint['url'] == kNativeUrl`.

- [x] **`TrustStatement` changes**:
  - `final Map<String, dynamic>? endpoint` field, parsed from `with.endpoint`.
  - In factory constructor: registers `FedKey(subject, endpoint ?? kNativeEndpoint)` for
    `trust` and `replace` statements.
  - In `make()`: always writes `endpoint` to `with` clause for `trust` and `replace` verbs,
    defaulting to `kNativeEndpoint`. Not added for `block`, `clear`, `delegate`.

- [x] **`Jsonish.keysInOrder` / JS `key2order` sync**: `'endpoint'` at position 25
  (between `stars` and `comment`) in both the Dart list and
  `functions/jsonish_util.js`. Both files carry a ⚠️ CRITICAL sync comment.

---

### ONE-OF-US.NET phone app

- [x] **Vouch / replace creation** (`app_shell.dart`): passes `fedKey.endpoint` to
  `TrustStatement.make()`. Endpoint flows in from the scanned `FedKey`.

- [x] **Sign-in payload** (`sign_in_service.dart`): sends
  `FedKey(identityPubKeyJson).toPayload()` = `{key, url, ...}` as the `identity` field.
  Old Nerdster installations handle bare-key payloads via `FedKey.fromPayload()`.

- [x] **Advanced screen checkbox**: "Federated identity QR / invitations" — default off.
  Gates the two items below.

- [x] **QR code format** (`card_screen.dart`): when checkbox on, encodes
  `FedKey(myPubKeyJson).toPayload()` as QR content.

- [x] **Invitation link format** (`share_service.dart`): when checkbox on, base64-encodes
  `FedKey(myPubKeyJson).toPayload()` in the link / `vouch.html` URL.

- [x] **`Config.resolveUrl(url)`** (`config.dart`): translates a prod URL to the correct
  local endpoint in emulator mode. Phase 2 code calls this instead of accessing
  `endpoint['url']` directly.

- [x] **`vouch.html`** (`web/vouch.html`): no changes needed; protocol-agnostic.

---

### Nerdster

- [x] **Sign-in handler**: parses `identity` field using `FedKey.fromPayload()` in both
  `sign_in_session.dart` and `paste_sign_in.dart` — accepts both old (bare key JSON) and
  new (`{key, url, ...}`) formats. Missing endpoint defaults to `kNativeEndpoint`.

- [x] **`KeyStore`**: stores and retrieves the endpoint JSON alongside the identity public key.
  Old sessions (no endpoint stored) default to `kNativeEndpoint`.

- [x] **`main.dart`**: reads the stored endpoint from `KeyStore` on startup and initializes
  `FedKey(identityJson, endpoint)` so `SourceFactory.forIdentity()` can resolve the URL.

- [x] **`SourceFactory.forIdentity(IdentityKey)`** (`source_factory.dart`): looks up the
  `FedKey` for the given identity and uses `endpoint['url']` to construct the source URL.
  Falls back to `kNativeUrl` if no `FedKey` registered.

- [x] **`FirebaseConfig.resolveUrl(url)`** (`config.dart`): in emulator mode, redirects
  `https://export.one-of-us.net` → local emulator URL transparently.

---

## Pre-Production Test Plan

Run these tests before pushing either app to production. Emulator is preferred.

### Automated (already passing)

- [x] Nerdster: `bash bin/run_all_tests.sh` — 9/9 suites (backend, Flutter unit,
  oneofus_common, Chrome ×3, Android ×3)
- [x] Phone app: `flutter test packages/oneofus_common/test/` — 15/15 unit tests
- [x] Phone app: `flutter test integration_test/ -d <emulator>` (with `fireChoice=emulator`)
  — federated_qr_test, people_screen_test, bidirectional_trust_test all pass

### Manual — Backward compatibility (phone app + Nerdster)

These verify that **old app versions** and **old QR codes / invitations** still work.

**M1. Old bare-key QR code scanned by new phone app**
- Use a photo/printout of an old QR code (bare key, no endpoint).
- Scan with updated ONE-OF-US.NET app → should sign in / vouch normally.
- Verify in Nerdster with `&showCrypto=true`: trust statement `"with"` should include
  `"endpoint": {"url": "https://export.one-of-us.net"}`.

**M2. Old invitation link opened by new phone app**
- Use an old `vouch.html#<base64-bare-key>` link.
- Open on phone with updated app → app should deep-link and parse correctly.

**M3. New phone app → sign in to updated Nerdster (via phone-to-Nerdster flow)**
- On the phone app (emulator), generate credentials via the "magic paste" / sign-in flow.
- Paste into the Nerdster running on Linux (emulator mode).
- Verify sign-in succeeds and feed loads.

**M4. Old phone app → sign in to updated Nerdster**
- Use an older installed phone app to generate credentials.
- Paste into the updated Nerdster.
- Verify sign-in succeeds (identity payload is bare key — Nerdster must accept via `FedKey.fromPayload`).

**M5. Trust statement round-trip**
- Sign in to the phone app (emulator). Trust another user.
- In the Nerdster with `&showCrypto=true`: verify the trust statement `"with"` has
  `"endpoint": {"url": "https://export.one-of-us.net"}` (not `"home": "..."`).
- Verify the trust graph loads the trusted user correctly.

**M6. Federated QR checkbox (phone app)**
- Go to Advanced screen → toggle "federated QR" on.
- Verify QR changes from bare key to `{"key": ..., "url": "https://export.one-of-us.net"}`.
- Toggle off → verify QR reverts to bare key.
- (This is also covered by `federated_qr_test`, but worth a manual smoke check.)

**M7. vouch.html with old and new links**
- Open `vouch.html#<base64-bare-key>` → QR renders, copy text is bare key JSON.
- Open `vouch.html#<base64-{key,url}>` → QR renders, copy text is the full payload.
- Both should work identically from the user's perspective.

---

## Phase 2

Phase 2 has two distinct pieces:

### 2a. Federated QR / invitation format flip *(one-line change)*

Remove the Advanced screen checkbox (or flip its default to `true`). This is the only gate
remaining. Safe to ship once pre-Phase-1 installs drop to negligible levels.

### 2b. Full federation — trust pipeline uses per-key endpoint

Currently `SourceFactory.forIdentity()` uses the registered `FedKey` endpoint for the
signed-in user, but the BFS trust pipeline still uses the same URL for all identity fetches.
For real federation, each key in the graph must be fetched from its own endpoint.

**Changes needed:**

- **`source_factory.dart`**: use `FedKey.find(token)?.endpoint['url'] ?? kNativeUrl` per token,
  piped through `FirebaseConfig.resolveUrl()`.
- **`key_info_view.dart`**: build the statement browser URL from the per-key endpoint
  instead of always `export.one-of-us.net`.
- **`FedKey` registry population**: already handled — FedKeys are registered when trust
  statements are parsed, covering all keys in the vouch graph.

`FirebaseConfig.resolveUrl` is already in place for transparent emulator handling.

---

## Export API Documentation *(done)*

- [x] **ONE-OF-US.NET export API** documented as OpenAPI 3.1 in
  [`openapi.yaml`](../../nerdster14/functions/openapi.yaml), served live at
  [`export.one-of-us.net/openapi.yaml`](https://export.one-of-us.net/openapi.yaml).

---

## Full Federation Support *(UNLIKELY ANYTIME SOON)*

- [ ] Trust pipeline fetches each key from its own endpoint.
- [ ] Sign-in with foreign-federated key (requires delegate statement fetch from foreign endpoint).
