# TODO


## Dis statement export (KeyInfoView)

Two items deferred from the dis stream separation. Details in `docs/dis_stream_separation.md`.

### Bug: emulator link opens prod

`KeyInfoView._buildStatementsLink` shows the external `export.nerdster.org` link for both
`FireChoice.emulator` and `FireChoice.prod`. In emulator mode the link queries prod Firestore.

**Fix**: change the condition from `fireChoice != FireChoice.fake` to `fireChoice == FireChoice.prod`.

### Feature: show signed, published dismiss statements

**Server**: Update the Cloud Function at `export.nerdster.org` to accept an optional
`subcollection` query param (default `'statements'`); serve `/{spec}/dis/statements` when
`subcollection=dis/statements` is passed. Backward compatible.

**Client**: In `node_details.dart`, add a second `KeyInfoView.show` call for the delegate using
`SourceFactory.forDis(delegateToken)` and a `baseUrl` that appends `?subcollection=dis/statements`.
Add a "Signed, Published Dismiss Statements" link in `KeyInfoView._buildStatementsLink`.




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
