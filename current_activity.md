# Current Activity: V2 Rewrite

## NOTES FOR ME - DON'T START WITHOUT ME

Bugs:
- Rate dialog thumb down is green, not like what's on content view. Unify.
- I disliked a rating
  - eneded up with a high level statement in the content view
  - it isn't clear that my dislike did something, or what it did at all.
  - I shouldn't be allowed to censor my own statements, I don't believe. I should just claer them.
  - I think the easiest way to clear this up is to remove the bunch of icons and just have a single REACT icon.
- Submit
  - Verify URLs some

- filter/sort content 
  - filter by type: recipe, video, article, ..
  - sort by: recent activity
  - sort by: most activity (not just comments)

- Use same network choices for Content and Graph View

- Equate, relate
  Requirements doc:
  - use my equivalence algorithm implementation to reduce
  - show equated/related subjects, TODO: Where? How?.
  - ratings on equated subjects to be shown under the canonical
  - allow users to equate/relate and not as well

- Make sure fetcher push is transactional [DONE in V2 via StatementWriter]

  - Consider integration test [DONE: v2_basic_test.dart covers this]

- Crypto proofs

  - Similar to JsonQrDisplay, interpreted
  - maybe explain: Statement signed by...

- Show Path(s) from PoV on other users, delegate keys

- allow change how I follow/block

- Make link to this view work

- My delegate statements should always be fetched and cached even when I'm not in the network being displayed (I'm not PoV, and I'm not in PoV's network (for this context)).
This is to show if I've already liked, what my existing comment was, etc... 
regression test, integration test.

- Notifications
  - Reach goal: Recommended actions, warnings

- embed in home page and on aviv.net

- transactions
The "Gold Standard" Solution
If you want the best of both worlds—no update permissions for anyone AND guaranteed atomic writes for you—the logic must move to a Cloud Function.
Rules: You set Firestore to read: true and create: false, update: false, delete: false. No one can write directly.
Function: You create a pushStatement Cloud Function.
Security: The Function uses your public key to verify the signature before it touches the database.
Atomicity: Because it's running on the server, it can use the Admin SDK to query for the latest statement inside a transaction, verify the new one, and write it—all without needing a mutable head pointer or granting update permissions to the world.


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
