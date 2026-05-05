# Web Staging Files

**Goal:** retire `bin/stage_nerdster.sh` and `bin/stage_oneofus.sh`. Run `firebase deploy`
directly from each project root with no transformation scripts.

**How:** files are given their **final names in source** — no renaming at deploy time.
Common files live in `web/common/` in each project and are referenced as `common/filename`
in HTML — no copying to root needed.

- **Nerdster** (`nerdster14/`): `flutter build web` copies `web/` → `build/web/`; then `firebase deploy`
- **OneOfUs** (`oneofusv22/`): static site; `firebase.json` points `"public": "web"` directly — no build step

---

## Common files (`web/common/` in each project)

Referenced in HTML as `common/boxes.js`, `common/data/demoData.js`, etc.
Duplicated into both projects — changes must be kept in sync.

| File | Notes |
|------|-------|
| `boxes.js` | JavaScript box-rendering logic |
| `boxes.css` | Box layout CSS |
| `box.css` | Individual box CSS |
| `box-common.css` | Shared box CSS |
| `guard.js` | JS guard/safety helper |
| `iframe_helper.js` | Used by home.html (Nerdster) and crypto/ready iframe files (OneOfUs) |
| `verify_helper.js` | Used by home.html (Nerdster) and vouch.html (OneOfUs) |
| `data/demoData.js` | Demo identity data; used by home.html, crypto_identity.html, crypto_trust.html |
| `img/apple.webp` | App Store badge; used by home.html (Nerdster) and oneofus.html, possibilities.html (OneOfUs) |
| `img/google.webp` | Google Play badge; same as above |

---

## Nerdster files (`nerdster14/web/`)

| File | Notes |
|------|-------|
| `index.html` | Flutter app shell |
| `manifest.json` | `<link rel="manifest">` in index.html |
| `favicon.ico` | `<link rel="shortcut icon">` in index.html |
| `icons/` | App icons; `apple-touch-icon` in index.html |
| `home.html` | Flutter web route (`nerdster.org/home`) |
| `home.css` | `<link>` in home.html |
| `home.js` | `<script>` in home.html |
| `img/nerd.png` | `<img>` in home.html |
| `man.html` | Man page; all CSS inline *(was `nerdster_man.html`)* |
| `.well-known/assetlinks.json` | Android app links *(was `nerdster_assetlinks.json`)* |
| `.well-known/apple-app-site-association` | Universal links |

> **TODO:** Create `policy.html`, `terms.html`, and `safety.html` for Nerdster (copies/adaptations of the OneOfUs versions).

---

## OneOfUs files (`oneofusv22/web/`)

| File | Notes |
|------|-------|
| `index.html` | Static entry point *(was `oneofus.html`)* |
| `index.css` | Main stylesheet; referenced by index.html + all iframes *(was `oneofus.css`)* |
| `man.html` | Man page; all CSS inline *(was `oneofus_man.html`)* |
| `vouch.html` | iOS universal link target (`one-of-us.net/vouch.html#<hash>`) |
| `crypto.html` | `<iframe>` in index.html |
| `img/sample.png` | `<img>` in crypto.html |
| `crypto_trust.html` | `<iframe>` in index.html |
| `crypto_identity.html` | `<iframe>` in index.html |
| `ready.html` | `<iframe>` in index.html |
| `possibilities.html` | `<iframe>` in index.html; also references `common/img/apple.webp`, `common/img/google.webp` |
| `talk.html` | `<a href>` in index.html |
| `img/oneofus_favicon.png` | `<link rel="icon">` in index.html |
| `img/oneofus_1024.png` | `<img>` in index.html |
| `img/jones.png` | `<img>` in index.html |
| `img/sheila-sm-flip.png` | `<img>` in index.html |
| `img/punk2.png` | `<img>` in index.html |
| `img/nerd.flipped.png` | `<img>` in index.html |
| `img/marketing_help.png` | `<picture>` in index.html |
| `.well-known/assetlinks.json` | Android app links *(was `oneofus_assetlinks.json`)* |
| `.well-known/apple-app-site-association` | Universal links |
| `policy.html` | Play/App Store boilerplate; linked externally |
| `terms.html` | Same |
| `safety.html` | Same |

---

## Firebase config files

Two configs serve different purposes and are maintained separately:

| File | Location | Purpose |
|------|----------|---------|
| `firebase.json` | `nerdster14/` root | Nerdster emulator + hosting deploy (`"public": "build/web"`) |
| `oneofus.firebase.json` | `nerdster14/` root | OneOfUs **emulator config** — stays here permanently; used by `bin/start_emulators.sh` |
| `firebase.json` | `oneofusv22/` root | OneOfUs **hosting deploy config** (`"public": "web"` — no build step needed) |

> [!NOTE]
> `nerdster14/oneofus.firebase.json` and `oneofusv22/firebase.json` are intentionally
> separate files with different roles. The emulator config lives alongside the nerdster
> project (no dependency on where oneofusv22 is checked out). The deploy config lives
> in oneofusv22 and is used when deploying from that project root.

---

## Verification checklist

Run these checks after the migration, before deploying to production.

### Pre-deploy (local, against emulators)

- [ ] `bin/start_emulators.sh` starts both emulators cleanly
- [ ] `bin/stop_emulators.sh` stops them cleanly
- [ ] **Nerdster site** — `flutter build web && python3 -m http.server 8765 --directory build/web`, open `http://localhost:8765/home.html?fire=emulator`
  - [ ] Box demos load
  - [ ] `http://localhost:8765/man.html` loads
- [ ] **OneOfUs site** — `python3 -m http.server 8766 --directory web` from `oneofusv22/`, open `http://localhost:8766/index.html?fire=emulator`
  - [ ] iframes load: crypto, crypto_trust, crypto_identity, ready, possibilities
  - [ ] `vouch.html` loads
  - [ ] `http://localhost:8766/man.html` loads
- [ ] All integration tests pass

> [!NOTE]
> Note: `/man` (clean URL) only works with Firebase hosting. The python server requires `/man.html`.

> [!NOTE]
> Also try Firebase emulator hosting once as a pre-deploy check — it tests `cleanUrls` (`/man` works),
> Flutter rewrite rules, and `.well-known/` headers, which python's server doesn't exercise:
>
> - Nerdster: `flutter build web && firebase emulators:start --only hosting` (serves `build/web/` on `localhost:5000`)
> - OneOfUs: `firebase emulators:start --only hosting` from `oneofusv22/` (serves `web/` on `localhost:5005`)

### Post-deploy (production)

- [ ] Deploy Nerdster: `flutter build web && firebase deploy --only hosting --project=nerdster` from `nerdster14/`
- [ ] Deploy OneOfUs: `firebase deploy --only hosting` from `oneofusv22/`
- [ ] Nerdster production site loads and functions correctly
- [ ] OneOfUs production site loads and functions correctly
- [ ] App links / universal links still work on device (`.well-known/assetlinks.json` served correctly)
- [ ] Run integration tests against production
