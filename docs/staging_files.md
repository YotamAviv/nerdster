# web/ Files by Site — Actual Dependencies

Traced by reading each HTML file's `src=`/`href=` references.

**Nerdster entry points:** `index.html` (Flutter app shell) → `flutter_bootstrap.js` (build artifact, not in web/), `manifest.json`, `favicon.ico`, `icons/`  
**Nerdster routes rendered by Flutter:** `home.html`, `vouch.html` (served as Flutter web routes from within the app)  
**Nerdster man page:** `nerdster_man.html` → no external local file deps (all CSS is inline)

**OneOfUs entry points:** `oneofus.html` (full static page) → many local files  
**OneOfUs man page:** `oneofus_man.html` → no external local file deps (all CSS is inline)

---

## File dependency table

| File | Nerdster | OneOfUs | How referenced |
|------|:--------:|:-------:|----------------|
| **`index.html`** | ✅ entry | — | Flutter app shell |
| **`manifest.json`** | ✅ | — | `<link rel="manifest">` in index.html |
| **`favicon.ico`** | ✅ | — | `<link rel="shortcut icon">` in index.html |
| **`icons/`** | ✅ | — | `<link rel="apple-touch-icon" href="icons/Icon-192.png">` in index.html |
| **`home.html`** | ✅ | — | Flutter web route (nerdster.org/home) |
| **`home.css`** | ✅ | — | `<link>` in home.html |
| **`home.js`** | ✅ | — | `<script>` in home.html |
| **`iframe_helper.js`** | ✅ | — | `<script>` in home.html (and crypto/ready iframes) |
| **`data/demoData.js`** | ✅ | — | `<script>` in home.html |
| **`vouch.html`** | ✅ | — | Flutter web route + iOS universal link target |
| **`verify_helper.js`** | ✅ | — | `<script>` in vouch.html |
| **`img/nerd.png`** | ✅ | — | `<img>` in home.html |
| **`img/sample.png`** | ✅ | — | `<img>` in home.html |
| **`nerdster_man.html`** | ✅ (→ man.html) | — | Staged as `man.html`; all CSS inline |
| **`oneofus.html`** | — | ✅ entry | Staged as `index.html` |
| **`oneofus.css`** | — | ✅ | `<link>` in oneofus.html |
| **`oneofus_man.html`** | — | ✅ (→ man.html) | Staged as `man.html`; all CSS inline |
| **`img/oneofus_favicon.png`** | — | ✅ | `<link rel="icon">` in oneofus.html |
| **`img/oneofus_1024.png`** | — | ✅ | `<img>` in oneofus.html |
| **`img/jones.png`** | — | ✅ | `<img>` in oneofus.html |
| **`img/sheila-sm-flip.png`** | — | ✅ | `<img>` in oneofus.html |
| **`img/punk2.png`** | — | ✅ | `<img>` in oneofus.html |
| **`img/nerd.flipped.png`** | — | ✅ | `<img>` in oneofus.html |
| **`img/marketing_help.png`** | — | ✅ | `<picture>` in oneofus.html |
| **`img/apple.webp`** | — | ✅ | `<img>` in oneofus.html (also in possibilities.html) |
| **`img/google.webp`** | — | ✅ | `<img>` in oneofus.html (also in possibilities.html) |
| **`crypto.html`** | — | ✅ | `<iframe src="crypto.html">` in oneofus.html |
| **`crypto_trust.html`** | — | ✅ | `<iframe src="crypto_trust.html">` in oneofus.html |
| **`crypto_identity.html`** | — | ✅ | `<iframe src="crypto_identity.html">` in oneofus.html |
| **`ready.html`** | — | ✅ | `<iframe src="ready.html">` in oneofus.html |
| **`possibilities.html`** | — | ✅ | `<iframe src="possibilities.html">` in oneofus.html |
| **`talk.html`** | — | ✅ | `<a href="talk.html">` in oneofus.html |
| **`boxes.js`** | ✅ | ✅ | `<script>` in home.html AND oneofus.html |
| **`boxes.css`** | ✅ | ✅ | `<link>` in home.html AND oneofus.html |
| **`box.css`** | ✅ | ✅ | `<link>` in home.html AND oneofus.html |
| **`box-common.css`** | ✅ | ✅ | `<link>` in home.html AND oneofus.html |
| **`guard.js`** | ✅ | ✅ | `<script>` in home.html AND oneofus.html |
| **`.well-known/`** | ✅ | ✅ | Required for app links / universal links on both domains |
| **`policy.html`** | ? | ? | Not referenced by any HTML in web/; possibly linked externally |
| **`terms.html`** | ? | ? | Not referenced by any HTML in web/ |
| **`safety.html`** | ? | ? | Not referenced by any HTML in web/ |

> [!NOTE]
> `vouch.html` is a Nerdster-only file. It is the iOS universal link target
> (`https://one-of-us.net/vouch.html#<hash>`) handled by the Flutter app,
> not a one-of-us.net static page.
