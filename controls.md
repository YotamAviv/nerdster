
# Goal:
Look cleaner, more modern
Work on phone, leave space for content

## Current controls:
menu
- sign in / out, in a variety of ways: magic, qr scan, copy/paste
- settings
  - toggle censorship
  - toggle showCrypto
- share link for this view
- /etc
  - sign demo
  - verify demo
- about dialog

permanent
- submit
- refresh

network bar
- PoV
- context
- confidence

filters drawer
- sort order
- type filter
- tag dropdown
- diss setting
- censor toggle



# New direction:

## New sign-in icon widget and options

Visually display signed in state:
- "signed in" only for identity (but no delegate key)
- signed in with identity and delegate key

Clicking on the widget brings up a comprehensive dialog (or screen, possibly full screen on phone)
- show current signed in state
  - Identity: green key, click to see key
  - Delegate: blue key, click to see key (if signed in with delegate, otherwise show that we don't have your delegate key)
  This replaces the show credentials business
- allow 3 methods to sign in
  - Show QR sign-in parameters for scanning
  - Custom URL Schemes (The "Magic" Link) keymeid://signin?parameters=<sign in parameters>
  - copy/paste sign in
  all accept either identity or identity and delegate

Place this new icon widget on the network bar far right

## other changes for phone
- no graph
- (considering) <nerdster> context fixed

## tech
If these are all widgets (possibly named), it'd be nice to shuffle them around using const List<string> and such.

## controls
- no menu
- controls are on the page to leave more room for content, maybe allow pinning them
- checkboxes, not sliders
- 

permanent:
- sign in / out and indicator (states: no idea who you are, have identity, have delegate)
- submit
- refresh
- (considering) show content drawer?
- (considering) show advanced network drawer?
- (considering) show esoteric drawer (/etc)? (sign, verify/tokenize, create link, about)

Next
- PoV
- context


esoteric
- confidence
- 

Deeper code changes:
- when not signed in, make that clear - no identity, not "No content found"
