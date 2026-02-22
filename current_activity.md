These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation

# Current Activity:

Typical through the app:
green / blue - identity / delegate key
solid / outline: have private key, have public key only

Sign in:
- if we don't have identity, then the sign in dialog must be up. Dismiss should be disabled
- sign out means drop the delegate key
  If the user signs out, let him see that he still has an identity key and don't dismiss the dialog.
- regardless of how we sign in (scan QR, keymeid://..., paste), behavave gthe same way. when the credentials are receieved
  - show the "throw" key animatino for the appropriate key(s) (identity or both idenitty delegate)
  - laeve the dialog up

Clarity:
Add text above the buttons that these are ways to sign in.
Make the 2 keys smaller and add text describing them and whether or not we have them.



## NOTES FOR ME, THE HUMAN - DON'T START WITHOUT ME

Check: TODO, SUSPECT, BUG ..



### relating statements

I used the app to relate 2 Bart's relate statement on El Barto and Marge's dontRelate statement on El Barto. This is what I see in LGTM:

I was expecting JSON subjects, not tokens.
After the statement took effect, I saw that Lisa related the statement to 8 digits of gibberish.
Clacker looked into it had started working on it, but I stopped it.

I should think about relating statements.


### another simpsons demo for a variety of reasons.
I want to add
- reactions on reactions (comment on comment, like  on comment, comment on like, etc..)
- relations (like simpsons_relate_demo)
- plenty of subjects (like the current simpsons_demo)
- some conflicts (like the current simpsons_demo, but different)
- different  conflicts from different PoVs
- different high level data shown from different PoVs
- the ability to use it either fake or emulator and be able to sign in as any person
  I used to be able to do that when using fake using the menus, but I seem to haev lost that ability
  Having that ability when using the emulator would require exporting and saving a file with the full public/private delegate keys
- furthermore, it'd be nice to have the "script" not be a Dart program. I don't want to invent a new language and syntax. Any suggestions?

### ..

- filter/sort content 
  - sort by: most activity (not just comments)

- upgrade related tags to use equivalence tech

- Show Path(s) from PoV on other users, delegate keys (phase 2, 3 from graph doc)

- embed in home page and on aviv.net

Still thinking... ??
- diss + like = show it to me again in case of new likes, comments
  - diss + dislike = never show it to me again
  - diss (no rating) = show me in case of ???

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

## implement in cloud, Nerdster queries ONE-OF-US.NET

- estimate cost
- prototype performance

# phone rewrite

- consider showing phone interface on web
  - possibly acting as Bart, Lisa.. and affecting the embedded Nerdster
