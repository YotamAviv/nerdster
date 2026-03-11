# iPhone Bootstrap Mode

## Goal

Apple rejected the Nerdster because it shows a blank screen at launch and requires a
third-party app (ONE-OF-US.NET) to function. Bootstrap mode is a 4th sign-in option,
iOS-only, that lets a user try the Nerdster immediately — without installing or using
the ONE-OF-US.NET identity app — while making it clear this is a temporary onboarding
state that they can "graduate" out of later.

Once implemented, update the App Store submission notes to describe Bootstrap Quick Start
as the way to review/try the app without any other app.

## User Experience

### Sign-in dialog (iOS only)

A 4th button appears beneath the existing 3:

```
○  App Link          [Recommended]
○  URL scheme
○  QR Code
○  Bootstrap Quick Start
```

### What "Bootstrap Quick Start" does

1. Generates a fresh **identity key pair** (Ed25519) locally.
2. Generates a fresh **delegate key pair** (Ed25519) locally.
3. Persists a **bootstrap flag** in `flutter_secure_storage` ("I am in bootstrap mode").
4. Persists both key pairs in `flutter_secure_storage` (so they survive app restarts).
5. **Locally** injects a trust vouch: bootstrap identity → Yotam's hardcoded identity key.
   This vouch is never published to Firestore; it only affects the local trust graph.
6. **Locally** injects a delegate statement: bootstrap identity → bootstrap delegate key →
   `nerdster.org`. This is also never published to Firestore. Only the ONE-OF-US.NET phone
   app (which holds the real identity key) should sign and publish delegate statements.
   All content the bootstrap user creates (likes, follows, ratings) is signed by the
   bootstrap delegate key and published to the Nerdster's Firestore as usual.
7. Calls `signInState.signIn(bootstrapIdentityToken, bootstrapDelegateKeyPair)` — the app
   proceeds normally from this point.

### Key icon color (orange)

When in bootstrap mode, the top-right key icon should be **orange** — distinct from:
- Grey: not signed in
- Green: identity only (no delegate)
- Blue: identity + delegate (normal)

Orange = bootstrap identity + delegate (temporary / untrusted).

### Bootstrap explanation dialog

When the user taps the orange key icon, instead of (or before) the normal sign-in dialog,
show a **Bootstrap Explanation Dialog**:

