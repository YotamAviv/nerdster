
# ..

# Nice ones:
```
tar -czf ~/backups/nerdster.git.`date2`.tgz .git
git tag PROD-v`date2`
code $(git diff --no-commit-id --name-only -r HEAD) -r
diff -r lib/oneofus ~/AndroidStudioProjects/oneofus2/lib/oneofus
diff -r ~/AndroidStudioProjects/oneofus2/lib/oneofus lib/oneofus
git reflog expire --all --expire=now
git gc --prune=now --aggressive
flutter clean
flutter pub get
flutter pub upgrade --major-versions
flutter test
flutter run -d chrome
```

```
Push to PROD:
flutter build web; firebase deploy --except functions
(flutter clean; flutter build web; firebase deploy)
firebase init hosting # Answer: build/web

add to .bashrc:
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

Plan:
FIXED? (BUG: Comp deadlock bug, various manifestations.)
BUG: I noticed that when Fetcher asserts false, it gets lost, not progpagated.


TODO: Lowercase: tags, follow contexts, domains (on phone).

BUG: Was severe, I commented out the assert, but there's still a bug, probably.
     Delete (clear) delegate on phone and can't sign in with saved credentials, crash, ....
TODO: Look into if we verify 'nerdster.org'
BUG: revoke delegate key statement described as delegated ignoring the revoked part.
BUG: Revoked delegate says 'replaced'.

TODO: Phone: Add a TODO(5): to save last statement tokens for each of your
  active keys (for revoking in case of compromised keys)

TODO: Warn about comments on comments
Re: comment on comment bug, it's actually a feature, educate instead
of fixing... A reaction (eg. comment) can be deleted, even if it's
just changed, then the old one is deleted(replaced). A book or a movie
can't be deleted ..
TODO: Use cookies
(https://stackoverflow.com/questions/71989527/is-there-a-way-to-create-and-read-cookies-in-flutter-web)
to 'Got it; don't show again.'
TODO: Linky in comment text.

TODO: Warn when signing in with non-matching delegate/Oneofus keys.

Sign in menu upgrade:
- bigger is okay, colors, bold, ...
- move copy/paste to DEV menu
- clean up 'data corruption' in Nerdster that dumps all entries by
  order regardless of data corruption that Fetcher detects.


CONSIDER: Embrace the key strikethrough icon. Use the red key for revoked maybe.

* X makes comment Cx on topic T
  Y responds with commnt Cy to comment Cx
  X changes his comment from Cx to Cx'
  Now Y's comment Cy on Cx is lost because Cx is obscured (cleared) by Cx'
  
- Dismiss not working for related:
  I dismissed the 'disinformation playbook' entry on PROD
- I see 'clear' statements.

- NerdTree solid
  - DO: test! (now that we have better than dump !minimalist)
  - paths
  - names
  - replaced/blocked nerds pink/red
  - replaced/blocked keys pink/red
  - revoked delegate
    - Include a revoked delegate in the tests and show properly in NerdTree.
      Progress: Hipster has a revoked delegate key, but the display could be
        improved:
        - says 'replaced', not 'revoked'.
        - (name, comment), and I'm not sure that it's in the tests.

- Firebase clarity: Nerdster/Oneofus 

- notifications...

- prefs menu
  - respect my dismiss, center's dismiss, or not at all
  - show DEV menu

- stress, performance.. more nerds, more trusts and blocks.
  - check where I'm spending time
    - reducing network at end?
  - limit number of paths to store per node?
  - limit path length?
  - limit time?

- hosted with me at center by default somehow, kludgey, hard-coded okay.

Phone:
- app names stored locally, no private comment
- trust management from phone, with recipe explanations
  - DONE: clear trust/block/delegate...
  - replace Oneofus key
    - create new key and state the replace
    - create text to email associates to trust new key and clear trust in old key (defer invitations)
    - ask about the delegate key..
    - delete old key from phone storage and call it 'destroyed'.
  - replace delegate Nerdster key
    - create new key and state the replace
    - trust new key and clear trust in old key
    - delete old key from phone storage and call it 'destroyed'.
  
- import/export on phone to Recipe with explanations




** Firebase emulators
- oneofus-nerdster.firebase.json
This file seems to be for running the one-of-us-net Firebase project emulator form the 'nerdster' directory.
The sequence seems to be:
aviv@aviv-Venus-series:~/src/nerdster$ firebase --project=nerdster emulators:start
aviv@aviv-Venus-series:~/src/nerdster$ firebase --project=one-of-us-net --config=oneofus-nerdster.firebase.json emulators:start
TODO: probably rename nerdster:oneofus-nerdster.firebase.json to oneofus.firebase.json
TODO: look into what oneofus:firebase.json is for; maybe change its emulator default to match the other.
NOTE: The Android Firebase stuff seems to cache on the Android device
(or emulator), and so even though deleting data or restarting the
emulator do delete the data, the Android Firebase stuff still finds
cached, deleted data.

** common code: lib/oneofus
Git submodules?
Flutter package?

## follow nerds

# Crypto
https://pub.dev/packages/encrypt
## Crypto RSA?
https://github.com/w3c/did-spec-registries/pull/20
https://github.com/w3c/did-core/issues/240
https://github.com/leocavalcante/encrypt/blob/5.x/example/rsa.dart


## slider for network visualization?

## Embed in aviv.net
see: https://docs.flutter.dev/deployment/web

### All statements on this page
They're completely portable and trusted.
Each one is digitally signed using the private key of its author.
Authors (people) distribute their public keys (the ones that match their private keys) using the network. Folks sign each others' public keys using their private keys to create a distributed, heterogeneous web of trust.

## code labels:
  - TEMP
  - BUG
  - FIX
  - NEXT
  - TODO
  - IMPROVE
  - DEFER ;)

