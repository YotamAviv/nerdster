# Block Identity from Nerdster

Entry point: **NodeDetails** → red `Icons.delete_outline` `IconButton` in `_buildActions()` (not shown for own identity).

## Motivation: the Apple App Store. Conclusion: Philosophy Unfit.

As I was planning this feature, it became apparent that:
- You might see people you've blocked when viewing from different PoVs.
- We allow censoring censorship.
- We allow ignoring censorship.

The Nerdster is philosophically unfit for the Apple App Store.

Possible remdial measures (Store Apps only):
- Restrict PoV's identity network to an intersection with your own
  (combione that with permissiveness, distance, and we get quagmire)
- Don't allow ignoring censorship.
- (Can't censor censorship when you can't even see it)

the Apple App Store may be philosophically unfit for me.

---

## Two Layers

| Layer | Signed by | Nerdster alone? |
|---|---|---|
| Affinity (follow/block per context) | Delegate key | ✅ Yes |
| Identity trust (vouch/block) | Identity key | ❌ Needs ONE-OF-US |

---

## Options (soft → hard)

**A. Stop seeing their content** — block for `<nerdster>` context (or all contexts).  
Delegate key only. Nerdster publishes directly. Reversible.  
*Note: per-context blocking already exists in NodeDetails via the Follow/Neutral/Block segmented control. This new button is a shortcut that applies the block immediately without expanding that section.*

**B. Clear your vouch** *(only shown if you directly vouch for them)*  
Trust-layer action → hands off to ONE-OF-US. Softer than a full block.

**C. Block this identity everywhere** *(harsh)*  
Trust-layer block → hands off to ONE-OF-US. Show a warning first:
> *Blocking removes this person from your network everywhere, not just Nerdster.*

---

## Design Notes

### PoV vs. personal statements
The active PoV determines whose trust graph is used, but your own personal trust statements
are yours regardless of PoV. NodeDetails, like RateDialog, always surfaces your own statements —
so showing "you've blocked this key" in NodeDetails is meaningful even when browsing from
someone else's PoV.

### Blocking from Nerdster makes sense; vouching from Nerdster does not
Vouching (trust) is an in-person, real-world action: you meet someone, scan their phone, and certify they're a real human. Encouraging vouching based on Nerdster content is absolutely wrong.

Blocking, however, is appropriate here: you're identifying what is probably not a real person at all — a bad-faith actor posting content — and removing them from your network. 
Meeting them in person to scan their phone makes no sense.

---

## Handoff to ONE-OF-US.NET (Options B and C)

Same pattern as sign-in (`https://one-of-us.net/sign-in?parameters=<base64>`):

```
https://one-of-us.net/block?key=<identityToken>   # Option C
https://one-of-us.net/clear?key=<identityToken>   # Option B
```

- **App installed**: universal link opens ONE-OF-US with key pre-loaded. No scanning needed.
- **App not installed**: web page explains the action, shows App Store / Play Store links.

### Changes required in oneofusv22
- Add `/block` and `/clear` routes to the web app (similar to `/sign-in`).
- ONE-OF-US mobile app handles the deep links and pre-populates the confirmation screen.

---

## NodeDetails Changes (Nerdster)

- Add red `Icons.delete_outline` `IconButton` to `_buildActions()`.
- Only show when the viewed identity is not the current user's own identity.
- Determine at open time:
  - Does the user directly vouch for this key? → show Option B
  - Has the user already trust-layer-blocked this key? → show a visual indicator on the button
  - *Implementation note: `tg.edges[myIdentity]` is wrong for two reasons: (1) it's only populated if the current user is reachable from the active PoV's BFS; (2) even when populated, it reflects the PoV's filtered view — e.g. if I vouch for Bart but the PoV blocked Bart, that vouch won't appear. Need a `myTrustStatements` map loaded directly from the current user's identity-key statements, independent of any PoV (analogous to `myLiteralStatements` for content).*

##


