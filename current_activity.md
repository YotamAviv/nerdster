# Current Activity: V2 Rewrite

## NOTES FOR ME - DON'T START WITHOUT ME

- relating statements

I used the app to relate 2 Bart's relate statement on El Barto and Marge's dontRelate statement on El Barto. This is what I see in LGTM:

I was expecting JSON subjects, not tokens.
After the statement took effect, I saw that Lisa related the statement to 8 digits of gibberish.
Clacker looked into it had started working on it, but I stopped it.

I should think about relating statements.



- Submit
  - Verify URLs some

- follow

- uniform bar/controlls for graph and content views, maybe..

- upgrade related tags
  - don't sort
  - use equivalence tech

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
