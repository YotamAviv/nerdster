# Continue to work on the tests and impl for the trust algorithm

- examine all of the notification types from the legacy code [DONE]
- make sure we can understand all of them [DONE]
- document them [DONE - see docs/v2_trust_specification.md]
- test them [DONE - 10 tests passing in test/v2/trust_algorithm_test.dart]
- so.. difficult scenarios.. notifications, conflicts, loops, etc.. [DONE]


- Nerdster recommends: scan this key, verify that you've vouched for it
  - add 'suspect' (moves to the end of your direct trusts, hints to others)
  - add generated comment
  - clear it?
  - block it?

# longer term

- document this as a requirements doc (for AI)
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

# longer term

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

