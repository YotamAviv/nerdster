# TODO

## DONE (May 2026): Seed startup channels from CF — `seedNerdster` endpoint

`seedNerdster` computes the OOU trust graph server-side and returns a flat bag
`{ fetchUrl: statements[] }` covering OOU trust statements + delegate content (all types
and no-dismiss). The client loads the bag into `ChannelFactory.loadSeedBag()` before
the first `_load()`, eliminating the sequential BFS round trips. Measured improvement:
~780ms at median on PROD (seeded ~1945ms vs. unseeded ~2725ms).

## FIXED (May 2026, seed branch): Delegate domain filtering — fetch only nerdster.org delegates

`DelegateResolver.getDelegatesForIdentity` returns delegates for all domains. Nerdster
should only consider `nerdster.org` delegates when building `myDelegateKeys` and
`delegateKeysToFetch` in `feed_controller.dart`. Without the filter, OOU delegates from
other apps (hablotengo.com, etc.) are fetched and a `!`-crash occurs in `_collectSources`
when their keys are absent from `contentResult.delegateContent`.

**Already fixed in the seed branch** (May 2026). Must land on main if the seed branch is
not merged:

- `feed_controller.dart`: `.where((k) => delegateResolver.getDomainForDelegate(k) == kNerdsterDomain)`
  on both `myDelegateKeys` and `delegateKeysToFetch`.
- `content_logic.dart`: `contentResult.delegateContent[key]!` → null-safe check (lines ~19
  and ~427) since not all resolver delegates are fetched after the filter.
- `functions/seed_nerdster.js`: `collectDelegateTokens` already filters by `s.with?.domain === 'nerdster.org'`.

## Sign-in failures.. show QR?

- I'm confused. Didn't the page at https://one-of-us.net/sign-in?parameters= used to show the QR code to scan? Should it, or has the app stopped listening already?

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
