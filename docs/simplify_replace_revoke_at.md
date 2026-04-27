# Simplify Replace revokeAt Semantics — IMPLEMENTED

## Decision

Treat any replace statement with `revokeAt = <token T>` as if it were
`revokeAt = <since always>`. The V2 ONE-OF-US.NET identity app only ever produces
`<since always>` anyway. The user restates what they want to keep using the new key.
This is equivalent in outcome and simpler.

## Motivation

The primary driver is an upcoming JavaScript port of the trust graph algorithm for use
in a Hablo Cloud Function. Removing the revokeAt-with-token logic simplifies the
algorithm significantly before that port, making the JS version easier to write and
maintain.

## What changes in the algorithm (trust_logic.dart)

Remove entirely:
- `byToken` index (was only needed for `resolveReplacementLimit`)
- `resolveReplacementLimit` function
- `replacementConstraints` map and all propagation logic
- The re-filtering of statements in stage 2 based on replacement constraints

After the change: any replace statement causes the old key to be revoked since always.
No time-bounded filtering of old key statements. `revokeAt` must be `"<since always>"`; any other value throws `UnimplementedError`.

Note: this change applies ONLY to replace statements. `revokeAt` on delegate statements
has a different and still-valid purpose (revoking a specific delegate key at a point in
time) and is NOT changed.

## What changes in TrustGraph model

- Remove `replacementConstraints` field
- `TrustPipeline` no longer passes `replacementConstraints` to the fetch map; all keys
  fetched without constraint (or with null)

## Tests affected

`replace_semantics_test.dart` — both tests are specifically about revokeAt-with-token
semantics. Both are eliminated.

`trust_algorithm_test.dart` — the "garbage revokeAt token" test (line ~227) becomes
irrelevant; remove or simplify. Tests that already use `kSinceAlways` are unaffected.

Other tests: search for `revokeAt` with non-null, non-kSinceAlways values on replace
(not delegate) statements and remove/simplify.

## SimpsonsDemo

`simpsons_demo.dart` line 88: Homer's key replacement uses `revokeAt: s2.token`.
Change to `revokeAt: kSinceAlways` (or omit revokeAt, depending on the new default).

`simpsons.dart` lines 42 and 48: same fix.

After updating SimpsonsDemo, re-run on prod and save the new `web/common/data/demoData.js`.

## Things to consider before proceeding

**Prod data with revokeAt = <token T>**: Any real ONE-OF-US.NET users who used the V1
app and have replace statements with specific tokens will have their old key's statements
fully revoked rather than partially preserved. Their effective trust network in the
Nerdster changes. This is probably fine (they've since restated what they care about),
but worth being aware of.

**Delegate revokeAt is untouched**: `delegate_revocation_test.dart` tests revokeAt on
delegate statements — those stay as-is.

**Display code**: `key_info_view.dart` references `revokeAt` — may need updating for
display purposes after the model change.
