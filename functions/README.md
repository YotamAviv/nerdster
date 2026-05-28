Files with the same name across the 3 projects (nerdster, oneofus, hablotengo) are identical.
Exceptions (per-project customizations):
- schema.js
- read_auth.js
- write_auth.js
- index.js

## Layers

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

## Do the project-specific functions use the layers?

Yes — `seedNerdster` and `getBatchContacts` go through `TrustPipeline`, `DelegateResolver`, `fetchStatementsBatch`, and `fetchDelegateStatements`.
