# TODO

I don't recall the details, but I was able to sign out and dismiss the sign in dialog and be left in a state where there is no identity. This should be impossible; with no identity, the sign in dialog should be up.
- **Fix applied (lib/app.dart):** Added safety net in `_AppHome._maybeShowDialog` — after the dialog closes, if `!signInState.isSignedIn`, it immediately re-shows. Root cause not fully reproduced from code review; `signOut(clearIdentity: false)` keeps identity set so the normal sign-out path shouldn't leave no identity. The safety net is defensive and covers any edge case.
- **Status:** Code change made, not yet tested on device.

Clicking on https://nerdster.org opens app, but clicking on https://nerdster.org?stuff opens the phone app and almost immediately bounces to the webapp app in Safari. There, Safari shows an "OPEN" button which opens the phone again app but bounces back again.
- **Root cause:** Two problems: (1) `FlutterDeepLinkingEnabled = true` with `MaterialApp` (no router) causes Flutter to bounce unrecognized URLs to Safari. (2) No foreground `app_links` stream listener — when the app is already running and a link is tapped, nothing handles it, causing the same bounce.
- **Attempted fix 1 (web/.well-known/apple-app-site-association):** Upgraded org.nerdster.app from legacy `"paths": ["*"]` to modern `"components"` format. Did NOT fix the issue.
- **Attempted fix 2 (ios/Runner/Info.plist):** Removed `FlutterDeepLinkingEnabled`. Build +165. Did NOT fix the issue (foreground stream still missing). Reverted in +166.
- **Fix applied (lib/main.dart + ios/Runner/Info.plist):** Added `AppLinks().uriLinkStream.listen(...)` after `runWidget()` to handle foreground Universal Link taps. Removed `FlutterDeepLinkingEnabled`.
- **Status:** Requires new TestFlight build to test. Test both cold-start and foreground taps.

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
