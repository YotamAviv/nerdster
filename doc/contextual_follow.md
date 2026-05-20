# Contextual Follow & Tag-Based Discovery

# Status

Documented what we currently do (follow contexts, content tags).
Documented what the dream is.
Explored some ideas for data model and UI. But nothing's settled or even attractive so far.

## The Dream

Click "news" or "sports" or "econ" and see content about those subjects — with the
scope broadened by context relations in your network — rated by people whose
opinions on those topics you should care about. That includes people you know
directly, but also people you've never heard of who are respected in that community
because someone you trust for that topic trusts them transitively.

No central authority decides who the bbq experts are or that "bbq" and "grilling"
are the same thing. The network self-selects and self-organizes.

---

## What We Already Have

### Hashtags (display filter only)

Tags are extracted from comment text (`#bbq`, `#news`, `#sports`). The Tags
dropdown in the feed filters display — only subjects tagged with the selected tag
are shown. The follow network does not change when you pick a tag.

### Follow Contexts (network filter only)

Follow statements have a `contexts` field — an arbitrary string → weight map.
Example: `{"<nerdster>": 1, "sports": 1}`. The Context selector switches which context
is used to build your follow network. When you select "sports", only follow statements
with a positive "sports" weight contribute to your network. Contextual follow is
transitive: if you follow Ken for "sports", you follow Ken's "sports" network too, and
so on. Popular context names from your network are surfaced dynamically in the
Context selector.

### The Equivalence System (for subjects today)

The Equivalence system (`equivalence.dart`) is a union-find structure that groups
tokens together. It supports:
- `a→b`: A and B are equivalent (merge their groups)
- `A ≠ B`: explicit DONT — these must never be merged, even if others say they should
- Transitive merging: if a→b and b→c then a→b→c
- DONTs propagate when groups merge — contradictions are rejected

This is computed per-PoV from the EquateStatements of people in your network.
Currently it applies to subjects (content items). 

---

## The Core Weakness

Context names are exact strings. If you follow Ken for "econ" and Ken follows
someone for "economics", that person is invisible to your "econ" network — different
namespace, no connection.

---

## The Idea: Apply Equivalence to Contexts, Tags

Extend the Equivalence system to context name strings. Users can declare:

- `"econ"→"economics"` — they're the same context
- `"econ"→"politics"` — someone else's opinion that these are related
- `"econ" ≠ "politics"` — someone else's explicit separation

