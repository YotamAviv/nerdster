
# Run the integration tests
Run using Firebase emulators.
- DEV menu => integration test: ...
- Manually change [Prefs.skipVerify, Prefs.cloudFetchDistinct]
- (Need to refresh in between for test framework)
# Run the JavaScript tests
node js/jsonish.js
# Corrupt the database and check what happens
TODO: App won't load, no error shown. Desired would be a notification about 1 corrupt token and 
just that data missing.
- Corrupt the data by:
  - deleting 1 statement from a notary chain, or 
  - modifying any value in it.


# Emulator simpsonsDemo
?fire=emulator&oneofus=%7B%22crv%22%3A%22Ed25519%22%2C%22kty%22%3A%22OKP%22%2C%22x%22%3A%22gq5i1acRbRIRG7H9gNb3us2Zx0E2FdOj1RqGV7LZc0U%22%7D

# Nice ones:
```
git tag PROD-v`date2`
git tag PROD-11
code $(git diff --no-commit-id --name-only -r HEAD) -r
diff -r lib/oneofus ../oneofus/lib/oneofus
diff -r ../oneofus/lib/oneofus lib/oneofus
flutter clean
flutter pub get
flutter pub upgrade --major-versions
flutter test
flutter run -d chrome
tar -czf ~/backups/nerdster.git.`date2`.tgz .git
```

```
Push to PROD:
flutter build web --release; firebase --project=nerdster deploy --except functions
firebase --project=nerdster deploy --only functions
firebase --project=nerdster deploy --only functions:streamstatements
firebase --project=one-of-us-net deploy --only functions:export
firebase --project=one-of-us-net deploy --only functions
(flutter clean)
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

- net/content.. I've gotten into a state where I see net with wrong controls.

- I noticed that when Fetcher asserts false, it gets lost, not progpagated.

- Revoked delegate says 'replaced'.

- Make keys match Oneofus colors: only active Nerdster delegate should
  be dark colored.

- Minor: filter by book doesn filters Hillel's comment on the article he
  submitted about a book which I equated to a book

## TODO:

- Look into if we verify 'nerdster.org'

? clean up 'data corruption' in Nerdster that dumps all entries by
  order regardless of data corruption that Fetcher detects.

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

- stress, performance.. more nerds, more trusts and blocks.
  - check where I'm spending time
    - reducing network at end?
  - limit number of paths to store per node?
  - limit path length?
  - limit time?

## Firebase emulators
Run these from 'nerdster' base directory.
$ firebase --project=nerdster emulators:start
$ firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start

### Export PROD Firebase for use by local emulators
firebase projects:list
gcloud projects list
gcloud auth login

date2
export NOW=`date2`
# If running in 2 windows, make sure to set (export) NOW in both
export NOW=03-12-25--09-39
echo $NOW

firebase use nerdster
gcloud config set project nerdster
gcloud firestore export gs://nerdster/nerdster-$NOW
gsutil -m cp -r gs://nerdster/nerdster-$NOW exports
firebase --project=nerdster emulators:start --import exports/nerdster-$NOW/

firebase use one-of-us-net
gcloud config set project one-of-us-net
gcloud firestore export gs://one-of-us-net/oneofus-$NOW
gsutil -m cp -r gs://one-of-us-net/oneofus-$NOW exports
firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start --import exports/oneofus-$NOW/



## code labels:
These are in flux, but I've been using
- TEMP
- NEXT
- BUG
- FIX
- TODO
--- bar --- 
- WIP
- TEST
- CODE
- QUESTIONABLE
- CONSIDER
- PERFORMANCE
- DEFER
Maybe shift to TODO1 or TODO(1) through 5 
