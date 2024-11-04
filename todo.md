# Nice ones:
```
tar -czf ~/backups/nerdster.git.`date2`.tgz .git
git tag PROD-v`date2`
code $(git diff --no-commit-id --name-only -r HEAD) -r
diff -r lib/oneofus ../oneofus/lib/oneofus
diff -r ../oneofus/lib/oneofus lib/oneofus
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

# Plan:

Instruction:
- add ? help to tree regarding Oneofus trust / Nerdster follow

Default follow context
- Hmm... I want a default follow context when folks view as me.
  - (don't generate a statement every time I just browse)

UI for clear relate/equate.

## BUGS
- I noticed that when Fetcher asserts false, it gets lost, not progpagated.
- Revoked delegate says 'replaced'.
- sign in without store keys should wipe keys
- Minor: filter by book doesn filters Hillel's comment on the article he
  submitted about a book which I equated to a book

## TODO:
- Take care to warn user if he signs in oneofus/delegate keys that aren't related, are revoked, etc...
- Look into if we verify 'nerdster.org'
- Warn about comments on comments
  Re: comment on comment bug, it's actually a feature, educate instead
  of fixing... A reaction (eg. comment) can be deleted, even if it's
  just changed, then the old one is deleted(replaced). A book or a movie
  can't be deleted ..
? clean up 'data corruption' in Nerdster that dumps all entries by
  order regardless of data corruption that Fetcher detects.
- Embrace the key strikethrough icon (like replaced/blocked keys on phone). Use the red key for revoked maybe.
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

- stress, performance.. more nerds, more trusts and blocks.
  - check where I'm spending time
    - reducing network at end?
  - limit number of paths to store per node?
  - limit path length?
  - limit time?

- hosted with me at center by default somehow, kludgey, hard-coded okay.

** Firebase emulators
Run these from 'nerdster' base directory.
$ firebase --project=nerdster emulators:start
$ firebase --project=one-of-us-net --config=oneofus-nerdster.firebase.json emulators:start

## Doc
### All statements on this page
They're completely portable and trusted.
Each one is digitally signed using the private key of its author.
Authors (people) distribute their public keys (the ones that match their private keys) using the network. Folks sign each others' public keys using their private keys to create a distributed, heterogeneous web of trust.

## code labels:
These are in flux, but I've been using
- TEMP
- NEXT
- BUG
- FIX
- TODO
--- bar --- 
- TEST
- CODE
- QUESTIONABLE
- CONSIDER
- DEFER
Maybe shift to TODO1 or TODO(1) through 5 
