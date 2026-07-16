# Pass the Intention — Nerdster → Identity App Handoff

## What

The Nerdster never holds a private **identity** key. So any identity-layer action —
signing in, or blocking/clearing another key — must be carried out by the user's
**identity app** (today: the ONE-OF-US.NET phone app), which does hold the key.

The Nerdster's job is only to hand the *intention* to that app: "here is a key, please
sign a `block`/`clear` statement about it" (or, for sign-in, "here are the session
parameters"). This document is about the **mechanics of that handoff** — how the bits
travel from the Nerdster to the identity app. It is not about *when* or *why* to block;
that's `block_identity.md`.

Sign-in and block/clear are the **same handoff problem**, and they must stay symmetric.

---

## The three transports

There are exactly three ways to get data from the Nerdster to the identity app. The user
picks one at sign-in time (see the sign-in dialog: `nerdster_common/lib/ui/sign_in_dialog.dart`):

| Transport | Link / mechanism | When it works |
|---|---|---|
| **Universal link** | `https://one-of-us.net/<verb>#<payload>` | Identity app is on **this same device**; the OS routes the https link to the app. The current default. |
| **Custom scheme** | `keymeid://<verb>#<payload>` | Identity app is on **this same device**. Kept deliberately (see "keymeid" below). |
| **QR code** | QR encodes the payload | Identity app is on a **different device** and scans it (e.g. desktop Nerdster ↔ phone app). |

For sign-in the `<payload>` is the session parameters; for block/clear the link payload is the
target identity's public-key JSON, base64url-encoded in the `#fragment`.

For block/clear specifically:
- **Same-device (universalLink / keymeid):** the magic link is launched **directly** — no
  intermediate dialog. The user already confirmed the harshness warning; a one-option dialog
  on top of that is just friction.
- **Different-device (qrScan):** the QR carries the **target key only**, not the action. The
  ONE-OF-US in-app scanner validates a scanned payload as JSON (a key), and takes the verb
  from the block/clear button the user taps in that app — it does **not** parse a scanned
  action URL. (A `https://one-of-us.net/block#…` universal link *is* handled by the app when
  **tapped or opened via the native camera**, but not by the app's own in-app scanner, so we
  don't put the verb in the QR. Carrying the action in the QR would need an app-side change to
  the in-app scanner.)

### keymeid

`keymeid://` is kept first-class alongside `https://one-of-us.net/`. The whole paradigm is
that identity is **not owned by one-of-us.net** — one-of-us.net is just today's default
identity app. Any `keymeid`-associated app can service the scheme. Do not collapse it into
the one-of-us.net path.

---

## The rule: record how you signed in, then reuse it

The user chose a transport at sign-in that demonstrably works on their setup. So:

1. **At sign-in**, record which transport the user actually used as a `SignInMethod`
   (`lib/sign_in_state.dart`).
2. **Persist it** across reloads (`lib/key_store.dart`), because the normal flow is
   "Store keys" → app boots and loads keys (and the method) from storage.
3. **At block/clear time**, read that same method back and rebuild the matching transport.
   Do **not** guess from platform; reuse what already worked.

### Method → block/clear handoff

| `SignInMethod` | Block / Clear offered? | Transport reused |
|---|---|---|
| `oneOfUsNet` | yes | `https://one-of-us.net/<verb>#<payload>` |
| `keymeid` | yes | `keymeid://<verb>#<payload>` |
| `qrScan` | yes | QR code |
| `paste` | no | (paste is a hidden debug-only sign-in; not a real transport) |
| `null` | **no** | none — see below |

Only **block** and **clear** are gated this way; they are the actions that transmit to the
identity app. **Trust** is not — clicking trust only shows an explainer ("vouch in person,
not because of Nerdster content"); it transmits nothing and is never gated by the method.

### `null` means "we don't know if or how you signed in"

`null` is a **meaningful, deliberate state**, not an accident: no identity-app transport is
known, so we cannot construct a block/clear handoff. When the method is `null`, **do not show
the block/clear buttons** in NodeDetails. We don't guess.

In practice, once transport-recording is wired correctly, `null` only arises for:
- **legacy stored keys** saved before sign-in-method persistence existed, and
- sessions that never signed in as an identity at all (e.g. arriving via `?pov=`, which sets
  a point of view but establishes no identity — so `canAct` is already false and the block
  dialog never opens anyway).

There is intentionally **no platform-based fallback** (the old "mobile → one-of-us.net,
desktop → QR" heuristic). Known method → its transport; unknown → no button.

---

## Why this was broken

The `SignInMethod` enum and its persistence existed, but the sign-in dialog's three buttons
all completed through a single `onData` callback that carried no transport, so every sign-in
was stamped `qrScan` regardless of which button was pressed — `oneOfUsNet` and `keymeid` were
never assigned anywhere. Block/clear then faithfully reused the wrong (or, on mobile before
persistence, a `null`-fallback) transport, showing a useless same-device QR. The fix is to
thread the real transport from each sign-in entry point through `onData` so the method is
recorded and persisted truthfully.

---

## TODO / known limitations — desktop (qrScan) block & clear

Two related gaps, both rooted in the desktop QR carrying only the key, not the action:

1. **Blocking a specific key from the desktop is hard to transmit to the phone.** The QR holds
   only the target key JSON. The ONE-OF-US in-app scanner takes the *verb* from which button
   the user taps (Block / Vouch / …), not from the QR — so the desktop can't say "block THIS
   key" precisely; the user scans the key and blocks it manually in the app.

2. **Clearing a block from the desktop can't be guided by name.** Blocked keys have no moniker
   in the identity app — they render as "Unknown" (only vouches, on the People screen, are
   named). So the clear dialog's "Find your block for '<name>'…" names a key the phone shows
   as "Unknown". (Clearing a *vouch* by name works, and is left as-is.) Users can't easily see
   their blocked keys anyway, so this is left as-is for now.

**Fix for both — put the intention (verb) in the QR.** A camera-scannable action-URL QR
(`https://one-of-us.net/block#<key>` / `/clear#<key>`) would carry key AND action; the phone's
OS routes the universal link to the app's handler (`_handleIncomingLink` → `_handleKeyFragment`
in oneofus), landing on the exact key — no manual scan, no name needed. This works via the
phone **camera** (universal-link routing), NOT the app's in-app scanner (which only parses
JSON), so the instruction would read "scan with your phone camera." Deferred.

---

## Related docs

- `block_identity.md` — semantics of blocking (when/why), not this handoff mechanism.
- `phone_app_plan.md` — sign-in-side handoff rationale (same-device vs cross-device QR).
- `deep_links.md`, `android_app_links.md` — universal/app-link and custom-scheme mechanics.