These statements are aggregated from your follow network per-PoV, exactly like
subject equivalences today. When you browse "econ", the system first resolves its
equivalence group (which might include "economics", "finance", depending on your
network's statements), then builds the follow network from all context names in that
group.

Ken says `econ→economics`: people who follow Ken see those as the same context.
Someone says `econ ≠ politics`: that DONT prevents the merge in the views of people
who follow them. The result is decentralized and network-specific — different PoVs
can have different context topologies.

---

## Tags and Contexts currently not related / connected

Hashtags (display filter) and follow contexts (network filter) are independent
controls today. Clicking "#sports" in the Tags dropdown doesn't activate the "sports"
follow network. Whether and how to connect these is an open design question.

---

## One Namespace, Two Kinds of Context

The human observation: "If I follow Hillel as 'family', folks he follows for family
are probably in my family. But I'm unlikely to tag an article as 'family' — or maybe
I would. Sometimes I just want to see everything my family posts, even if it's not
about family."

This exposes a real distinction:

**Relational contexts** (family, neighbor, kayaker, woman) — the context says something
about your relationship with the *person*, not about the content they post. You follow
your family because they're family, not because they're experts in "family content".
You want to see everything they post. Filtering content by the tag `#family` would miss
the point.

**Topic contexts** (bbq, econ, ai, surf) — the context says something about what you
want to see. You follow Ken for "econ" because he knows econ. You want to see econ content
from people in your econ network. The follow context and the content tag are the same
concept.

Despite this distinction, **one namespace is the right call**. Two namespaces forces
users to understand the difference upfront, which is too much friction. In one namespace,
relational and topic contexts coexist naturally — the difference is just how the user
*chooses to use* a given context name, not a system-level category. The equivalence
system handles cross-pollination per-PoV as usual.

---

## UI Analysis and Suggestions

The current UI encodes a hidden assumption: contexts and tags are separate things.

**Current state:**
- The **Context selector** is prominent (top of feed). Selecting a context is the
  primary act — it changes who you're listening to.
- The **Tags dropdown** is buried in the filters menu. Clicking a `#hashtag` in a
  comment activates the tags filter but does *not* change the follow network.
- These two controls share no connection despite operating over what should be one namespace.

**The problem:** clicking `#econ` in a comment should ideally do what clicking "econ" in
the context selector does — bring in the right people AND show the right content. But
today it only does the latter half.

**Proposed direction: hashtag clicks drive the full experience**

When a user taps `#econ` in a comment, they're expressing interest in that topic. The
system should respond fully:
1. Switch the follow context to "econ" (broaden the network to econ-trusted people)
2. Filter content to `#econ` tagged items

For **relational contexts** (family, neighbor), the content-filter half is usually
unwanted — you want *all* content from those people, not just posts tagged `#family`.
A simple per-context toggle — "also filter content by this tag" — lets the user
decide.

**What changes:**

- `#hashtag` links in comments become the primary discovery entry point. Tapping one
  activates the matching follow context (if one exists in the network) and sets the
  content filter. The experience becomes: "I saw this tag, I want to go deeper."
- The **Context selector** stays prominent but is now also reachable via hashtag taps.
  It remains useful for switching between saved/named views (family, work, econ) directly.
- The **Tags filter** in the menu can be simplified or removed — it becomes a secondary
  control for users who want to filter content within an already-active context without
  changing the network.
- Tags that have an associated follow context in your network could be visually
  distinguished (e.g., a small network icon next to `#econ` in comments), so users
  know a tap will also shift the network, not just filter.

**Summary:** make hashtag taps the unified entry point into topic-scoped browsing.
The context selector becomes the place you *name and manage* your lenses; hashtag
taps are how you *discover and enter* them organically from content.



- What's the right UI for declaring context equivalences? Some options:

  - **Link icon in the Tags dropdown**: select two (or more) tags and click a link
    icon, bringing up a dialog like RelateDialog. Produces a signed, published
    equivalence statement.

  - **Drag to group**: drag one tag onto another to declare them equivalent.
    Expand a grouped tag to see its members. Drag a tag out of a group to separate
    it.

  In either case, equivalences are signed statements published to the network.
  The canonical/equivalent relationship is computed per-PoV by the Equivalence
  system (or a reimplementation of it applied to context names). If Andrew says
  "cycling" is canonical for "bikes" but Eric says "bikes" is unrelated to
  "cycling" (or that "bikes" is the canonical one), each person sees the
  aggregation from their own PoV based on who they follow.

# Plan

## Do nothing to connect tags to contexts.
The dream might be to use your science network to read about mRNA vaccinces but not to have an mRNA group.
So, pick a follow network, and maybe narrow down your feed using a tag.

## Improve the UI:
- ContentType dropdown: as narrow as the icon only
- Sort dropdown: See what we have and shoot for icons:
  - calendar icon? for recent activity
  - thumb ups icon for net likes
  - comment icon for most comments

### New drag n' drop widget for manipulating equivalence groups.
- drag A onto / into B to state A is equivalent of canonical B.
- expand B to see its equivalents
  - click "x" to state that an element does not belong in this EG (A is not equivalent of canonical B).
  - don't allow dragging canonicals inside an expanded EG.  
To be used by:
- tags dropdown
- context dropdown
Using it will issue new equate / not-equate statements for these

# Tags and Contexts can be equated

## Tags first

The old code trying to relate or do something fancy with tags is broken and old. I think that it based itself on that if a subject is tagged with more than one tag then those are somehow related. Remove all that first.

Use the new drag and drop equivalence dropdown widget.

State tag relation in a new statement type.
{
  "statement": "org.nerdster.equivalence",
  "time": "2025-04-08T20:43:40.229Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
  },
  "equate": "cycling",
  "with": {
    "otherSubject": "bikes"
    }
  },
  "previous": "e728467a5466fd2d41eb571aa6251b0c1fcb280f",
  "signature": "ff16d7c564c37eb367c5c7c28562d08fd4f5ecb5805a35cc335e971447c8b0ebea8ca145db02bf5fc0a4b5017dcffe3093e67c37f7d1bad5059fc631641b2503"
}

Compute tag Equivalence and use the tags filter to fitler for content matching canonical and equivalent tags.

### Statement type: `org.nerdster.equivalence`

Covers both tags and contexts — same namespace, one statement type.

JSON reuses the `equate` / `with.otherSubject` field names from content equate statements but
holds plain strings instead of content key objects. This is already precedented (dismiss/censor
use `rate` with a token). Concern to keep in mind: tooling that assumes `equate`/`otherSubject`
holds a content key object would misread these. Since this is a separate statement type with its
own parser the concern is isolated.

