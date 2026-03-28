# Web Staging Files

Each site is staged by copying `web/` to `build/web/` and applying site-specific
transformations, then running `firebase deploy`.  The goal is to eliminate the
`bin/stage_*.sh` scripts and run staging + deploy from each project root via
`firebase.json` hooks (or a single `stage.sh` at each project root).

**Nerdster** lives in `nerdster14/`. Its `firebase.json` is at the root.  
**OneOfUs** lives in `oneofusv22/`. It has its own `firebase.json` (hosting only so far).  
The `bin/stage_nerdster.sh` and `bin/stage_oneofus.sh` scripts in `nerdster14/bin/`
are the current staging mechanism — both are to be retired.

---

## Common files (shared between both sites)

These files are currently kept only in `nerdster14/web/` but are used by both sites.
The plan is to duplicate them into both projects under `web/common/` and have each
project's staging step copy from there.

| File | Notes |
|------|-------|
| `boxes.js` | JavaScript box-rendering logic |
| `boxes.css` | Box layout CSS |
| `box.css` | Individual box CSS |
| `box-common.css` | Shared box CSS |
| `guard.js` | JS guard/safety helper |
| `data/demoData.js` | Demo identity data; used by home.html, crypto_identity.html, crypto_trust.html |
| `img/apple.webp` | App Store badge; used by home.html (Nerdster) and oneofus.html, possibilities.html (OneOfUs) |
| `img/google.webp` | Google Play badge; same as above |
| `iframe_helper.js` | Used by home.html (Nerdster) and crypto.html, crypto_trust.html, crypto_identity.html, ready.html (OneOfUs) |

> [!NOTE]
> All other files belong exclusively to one site. The `web/common/` subdirectory
> does not exist yet — it is the proposed destination in each project repo.

---

## Nerdster-only files (`nerdster14/web/`)

| File | Staged as | Notes |
|------|-----------|-------|
| `index.html` | `index.html` | Flutter app shell |
| `manifest.json` | `manifest.json` | `<link rel="manifest">` in index.html |
| `favicon.ico` | `favicon.ico` | `<link rel="shortcut icon">` in index.html |
| `icons/` | `icons/` | App icons; `apple-touch-icon` in index.html |
| `home.html` | `home.html` | Flutter web route (`nerdster.org/home`) |
| `home.css` | `home.css` | `<link>` in home.html |
| `home.js` | `home.js` | `<script>` in home.html |
| `img/nerd.png` | same | `<img>` in home.html |
| `nerdster_man.html` | `man.html` | Renamed at staging time; all CSS inline |
| `.well-known/nerdster_assetlinks.json` | `.well-known/assetlinks.json` | Copied at staging time |
| `.well-known/apple-app-site-association` | same | Universal links |

> **TODO:** Create `policy.html`, `terms.html`, and `safety.html` for Nerdster (copies/adaptations of the OneOfUs versions).

---

## OneOfUs-only files (`nerdster14/web/` → staged to `one-of-us.net`)

> [!NOTE]
> `oneofusv22/web/` now exists (empty). Currently all OneOfUs web files still live in
> `nerdster14/web/` and are deployed via `bin/stage_oneofus.sh` running from `nerdster14/`.
> The next step is to move these files into `oneofusv22/web/`.

| File | Staged as | Notes |
|------|-----------|-------|
| `oneofus.html` | `index.html` | Renamed at staging time; static entry point |
| `oneofus.css` | `index.css` | Renamed to `index.css` in `oneofusv22/web/`; referenced by oneofus.html, crypto.html, crypto_trust.html, crypto_identity.html, ready.html, possibilities.html (all refs updated) |

> **TODO:** When migrating, update `href="oneofus.css"` → `href="index.css"` in all 6 files above.
| `oneofus_man.html` | `man.html` | Renamed at staging time; all CSS inline |
| `vouch.html` | `vouch.html` | iOS universal link target (`one-of-us.net/vouch.html#<hash>`) |
| `verify_helper.js` | `verify_helper.js` | `<script>` in vouch.html |
| `crypto.html` | `crypto.html` | `<iframe>` in oneofus.html |
| `img/sample.png` | same | `<img>` in crypto.html |
| `crypto_trust.html` | `crypto_trust.html` | `<iframe>` in oneofus.html |
| `crypto_identity.html` | `crypto_identity.html` | `<iframe>` in oneofus.html |
| `ready.html` | `ready.html` | `<iframe>` in oneofus.html |
| `possibilities.html` | `possibilities.html` | `<iframe>` in oneofus.html; also references `apple.webp`, `google.webp` |
| `talk.html` | `talk.html` | `<a href>` in oneofus.html |
| `img/oneofus_favicon.png` | same | `<link rel="icon">` in oneofus.html |
| `img/oneofus_1024.png` | same | `<img>` in oneofus.html |
| `img/jones.png` | same | `<img>` in oneofus.html |
| `img/sheila-sm-flip.png` | same | `<img>` in oneofus.html |
| `img/punk2.png` | same | `<img>` in oneofus.html |
| `img/nerd.flipped.png` | same | `<img>` in oneofus.html |
| `img/marketing_help.png` | same | `<picture>` in oneofus.html |

| `.well-known/oneofus_assetlinks.json` | `.well-known/assetlinks.json` | Copied at staging time |
| `.well-known/apple-app-site-association` | same | Universal links |
| `policy.html` | same | Play/App Store boilerplate; linked externally |
| `terms.html` | same | Same |
| `safety.html` | same | Same |

---

## Firebase config files

Two configs serve different purposes and are maintained separately:

| File | Location | Purpose |
|------|----------|---------|
| `firebase.json` | `nerdster14/` root | Nerdster emulator + hosting deploy |
| `oneofus.firebase.json` | `nerdster14/` root | OneOfUs **emulator config** — stays here permanently; used by `bin/start_emulators.sh` and `bin/stage_oneofus.sh` |
| `firebase.json` | `oneofusv22/` root | OneOfUs **hosting deploy config** — currently Flutter-only; needs hosting section added |

> [!NOTE]
> `nerdster14/oneofus.firebase.json` and `oneofusv22/firebase.json` are intentionally
> separate files with different roles. The emulator config lives alongside the nerdster
> project (no dependency on where oneofusv22 is checked out). The deploy config lives
> in oneofusv22 and is used when deploying from that project root.
