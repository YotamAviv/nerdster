# App Store Compliance Plan

## Current state

- `lib/about.dart` has links to Privacy Policy, Terms, Report Abuse (`abuse@nerdster.org`).
  - Currently links to `nerdster.org/policy.html` and `nerdster.org/terms.html`.
  - Those pages are shared with ONE-OF-US.NET (same `web/` folder deployed by both `bin/stage_*.sh`).
  - Pages still have ONE-OF-US.NET branding — needs resolution (see below).
- ONE-OF-US.NET passed Apple Beta App Review with its about page linking to its own terms/policy/abuse.
- Nerdster (iosmagic branch) has NOT passed Apple Beta App Review.
  - Apple rejected on "no moderation." ONE-OF-US.NET's model was accepted.

---

## Your understanding (confirmed correct)

- Apple/Google Play require some moderation mechanism for apps with UGC.
- **Web app**: cannot be forced to add centralized censorship — it's not a store app.
- **Native apps (iOS/Android)**: may need centralized censorship to satisfy stores.
  - Existing per-user tools (block via ONE-OF-US.NET, follow -1, censor checkbox) are decentralized and likely insufficient for store policy on their own.
  - The `abuse@nerdster.org` email in the About dialog is a lightweight mechanism — may be enough to argue to Apple/Google that there is a reporting path, similar to ONE-OF-US.NET's `abuse@one-of-us.net`.

---

## Open decisions

### 1. Centralized censorship for native apps
- **Option A**: Argue purely decentralized (trust graph IS the moderation). Point to ONE-OF-US.NET precedent. Try Beta App Review with the current abuse email link.
- **Option B**: Implement a Firestore-backed `global_blocked` list. The native app checks it. Web app ignores it. Minimal: admin-only writes, no UI required initially.
- **Option C**: Defer — keep on internal testers only until you decide.

### 2. Terms / Privacy / Abuse pages
Native apps need their own pages, separate from ONE-OF-US.NET. Options:

- **A (simple)**: Create `web/nerdster_terms.html` and `web/nerdster_policy.html`. Update `bin/stage_nerdster.sh` to copy them over `terms.html` / `policy.html` at build time (same pattern as `nerdster_man.html` → `man.html`). About page links stay as `nerdster.org/terms.html`.
- **B (decouple web)**: Move web deployment to the ONE-OF-US.NET project (`oneofusv2` repo). Remove `bin/stage_*.sh` from nerdster. Each project manages its own hosting. Cleaner long-term, bigger one-time effort.

### 3. iosmagic → main merge
- `about.dart` changes (Legal & Privacy links, scrollable) should go to main before Android.
- Deep link fixes (`FlutterDeepLinkingEnabled = false`, `uriLinkStream`) need assessment for Android — different plugin behavior.
- Decision pending.

---

## Recommended next steps (in order of priority)

1. **Try Beta App Review first** with the existing abuse email. ONE-OF-US.NET passed — make the decentralized-moderation argument in the review notes. Low-cost, highest-upside.
2. If rejected: implement Option A (nerdster_terms.html) for proper branding, and assess whether a Firestore `global_blocked` list is needed.
3. **Web decoupling** (Option B above): good long-term hygiene but not blocking anything right now — do it when the mess of shared `web/` files becomes painful.

---

## Things NOT to touch on the web app

- No centralized censorship list checked by the web app.
- Web app can continue to mention both platforms (e.g. magic link platform hints).

---

## Email addresses

Gmail filter tip: Settings → Filters → `From: @one-of-us.net OR @nerdster.org` → **Never send to Spam**.

| Address | Purpose | Where referenced | Active? |
|---|---|---|---|
| `contact@nerdster.org` | Nerdster user contact | `web/terms.html`, `web/policy.html`, `lib/about.dart` | ✅ Yes |
| `abuse@nerdster.org` | Nerdster abuse reports | compliance plan (not yet in app) | ✅ Yes (future) |
| `conflict-help@nerdster.org` | In-app conflict notification link | `lib/ui/notifications_menu.dart` | ❓ Verify |
| `contact@one-of-us.net` | ONE-OF-US.NET user contact | `web/terms.html`, `web/policy.html`, oneofusv2 About | ✅ Yes |
| `abuse@one-of-us.net` | ONE-OF-US.NET abuse reports | oneofusv2 About screen | ✅ Yes |
| `report@one-of-us.net` | Safety/report page | `web/safety.html` | ❓ Verify |
