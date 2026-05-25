# TODO

## (Like Hablo just did) Move Dart initial OOU graph search and/or more to CF JavaScript.
Should be way faster.
From Hablo's point of view, Nerdster does it in Dart because:
- Nerdster shows the trust statements
- history... I developed it, debugged it, tested it, and so Dart.

Nerdster also allows changing PoV and how you follow others, and so during its use it may need to fetch more OOU and/or Nerdster statements incrementally whereas Hablo only does full re-fetches.
Supporting this necessarily requires at least 1 round-trip to the server, ideally just 1, but trying to do that would be complicated (a new PoV may require fetching layers of trust).

For starters, I'd like to explore just reducing the round trips for the inital startup.
Option A:
Have the CFs compute the trust graph and respond with the graph and the cache of OOU statements for Nerdster to seed its channels. The hope would be that this could be clean enough that not much Nerdster client code is changed.
The Nerdster will use that as 1 round trip but will still require another for delegate content at initial startup.

DEFER: Option B:
Have the CFs compute both the trust graph and also respond with the delegate statements the Nerdster will need as well, and so startup would be reduced to 1 round trip.




## Merge don't sort - check everywhere!

## Improve SimpsonsDemo tag equate/dontEquate
Wait for context equate/dontEquate.

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
