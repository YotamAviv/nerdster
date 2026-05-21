# TODO

# Tags continuation

## UI:
- When the screen is narrow, the dropdown and shield are off view. Get them in view.
- When I want to drag and drop one tag to another, the target can be off view due to scrolling. Make it so that as I reach the ends the list starts to scroll to help me reach it.

## BUGS
- With &lgtm=true, I don't see the FYI dialog.
This should be the case for all statements.
AI: When you address this, see if it can be done in a general way, but don't force it if it's a lot of work.

## Relate as well as Equate
Semantically, if I relate A to B then that's symmetric; there is no canonical/equivalent.
In case we use an Equivalence object, then both will end up in the same EG and that's all we care about.

Option A: Use the existing Equivalence computation:
This would be done with another instance of the Equivalence object for relate statements.
Use the same verbs that ContentStatement uses:
        verb == ContentVerb.equate ||
        verb == ContentVerb.dontEquate ||
        verb == ContentVerb.relate ||
        verb == ContentVerb.dontRelate ||
Pros:
- it exists
Cons:
- we always follow all relations until there are more (can't limit only 2 relations away)

Option B: Use a new, ad-hoc, computation:
Pros:
- we'll be able to limit how many depth of related we follow. 
Cons:
- need to implement it (but seems straight forward)

AI: A or B? What do you think?

Relate will be expressed using an EquivalenceStatement as well (although we might rename the class and the statement), and so if a user says:
  A is canonical of B
and then says:
  A is related to B (or even: B is related to A)
then the latter statement hides former (single disposition, distincter...)

When we show the dropdown choices:
- do not show equivalent tags as top level choices in the dropdown.
- In case A is related to B, show both A and B as top level choices in the dropdown.
- Expanding a top level choice should show all equivalents and related choices.

Display
- related children: light green
  - show "!~" to state that they're not related.
- equivalent children: light red
  - show a "!=" to state that they're not equivalent.

- Do allow choosing a child choice (tag) in case I want to specifcally filter for that choice even though it might be an equivalent.

Action:
When a user drags tagA onto tagB, present a dialog
"State that A is related B"
and have a checkbox labled: "A is an equivalent of B"
Then either state relate or equate.


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
