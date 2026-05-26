# CF OOU Cache Seeding — Startup Round-Trip Reduction

## Goal

Reduce the number of cloud round trips at Nerdster startup by having the Cloud Functions
return the OOU statement cache they accumulate during trust graph computation, so Nerdster
can seed its channels with that data and skip redundant fetches.

## Background

When Nerdster starts up, `FeedController._load()` creates a Dart `TrustPipeline` and calls
`.build()`. The pipeline performs BFS over the trust graph, fetching OOU statements from
one-of-us.net one layer at a time — potentially 6+ round trips just to establish the trust
network, before any content is loaded.

## Design

The CF runs `TrustPipeline.build()` server-side for the given PoV and returns the accumulated
`oouCache` (`{ [token]: statement[] }`). Nerdster seeds its OOU channel with this data, then
runs the Dart-side trust graph computation as usual — all fetches hit cache, no network I/O.

**Why not return the full trust graph?**
- Nerdster does incremental fetching as the user changes PoV, so the channel abstraction must
  stay live anyway.
- Computing the trust graph from cached data is cheap (CPU-only). The expensive part is round
  trips, not computation.

## What Was Built

### 1. `getOouCache` CF endpoint (`nerdster/functions/get_oou_cache.js`)

- No auth required — OOU statements are public data
- Query params: `povToken` (required), `pathRequirement` ('permissive' | 'standard' | 'strict')
- Returns `{ oouCache: { [token]: statement[] } }`
- `minInstances: 1` to avoid cold-start latency

JS logic files copied from `hablotengo/functions/` (keep in sync):
`trust_pipeline.js`, `trust_logic.js`, `oneofus_source.js`

### 2. `FeedController._seedTrustChannelFromCF()` (`lib/logic/feed_controller.dart`)

Called from `_load()` before `TrustPipeline.build()` if the trust channel is not yet cached:
1. GET `getOouCache` with current PoV token + path requirement setting
2. Verify each statement with `OouVerifier`, parse to `TrustStatement`
3. Seed `trustSource` per token — BFS then runs entirely from cache (0 misses confirmed)

Controlled by `_seedingEnabled` flag (used by the benchmark tool).

### 3. Benchmark tool (DEV menu → "Benchmark seeding")

10 alternating runs (seeded / unseeded), clearing all channels + Jsonish between each.
Reports median and average for OOU phase, delegate content, and CF fetch time.
Intended as a temporary diagnostic; may be removed once the optimization is settled.

### 4. Timing instrumentation in `_load()`

`_lastOouMs`, `_lastDelegateMs`, `_lastCfFetchMs` — captured after each timed section.
Also temporary; used only by the benchmark tool.

## Decisions

**Federation:** The JS `TrustPipeline` already supports federated keys via `sourceFor` +
`fedRegistry`. No additional work needed.

**Path requirements:** Passed as a query parameter; three functions (`permissive`,
`standard`, `strict`) are implemented in `trust_logic.js`.

**`myIdentity` edge case:** When the signed-in user is the PoV (the common case), their
statements are already in the cache. The rare case where `myIdentity` is outside the PoV's
graph still costs one extra round trip — deferred.

**Emulator mode:** `getOouCache` is registered in `main.dart` via
`FirebaseConfig.registerRedirect()` mapping to port 5001, consistent with other CF calls.

## Results

Mildly disappointing. The round-trip reduction is real, but the CF call itself costs nearly
as much as the direct BFS for a shallow network. The CF fetches the same total data as the
client would have fetched directly — the only win is lower server-side latency for the BFS
round trips. For a small, shallow network (3–4 depths, ~24 keys) that savings is small.

Benchmark from Andrew's PoV (nerdster.org, prod, 5 seeded / 5 unseeded alternating):

```
OOU phase (ms):
  Seeded:   median=943  avg=962  raw: 854, 1239, 1013, 943, 764
  Unseeded: median=1370  avg=1290  raw: 1556, 1370, 1060, 1460, 1007

Delegate content (ms):
  Seeded:   median=1689  avg=1681  raw: 1720, 1689, 1618, 1700, 1678
  Unseeded: median=1614  avg=1670  raw: 1713, 1602, 1606, 1614, 1818

CF fetch (ms):
  median=910  avg=926  raw: 813, 1203, 976, 910, 731
```

The OOU phase improves ~30% (943ms vs 1370ms median), but the CF fetch (910ms) accounts for
most of the seeded cost — the BFS from cache is only ~33ms. Delegate content shows no
meaningful difference, as expected (seeding only touches the trust channel).

The optimization would be more valuable for:
- Larger/deeper networks (more sequential BFS round trips to eliminate)
- CF-side caching of the result (most callers skip the BFS entirely)

## Planned

- Try seeding the delegate content channel similarly, to reduce delegate content round trips.
- CF-side caching of the oouCache result (TTL-based) to amortize BFS cost across callers.
