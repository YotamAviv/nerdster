# TODO

## Optimistic writes — MOSTLY DONE; one bug remaining

`push()` now returns after local cache inject (before network write). Write failures go to
`ChannelFactory.onWriteError`. `clear()` is async and drains pending writes. `clearCache()`
is async. These are implemented and tested.

### Remaining bug: `excludeTypes` fanout

**Invariant that must hold**: each unique `(exportUrl, streamKey, excludeTypes, distinct)`
combination gets its own root (`_CachedSource`) with its own server-side fetch config.
`excludeTypes` must reach the server — it is a bandwidth optimization, not merely a local
filter.

**Problem**: for optimistic writes to be immediately visible in every channel for the same
stream (regardless of `excludeTypes`), all such roots need the inject. Currently all channels
share one root (excludeTypes ignored), which breaks server-side filtering.

**Correct fix — inject fanout**:
- Keep separate roots per `excludeTypes` (restore old cache key including `excludeTypes`).
- `ChannelFactory` maintains a secondary index: `"exportUrl/streamKey" → List<_CachedSource>`.
- When `_CachedSource._inject(statement)` runs, it also fans out to every sibling in that
  list, subject to two guards:
  1. The sibling's `_fullCache` must already contain the issuer (no fetch-to-satisfy).
  2. The statement's type must not be in the sibling's `excludeTypes`.
- Use a separate `_injectLocal` (no fanout) so siblings don't recurse back.
- Fanout is read from the factory index at inject time (late-bound, like `_getOnWriteError`).

**Test fix** (restore original intent, don't remove `upload()`):
- Call `await contentSource.clear()` BEFORE `upload()` to drain the background write.
- The background write lands in Firestore first; `upload()` then overwrites with `set()`
  (harmless). The cache is cleared; re-fetch before any subsequent `push()` if needed.
- Do NOT remove `upload()` — it tests that the pipeline reads from Firestore correctly.


## Clean up the vestigial do/make split in DemoKey

`makeRate`, `makeFollow`, and `makeRelate` in `DemoKey` have no external callers — they are only called by their `do*` wrappers. Inline each body directly into `doRate`, `doFollow`, and `doRelate`, then delete the `make*` methods.

## Merge don't sort - check everywhere!

## DemoKey shouldn't do "fetch before push" everywhere!

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
