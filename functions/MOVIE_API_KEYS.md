# Movie poster API keys (TMDB / OMDb)

The `fetchImages` cloud function can pull movie posters from **TMDB** and **OMDb**,
but only if API keys are configured. Without a key, movies fall back to Wikipedia
alone — which silently rate-limits under concurrent load and returns no image.

## Current status

- **TMDB key is configured** in `functions/.env` (`TMDB_API_KEY`). TMDB is now the
  primary movie-poster source, with Wikipedia as fallback. OMDb is not configured.
- `functions/.env` is git-ignored, so the key is not in the repo. To run the local
  emulator or deploy on another machine, recreate `functions/.env` (see below).
- **Production**: deploy with `firebase deploy --only functions` to push both the
  function code and the `.env` so the key takes effect on nerdster.org.
- **Attribution**: TMDB's terms require attribution. This is included in the app's
  About dialog (`lib/about.dart`): "Movie posters and data from TMDB … This product
  uses the TMDB API but is not endorsed or certified by TMDB."

## Throttling fix (related)

Independent of the key, `metadata_fetchers.js` now routes all JSON API calls through
a `fetchJson` helper that retries with backoff and treats a non-JSON/429/503 reply
(e.g. Wikipedia's "You are making too many requests" served as HTTP 200) as a
throttle instead of silently returning no images. Wikipedia calls also use a
descriptive User-Agent per Wikimedia's bot policy.

You only need **one** of these. TMDB is recommended (better posters, higher limits).
Getting both is fine and gives redundancy.

The code reads them here:
- `process.env.TMDB_API_KEY` — `metadata_fetchers.js` → `fetchFromTMDB`
- `process.env.OMDB_API_KEY` — `metadata_fetchers.js` → `fetchFromOMDb`

---

## Option A — TMDB (recommended)

1. Create a free account: https://www.themoviedb.org/signup
2. Verify your email and log in.
3. Go to **Settings → API**: https://www.themoviedb.org/settings/api
4. Click **Request an API Key** → choose **Developer**.
5. Fill in the form. For a personal/hobby project you can put:
   - Type of use: Personal / Education
   - Application name: Nerdster
   - Application URL: https://nerdster.org
   - Summary: "Fetches movie poster images for a social bookmarking app."
6. Accept the terms. The key is issued instantly.
7. Copy the **"API Key (v3 auth)"** value — that's the one this code uses
   (`api_key=...` query param). It looks like a 32-char hex string.

## Option B — OMDb

1. Go to https://www.omdbapi.com/apikey.aspx
2. Choose the **FREE** tier (1,000 requests/day).
3. Enter your email, submit.
4. You'll get an email with a link to **activate** the key (don't skip this).
5. Copy the key from the email (looks like `1a2b3c4d`).

---

## Where to put the keys

Firebase Functions v2 (this project) automatically loads a `.env` file from the
`functions/` directory — for both the local emulator and deploys.

1. Create `functions/.env` with:

   ```
   TMDB_API_KEY=your_tmdb_v3_key_here
   OMDB_API_KEY=your_omdb_key_here
   ```

   (Include only the line(s) for the key(s) you got.)

2. **Add it to git-ignore so you don't commit the keys.** Append to
   `functions/.gitignore` (create the file if needed):

   ```
   .env
   .env.*
   ```

3. Restart the emulator (or redeploy) so the new env is picked up:
   - Emulator: stop and re-run your `firebase emulators:start ...`
   - Production: `firebase deploy --only functions`

### Verify it worked

From `functions/`, with the `.env` in place:

```
node -e 'require("dotenv").config(); const {executeFetchImages}=require("./core_logic"); executeFetchImages({title:"The Godfather",contentType:"movie"}).then(r=>console.log(r.images))'
```

You should see a `tmdb` or `omdb` source URL in the output, not just `wikipedia`.
(If `dotenv` isn't installed, the emulator/Firebase still loads `.env` on its own —
this one-liner just needs it for a bare `node` run: `npm i -D dotenv`.)

---

## Notes

- These are low-sensitivity keys, but treat them like passwords: don't commit them.
- If you ever want stronger secret handling, Firebase supports
  `firebase functions:secrets:set TMDB_API_KEY` (Google Secret Manager) instead of
  a `.env` file. Not necessary for hobby use.
- TMDB free tier is effectively unlimited for this use. OMDb free is 1,000/day.
