These packages are shared across the 3 projects (nerdster, oneofus, hablotengo).
The goal is for them to be identical. Divergence is expected to be temporary.

oneofus_common is shared across all three repos.
Exceptions: none.

nerdster_common is shared between hablotengo and nerdster only.
Exceptions: none.

---

## functions/ layer architecture

The `functions/` directories across the 3 projects share a common set of files. The layers:

**Generic utility**
- `jsonish_util.js` — token derivation, statement ordering, JSON canonicalization
- `verify_util.js` — signature verification

**Mid-level — statements, Firestore, HTTP**
- `statement_fetcher.js`
  - `fetchStatements(token2revokeAt, ...)` — one stream; handles revokeAt, distinct, notarization chain, excludeTypes
  - `fetchStatementsBatch(token2revokeAt, ...)` — many streams in parallel; returns `{token → statements[]}`, or `{token → {error}}` per token on failure. JS-layer equivalent of `oneofusSource.fetch()` for own-project streams.
- `export.js` — HTTP GET; parses `spec` array, calls `fetchStatementsBatch`, streams results back one line per token
- `write.js` / `write2.js` — HTTP endpoints for appending signed statements

**Higher-level — trust graph and delegation**
- `trust_logic.js` — BFS reduction algorithm
- `trust_pipeline.js` — orchestrates BFS fetch+reduce cycles to build a trust graph
- `delegate_resolver.js` — resolves which delegate keys belong to which identities
- `fetchDelegateStatements(resolver, identityToken, ...)` in `statement_fetcher.js` — fetches all delegate streams for an identity, merged; depends on `DelegateResolver`

**Project-specific**
- `seed_nerdster.js` — builds trust graph and fetches all delegate content; returns a seed bag for client startup
- `get_batch_contacts.js` (hablotengo only) — builds trust graph and resolves contact cards for all trusted contacts

Project-specific functions use the layers: `seedNerdster` and `getBatchContacts` go through `TrustPipeline`, `DelegateResolver`, `fetchStatementsBatch`, and `fetchDelegateStatements`.