Add UI to NodeDetails to simply see my own (signed in user (signInState.identity), not PoV) existing block or trust.
This is the new myLiteralStatements for trust referred to above - the identity's own trust statements.
Show a shield icon at the bottom left of the NodeDetails card if I have a block or trust statement for this identity;
clicking on it shows the Json of that statement in one of our standard widgets to that I can toggle interpreted or not.


Add UI to block, clear.
- Track how the user signed in (keymeid://, https://one-of-us.net, scan QR, or paste)
At the bottom left of NodeDetails to the right of the shied icon, add these:
- check icon (to trust). Make it filled in solid green if I trust this key, outlined otherwise.
- trash can icon (to block) like the censor icon on RateDialog. Make it filled in solid red if I block this key, outlined otherwise.
- X icon (to clear my trust or block) similar to clear on Rate dialog. Show only if I have a trust or block statement for this key.
Clicking block or clear (when filled in and enabled) "pass the intention" to to the ONE-OF-US.NET app.
Clicking trust (when filled in and enabled) should show an alert dialog explaing that you vouch in person or through another means of secure communication, not because you believe that it's them on the Nerdster.
* pass the intention
If signed in by scanning QR or paste, then show the key in a dialog and explain what to do.
If signed in using keymeid://, https://one-of-us.net then create the new link discussed for the user to click on.



If we don't have a
- On the NodeDetails add a block icon if the key represented 


## Implementation plan: myTrustStatements

Goal: make the signed-in user's own trust statements available on `FeedModel`, independent of the active PoV — analogous to `myLiteralStatements` for content.

### 1. `TrustPipeline.build()` — add optional `signerIdentity` parameter

```dart
Future<TrustGraph> build(IdentityKey povIdentity, {IdentityKey? signerIdentity}) async {
```

At depth=0, if `signerIdentity != null && signerIdentity != povIdentity`, add it to the initial `fetchMap` alongside the PoV key. Since `source.fetch(fetchMap)` is a single batched call, this is no extra round trip.

After the first `source.fetch()`, extract raw statements for `signerIdentity` from `newStatementsMap`. Filter out `clear` statements (clear = invisible). Store as a field on the returned `TrustGraph`.

```dart
// TODO: replace chains are not chased for myTrustStatements.
// If the signer's identity has been replaced, only statements from the
// current signInState.identity key are included, not from prior keys.
```

### 2. `TrustGraph` — add `myTrustStatements` field

```dart
final List<TrustStatement> myTrustStatements; // statements from signerIdentity, clear-filtered
```

### 3. `FeedController` — pass `signerIdentity`

When building the trust pipeline, pass `IdentityKey(signInState.identity)` as `signerIdentity` when it differs from the PoV.

Also: the existing fallback at lines 372–380 (`mePipeline.build(currentMeIdentity)`) is related but not the same thing — it builds a full BFS from Me to find delegate keys (`TrustVerb.delegate`). `myTrustStatements` is simpler: just Me's raw first-degree `trust`/`block` statements, taken directly from `statementsByIssuer[signerIdentity]` after the first depth=0 fetch — no BFS from Me needed. Pre-fetching Me at depth=0 means the `mePipeline` source call would also be a cache hit, which is a nice side effect.

### 4. `FeedModel` — expose `myTrustStatements`

Store the list from `graph.myTrustStatements` on `FeedModel`, keyed by subject for fast lookup:

```dart
final Map<IdentityKey, TrustStatement> myTrustStatements; // latest effective statement per subject
```

Singular Disposition applies: if multiple statements exist for the same subject, keep only the latest.

### 5. NodeDetails — consume it

```dart
final myStmt = model.myTrustStatements[canonicalIdentity];
// myStmt?.verb == TrustVerb.trust  → show Option B
// myStmt?.verb == TrustVerb.block  → show visual indicator on delete button
// myStmt == null                   → no indicator
```

---

## Open Questions

1. **"Block for all contexts" (Option A variant)**: One tap blocks across every context the user follows, not just `<nerdster>`. In scope?
2. **ONE-OF-US implementation**: The `/block` and `/clear` deep link routes need to be built in oneofusv22 and the ONE-OF-US mobile app. Separate ticket or included here?
