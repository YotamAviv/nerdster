# TODO

~~I don't recall the details, but I was able to sign out and dismiss the sign in dialog and be left in a state where there is no identity.~~ **FIXED build +171.**
- Sign-in dialog safety net re-shows via `_AppHome._maybeShowDialog` safety net.
- Bootstrap-specific fix: `signOut(clearIdentity: wasBootstrap)` in `sign_in_widget.dart` — clears identity on bootstrap sign-out so `_onSignInChanged` → `_maybeShowDialog` fires.
- `_onSignInChanged` auto-dismisses the sign-in dialog when sign-in arrives externally (e.g., deep link), using `addPostFrameCallback` to avoid double-pop with Bootstrap button.

~~Clicking on https://nerdster.org/?identity=... bounced between app and Safari.~~ **FIXED build +171.** See `docs/deep_links.md` for full details.
- `FlutterDeepLinkingEnabled = false` in `Info.plist` (absent = true, must be explicitly false).
- `AppLinks().uriLinkStream.listen(...)` for foreground link handling (applies `Setting.updateFromQueryParam` + `defaultSignIn`).




## Test with skipVerify=false



## Dead code in cloud functions: OMDB / TMDB fetchers

`functions/metadata_fetchers.js` contains `fetchFromOMDb` and `fetchFromTMDB`, called
from `executeFetchImages` in `functions/core_logic.js` when the content type is `movie`.

Both functions guard on environment variables that are apparently never set:

```js
// fetchFromOMDb:
const apiKey = process.env.OMDB_API_KEY;
if (!apiKey || !title) return [];

// fetchFromTMDB:
const apiKey = process.env.TMDB_API_KEY;
if (!apiKey || !title) return [];
```

Since `OMDB_API_KEY` and `TMDB_API_KEY` are not known to be configured in Firebase,
both functions silently return `[]` on every call. Movie image fetching falls back to
Wikipedia only.

**Resolution options:**
1. Set `OMDB_API_KEY` and/or `TMDB_API_KEY` as Firebase environment variables (free-tier
   keys available at omdbapi.com and themoviedb.org).
2. Remove the dead calls to `fetchFromOMDb` and `fetchFromTMDB` from `core_logic.js` and
   delete the two functions from `metadata_fetchers.js`.