A dontEquate statement uses `dontEquate` as the field name instead of `equate`, consistent with
how `ContentVerb.dontEquate` already works in content statements.

Uses the same `previous` chain as all other statements from that key.

### Requirements

- User can state A→B (A is equivalent to canonical B).
- User can state A≠B.
- User can clear any of their own statements.
- User can see all statements — their own and everyone they follow — that involve a given string.

### UI

**Drag to state A→B**: drag A onto B's row in the dropdown using the drag handle (⠿).
The overlay stays open after the drop; the active filter updates only if the dragged tag
was the active filter (it just became non-canonical, so advance to the new canonical).

**≠ on an expanded member**: tapping it states A≠B. One action, one meaning.
The overlay stays open. No filter change.

**Crypto shield**: shown only on canonical rows that have at least one equivalent (i.e., the
tag is the head of a real equivalence group, not a solo canonical). Tapping opens the provenance
dialog for the whole group.

**Provenance dialog**: shows all `org.nerdster.equivalence` statements involving any tag in the
equivalence group — both equate and dontEquate, from everyone in the follow network. The list
covers the full group because transitive chains (A→B→C) require seeing multiple statements to
understand why A appears under C. Clearing your own statements is done here (not yet implemented).

Design note: the dialog shows raw JSON statements for now. The target is network-ordered display
with signer identity visible (like statement tiles on content cards), plus a "clear my statement"
action. That requires a `TagProvenanceDialog` widget analogous to the rating history section.

### What populates the dropdown

Only strings that appear as tags in the current feed. Strings that exist only as equivalence
targets (not tags on visible content) still appear if they are a canonical whose members do
appear as tags.

Equivalence rule for the demo: every `doEquate` must reference tags that actually appear in
comments; `dontEquate` must only counter an equate that already exists from someone in the
network (otherwise it is vacuous and confusing).

### Computation

Walk `org.nerdster.equivalence` statements from the current follow network alongside the existing
content walk. Feed them into an `Equivalence` instance using the same network/PoV as content.

`tagEquivalenceStatements: Map<String, List<EquivalenceStatement>>` — for each tag, all
statements in the network that mention it (as either field). Used to build the provenance dialog
for the whole group without re-walking the network.

When the tag filter is set to a canonical string, resolve its full `EquivalenceGroup.all` and
show content tagged with any member of that group.

### Implementation sequence

1. Remove old broken tag-relation code. ✅
2. Define `EquivalenceStatement` parser class for `org.nerdster.equivalence`. ✅
3. Collect and compute equivalence groups in the feed pipeline. ✅
4. Expand the tag filter to resolve equivalence groups. ✅
5. Wire `eq_dropdown` into the tags filter (read-only first — shows computed groups). ✅
6. Wire publishing: drag-drop and ≠ actions issue signed statements. ✅
7. Crypto shield + provenance dialog. ✅ (shield on canonical; dialog shows full group statements;
   full provenance dialog with network order + clear action is still pending)

Contexts follow the same path (steps 2–7 again), same statement type, same computation.

### Statement fetching

`statement_fetcher.js` uses an omit list — new types are included by default, so
`org.nerdster.equivalence` statements are fetched alongside content statements automatically.
Both are needed when building the feed for a PoV.

On the client, the existing fetch channel is typed to `ContentStatement`. The new
`EquivalenceStatement` needs its own parser registered so that `org.nerdster.equivalence`
statements are routed correctly rather than ignored or failing silently.

### Tests

Unit tests:
- `EquivalenceStatement` parses equate and dontEquate JSON correctly.
- `EquivalenceStatement` with unknown fields doesn't crash.
- Tag filter with equivalence group returns content for all members, not just the canonical.
- Tag filter with no equivalence statements behaves as before.

Integration tests:
- Two users in a follow network: one states A→B, PoV selects A as filter, sees content tagged B.
- One user states A→B, another states A≠B; PoV following both sees the conflict resolved correctly.
- Clear via provenance dialog removes the statement; recomputed feed reflects the change.

More tests will be added as implementation uncovers edge cases.

## Contexts next

TBD...

### Change and simplify NodeDetails UI especially for following

I'm thinking about an interface where you have a Follow half on the left and Block half on the
right and you can drag n' drop contexts to either or to a Neutral area to remove in addition to
dragging contexts onto each other to equate them.

## Open

### Which network to use to compute the context equivalence groups?
The result of the computation affects the group. Probably best to keep it simple and just use the
identity network (saves computing the <nerdster> network, which would be my first choice).

