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
- Determine at open time (from `tg.edges[myIdentity]`):
  - Does the user directly vouch for this key? → show Option B
  - Has the user already trust-layer-blocked this key? → show a visual indicator on the button
  - *Implementation note: when browsing from a different PoV where the current user is not in that PoV's trust network, `tg.edges[myIdentity]` may not be populated. May need to load the current user's own trust statements separately, similar to how `myLiteralStatements` works for content.*

---

## Open Questions

1. **"Block for all contexts" (Option A variant)**: One tap blocks across every context the user follows, not just `<nerdster>`. In scope?
2. **ONE-OF-US implementation**: The `/block` and `/clear` deep link routes need to be built in oneofusv22 and the ONE-OF-US mobile app. Separate ticket or included here?