---
> **You are using a bootstrap identity.**
>
> Your ratings, comments, and follows are signed with a delegate key that belongs to you.
> If you later graduate to your own identity, you can claim this delegate key and all your
> activity will remain valid.
>
> The content you see is from the project owner's network: you are viewing the Nerdster as
> if the only person you trust is the project owner, and through him, the people he has
> vouched for.
>
> **To use the Nerdster as yourself:**
> 1. Install the [ONE-OF-US.NET phone app](https://one-of-us.net).
> 2. Create your own identity key. Vouch for people you know and get vouched for.
> 3. On the SERVICES screen in the phone app, claim the delegate key you've been using —
>    all your ratings, follows, and comments will remain valid under your real identity.
> 4. Sign in to the Nerdster with your new identity ("App Link" or "URL scheme" above).
>    You will no longer automatically trust the developer — you'll trust whoever you've vouched for.

---

Buttons: **[Dismiss]** and **[Sign in with ONE-OF-US.NET app]** (opens the sign-in dialog).

## Key Technical Points

### Hardcoded identity key (Yotam's key)

```dart
const Json yotam = {
  "crv": "Ed25519",
  "kty": "OKP",
  "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
};
```

This key is hardcoded in `lib/bootstrap_sign_in.dart`. It is public-key-only — no secret.
The bootstrap identity locally vouches for Yotam, so the bootstrap user sees Yotam's network.

### Local trust injection — no changes to oneofus_common needed

All the relevant code is in **nerdster14**:

- `lib/logic/trust_pipeline.dart` — `TrustPipeline.build()` builds `statementsByIssuer`
  (a `Map<IdentityKey, List<TrustStatement>>`) before calling `reduceTrustGraph`.
- `lib/logic/trust_logic.dart` — `reduceTrustGraph(current, byIssuer, ...)` is a pure function.
- `lib/logic/labeler.dart` — `Labeler` wraps a `TrustGraph`.

**Injection point**: Before the fetch-reduce loop in `TrustPipeline.build()`, pre-populate
`statementsByIssuer` with a synthetic `TrustStatement` issued by the bootstrap identity key,
trusting Yotam's key. `reduceTrustGraph` will pick it up on its first iteration exactly as if
the statement had come from Firestore.

`TrustPipeline` needs a new optional parameter:

```dart
TrustPipeline(
  this.source, {
  this.localStatements = const {},   // <-- new: bootstrapIdentity → [synthTrustStatement]
  this.maxDegrees = 6,
  this.pathRequirement,
});
```

At the start of `build()`, merge `localStatements` into `statementsByIssuer` before the loop:

```dart
statementsByIssuer.addAll(localStatements);
```

The caller (`graph_controller.dart` or wherever `TrustPipeline` is constructed) passes in
the synthetic statement when bootstrap mode is active.

### Delegate statement is local-only

Bootstrap generates a delegate statement (bootstrap identity → bootstrap delegate →
`nerdster.org`) but **does not publish it to Firestore**. Only the real ONE-OF-US.NET
phone app — which holds the user's actual identity key — should sign and publish delegate
statements. Any old Nerdster code that writes to the ONE-OF-US.NET Firestore should not
be used here.

The delegate statement is injected locally via the same `TrustPipeline.localStatements`
mechanism as the trust vouch.

### Persistence across restarts

`KeyStore` already persists keys via `flutter_secure_storage`. Bootstrap mode adds:
- A boolean flag (`bootstrap_mode`) stored with `flutter_secure_storage`.
- Both the bootstrap identity **key pair** (public + private) and the delegate key pair are
  stored. `KeyStore` currently stores only the public identity key; bootstrap needs the
  private identity key too to reconstruct the local delegate statement on app restart.
- On app startup, if `bootstrap_mode` is set, skip the sign-in dialog, load the persisted
  keys, and re-enter bootstrap mode automatically.

### Exiting bootstrap mode

Normal sign-in (`signInUiHelper`) calls `KeyStore.wipeKeys()` and then stores the real keys.
Bootstrap exit also clears the `bootstrap_mode` flag. The orange icon returns to blue/green.

## Files Affected

### New
- `lib/bootstrap_sign_in.dart` — key generation, synthetic trust statement creation,
  bootstrap flag persistence, `bootstrapSignIn()` top-level function.
- `lib/ui/bootstrap_explanation_dialog.dart` — explanation + CTA dialog shown on orange key tap.

### Modified (nerdster14)
- `lib/ui/sign_in_widget.dart` — add "Bootstrap Quick Start" button (iOS-only guard via
  `defaultTargetPlatform == TargetPlatform.iOS`); orange icon when bootstrap flag is set.
- `lib/key_store.dart` — add `storeBootstrapFlag()`, `clearBootstrapFlag()`,
  `readBootstrapFlag()`. Also add optional storage of the private identity key pair
  (needed in bootstrap only; called differently from the public-key-only normal path).
- `lib/logic/trust_pipeline.dart` — add optional `localStatements` parameter to
  `TrustPipeline`; merge into `statementsByIssuer` before the loop.
- `lib/logic/graph_controller.dart` (or wherever `TrustPipeline` is constructed) — pass
  `localStatements` when bootstrap mode is active.
- `lib/app.dart` — on startup, check for bootstrap flag and auto-restore bootstrap mode.

## Testing on Chrome

The Bootstrap Quick Start button is iOS-only in the real app. To test it on Chrome,
append `?iphone=true` to the URL:

```
http://localhost:PORT/?fire=emulator&iphone=true
```
