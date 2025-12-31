# Current Activity: V2 Rewrite


NOT LIKE DOC:
- Remove PoV icons everywhere

- Collapsible sections

- Use icons instead of words

- BUG: I equated to <token>

- BUG: I see related to El Barto regardless of if I'm looking at Art or El Barto 
{
  "time": "12/31/2025 3:06 AM",
  "I": "Lisa@nerdster.org",
  "relate": {
    "contentType": "resource",
    "title": "Art",
    "url": "https://en.wikipedia.org/wiki/Art"
  },
  "with": {
    "otherSubject": {
      "contentType": "resource",
      "title": "El Barto",
      "url": "https://simpsons.fandom.com/wiki/El_Barto"
    }
  }
}


Bugs:
- [x] Rate dialog thumb down is green, not like what's on content view. Unify.
- trying to rate while not signed in fails silently. The user should be alerted that he's not signed in early.
- I see content I've dismissed.
- [x] I disliked a rating
  - [x] eneded up with a high level statement in the content view
  - it isn't clear that my dislike did something, or what it did at all.
  - I shouldn't be encouraged to censor my own statements; I can just clear them instead.
  - I think the easiest way to clear this up is to remove the bunch of icons and just have a single REACT icon.

- Equate, relate
  Requirements doc:
  - Use my legacy equivalence algorithm (legacy equivalence.dart) to reduce equivalences, possibly relations as well.
  - show equivalent and related subjects in the UI somehow, TODO: Where? How?.
    - show the statements that related and equated those somewhere as well.
  - Include ratings on equivalent subjects as being about the canonical subject. that's the whole point.
  - allow users to state   relate, dontRelate, equate, dontEquate using the UI.



## NOTES FOR ME - DON'T START WITHOUT ME

- upgrade related tags
  - don't sort
  - use equivalence tech

- Submit
  - Verify URLs some

- filter/sort content 
  - filter by type: recipe, video, article, ..
  - sort by: recent activity
  - sort by: most activity (not just comments)

- Use same network choices for Content and Graph View

- Crypto proofs

  - Similar to JsonQrDisplay, interpreted
  - maybe explain: Statement signed by...

- Show Path(s) from PoV on other users, delegate keys

- allow change how I follow/block

- Make link to this view work

- Notifications
  - Reach goal: Recommended actions, warnings

- embed in home page and on aviv.net


## NerdyContentView

- [x] Document requirements in `docs/v2_nerdy_content_view_spec.md`
- [ ] consider UI testing
- [x] implement (Stable with Multi-View Routing)

## Multi-View Routing & Navigation

- [x] Implement path-based routing in `app.dart`
- [x] Add "Views" menu to `NerdsterMenu`
- [x] Restore legacy views (`ContentTree`, `NetTreeView`)
- [x] Link V2 Feed to V2 Trust Tree and Graph

## Follow Network & Content Aggregation (V2)

- [x] Document requirements in `docs/follow_net_specification.md`
- [x] Implement V2 `FollowNetwork` logic (Stable)
- [x] Implement V2 `ContentAggregator` logic (Stable)
- [x] Port and expand tests to V2 (36 tests passing)

# Probably next - DO NOT GET STARTED.

# longer term - DO NOT GET STARTED ON THESE!

# Nerdster recommends (Have the Nerdster recommend an action)

- Nerdster recommends (Have the Nerdster recommend an action)
  - get in touch with your associate and
    - verify the key you have represents him and has not been compromised (maybe mention a specific action)
    - ask about a different key.
  - scan this key, verify that you've vouched for it
    - add 'suspect' (moves to the end of your direct trusts, hints to others)
    - add generated comment
    - clear it?
    - block it?

# Graph layout, traversal, linking, expansion...

- document this as a requirements doc (for AI)

Lay the graph out better.

- include keys dive in when crypto enabled
  Deal with hugeness:
- fade out nodes beyond 2 degrees, but highlight start of paths.
- scroll through or something when there are too many edges.
  Ditch the shadow view graph entirely.
- visualize the network
  - ideally not as a tree
    - graph that you can drag around: blue, green, red edges
      - only goes 1 or degrees out and then fades, have to change PoV to explore
  - ideally without deprecated libraries
  - ability to link to a person, key, statement
- crypto on
  - keys
  - statements
    - rejected statements
  - link to all statements
- crypto off
  - people
  - paths to them
  - names
  - long press / tooltip to see all names and paths
- actions
  - PoV
  - view/edit follow
  -

# UI regression testing

## implement in cloud

## content layer

- document censor, dismiss, relate/not, equate/not
  - tags
  - options: type, sort, tags
    - check what else..
- display it
  - not necessarily as a tree
    - ideally without deprecated libraries
  - crypto on
    - statements

## implement in cloud, Nerdster queries ONE-OF-US.NET

- estimate cost
- prototype performance

## simple view

- suitable for phones
- less feature rich

# phone rewrite

- consider showing phone interface on web
  - possibly acting as Bart, Lisa.. and affecting the embedded Nerdster
