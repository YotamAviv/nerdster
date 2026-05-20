# TODO

## Optimistic writes for rate/dismiss/equivalence actions

Currently `FeedController.push()` awaits the network write before calling `notify()`, so
the UI only updates after the round-trip completes. We had this working in the old `v2/`
architecture (commit `815a939`, Jan 2026) and lost it in the `ChannelFactory` refactor
(commit `0849202`, May 7 2026).

**oneofus_common (`channel_factory.dart`, `statement_source.dart`):**
1. In `_CachedSource.push()`: inject the statement into the local cache immediately, then
   fire the network write via the existing push queue in the background. Return a future
   that completes after injection, not after the write.
2. The tricky part: the `previous` pointer is currently set inside the push queue. It needs
   to be read from the cache head at inject time, and the same value passed to the writer.
3. Write failures surface via a per-channel `ValueNotifier<Object?>` error notifier on
   `_CachedSource` — the app layer registers once per channel rather than handling at
   every call site.
4. Update the contract comment on `StatementWriter.push()` in `statement_source.dart` to
   reflect that it now returns after local injection, with the write completing in background.

**nerdster/oneofus/hablotengo (app initialization, not FeedController):**
5. `FeedController` (and equivalent read/write code) needs no change — `notify()` is
   already called right after `push()` and will fire at the right time once the semantics
   change.
6. Each project's main app initialization registers a write failure handler on its channels.
   For nerdster: show the existing "We need to reload" dialog from `app.dart` — no dismiss,
   programmatic reload only. Oneofus and hablotengo implement their own equivalent.

**Tests (both must be restored/added):**
- **#1 No re-fetch**: After a write, verify that `fetch()` is never called on the source
  (i.e. the cache is used as-is). Restore from `test/v2/partial_refresh_test.dart` in
  commit `815a939`.
- **#2 No waiting**: Verify that `notify()` is called *before* the network write returns —
  i.e. the UI updates while the write is still in flight.


ISSUES:
I feel like we're (AI and I) playing whack a mole. I want to not await and so you let us not await but add await somewhere else for a new function that should never exist: drainWrites.

We do want to have a "refresh" ability. A user might step away from your Nerdster browser for a day and want to check for new content, which is obviously not in your cache, and so we need to have a refresh at the infrastructure. That call should require an await.

Consider that and see if you can offer a way to remove drainWrites from the infrastructure.




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
