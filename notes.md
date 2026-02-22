AI NOTE: This is my (the human) file with my own notes.

# Corrupt the database and check what happens
- Corrupt the data by:
  - deleting 1 statement from a notary chain, or 
  - modifying any value in it.

# Misc...
?fire=emulator
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22NOqGmF9lMMWEUL9lMWs0mZZM9BSybVplqvawUkLbwOs%22%20}

?identity={"crv": "Ed25519","kty": "OKP","x": "Sf-EQHCY94WB_4QFzEQWkO2SYFNTBgtfsc-Ic25oL84"}&skipVerify=false&dev=true

# Fake egosCircle
?fire=fake&demo=egosCircle
# Fake equivalenceBug
?fire=fake&demo=equivalenceBug

?fire=fake&demo=simpsonsRelateDemox 

?fire=fake&demo=simpsonsDemo

?fire=fake&demo=rateWhenNotInNetwork

# Notifications gallery
?fire=fake&demo=notificationsGallery

?fire=emulator&demo=loner

# Emulator simpsonsDemo from PROD
# Lisa
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22NOqGmF9lMMWEUL9lMWs0mZZM9BSybVplqvawUkLbwOs%22%20}
# Bart
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22DLKWtnSsw7P9ePCizuMP1Yxg5knCvT3Y7a7X7oMnxwc%22%20}

# Emulator yotam
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo%22%20}

# Nice ones:
```
flutter clean
flutter pub get
flutter pub upgrade --major-versions
flutter test
flutter run -d chrome
```

```
Push to PROD:
flutter build web --release; firebase --project=nerdster deploy --except functions
./bin/stage_nerdster.sh deploy
./bin/stage_oneofus.sh deploy
firebase --project=nerdster deploy --only functions
firebase --project=one-of-us-net deploy --only functions:export
firebase --project=one-of-us-net deploy --only functions
(flutter clean)
firebase init hosting # Answer: build/web

add to .bashrc:
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### Export PROD Firebase for use by local emulators
functions$ npm install
firebase projects:list
gcloud projects list
gcloud auth login

Run `./bin/start_emulators.sh` to start emulators in the background and log to `.log` files.
Run `./bin/start_emulators.sh --export` to first export PROD data, and then start the emulators using the new export.
Run `./bin/stop_emulators.sh` to stop them.



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

