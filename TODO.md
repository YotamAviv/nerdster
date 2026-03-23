# TODO


## protocol in HomedKey
Vouch, replace include
Key 
All other fields in json obj


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
