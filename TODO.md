# TODO

## Optimistic writes for rate/dismiss/equivalence actions

Currently `FeedController.push()` awaits the network write before calling `notify()`, so
the UI only updates after the round-trip completes. We had this working in the old `v2/`
architecture (commit `815a939`, Jan 2026) and lost it in the `ChannelFactory` refactor
(commit `0849202`, May 7 2026).

**Plan:**
1. Add a public `inject(T statement)` method to `_CachedSource` in `channel_factory.dart`
   that updates the local cache immediately (same logic as the private `_inject`).
2. In `FeedController.push()`: sign the statement, inject it into the cache, call `notify()`
   (UI updates instantly), then fire the network write. If the write fails, call `refresh()`
   to correct the cache.
3. The tricky part: the `previous` pointer is currently set inside the push queue. It needs
   to be read from the cache head before injecting, and the same value passed to the writer.
4. Apply the same pattern to `pushEquivalence`.

## merge don't sort - check everywhere!

## DemoKey shouldn't do "fetch before push" everywhere!


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
