# Nerdster Web Development Guide

Covers local development, testing, and deployment after moving the Flutter
web app from `https://nerdster.org/` to `https://nerdster.org/app`.

---

## URL Structure

| URL | Content |
|-----|---------|
| `https://nerdster.org/` | Static home page (`home.html` → `index.html`) |
| `https://nerdster.org/app` | Flutter web app |
| `https://nerdster.org/terms.html` | Terms of Service |
| `https://nerdster.org/safety.html` | Safety & Content Policy |
| `https://nerdster.org/policy.html` | Privacy Policy |

App Links (Android) and Universal Links (iOS) are restricted to `/app*`
so all other `nerdster.org` paths open normally in the browser even when
the native app is installed.

---

## Local Development

### Nerdster app only (hot reload)

```bash
flutter run -d chrome
```

The app runs at `http://localhost:<port>/` (Flutter picks a free port).
To use the emulator, add `?fire=emulator` in the browser URL bar after launch.

> **Note:** In this mode there is no `/app` path — the app is at the root.
> This is fine for Flutter UI development. Use the full build setup below
> when you need to test the `/app` path or OneOfUs iframe embedding.

---

### Both websites (Nerdster + OneOfUs iframe embedding)

This mirrors the production structure. Run from each project root:

**Terminal 1 — Nerdster** (from `nerdster14/`):
```bash
./bin/serve_web.sh
```
This builds Flutter with `--base-href /app/`, restructures the output,
and starts a server at port 8765.

**Terminal 2 — OneOfUs** (from `oneofusv22/`):
```bash
python3 -m http.server 8766 --directory web
```

**Open in browser:**
| URL | What you get |
|-----|-------------|
| `http://localhost:8765/app?fire=emulator` | Nerdster Flutter app |
| `http://localhost:8765/?fire=emulator` | Nerdster home page |
| `http://localhost:8766/index.html?fire=emulator` | OneOfUs website |

> **Note:** `serve_web.sh` does a full `flutter build web` each time (~30s).
> Use `flutter run -d chrome` for rapid UI iteration; switch to `serve_web.sh`
> only to verify the `/app` path or iframe embedding.

---

## Deployment

```bash
./bin/deploy_web.sh
```

From `nerdster14/`. Does:
1. `flutter build web --base-href /app/`
2. Moves Flutter output into `build/web/app/`
3. Renames `home.{html,css,js}` → `index.{html,css,js}` at the root
4. `firebase deploy --only hosting`

---

## Integration Tests

Integration tests run via `flutter run -d chrome` against the emulator and
are **unaffected** by the `/app` path change — they drive the Flutter app
directly, not via a deployed URL.

```bash
./bin/integration_test.sh
# or
./bin/run_all_tests.sh
```

---

## What to Manually Test After Deploying

### Android (native app installed)
- [ ] `https://nerdster.org/` — opens **home page in browser** (not native app)
- [ ] `https://nerdster.org/terms.html` — opens in browser
- [ ] `https://nerdster.org/safety.html` — opens in browser
- [ ] `https://nerdster.org/app` — opens **native app**
- [ ] `https://nerdster.org/app?identity=...` share link — opens native app
- [ ] About dialog: Home, Embed, Terms, Safety, Privacy links all open in browser
- [ ] Sign-in dialog: Terms and Safety links open in browser

### Android (no app installed) / Desktop browser
- [ ] `https://nerdster.org/` — loads home page
- [ ] `https://nerdster.org/app` — loads Flutter web app
- [ ] `https://nerdster.org/app?identity=...` share link — loads web app with correct identity

### iOS (native app installed)
- [ ] `https://nerdster.org/app?identity=...` share link — opens native app
- [ ] `https://nerdster.org/terms.html` — opens in Safari (not native app)

### OneOfUs website (iframe embedding)
- [ ] `https://one-of-us.net` pages with Nerdster iframes load correctly:
  - `crypto.html`, `crypto_trust.html`, `crypto_identity.html`, `ready.html`
- [ ] Iframes pick up `?fire=emulator` param from parent page in dev

### Share links
- [ ] Share link generated from **native app** contains `nerdster.org/app?...`
- [ ] Share link generated from **web app** contains `nerdster.org/app?...`
- [ ] Sign-in flow completes successfully end-to-end (Android + iOS)
