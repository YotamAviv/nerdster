AI NOTE: This is my (the human) file with my own notes.

# Corrupt the database and check what happens
- Corrupt the data by:
  - deleting 1 statement from a notary chain, or 
  - modifying any value in it.

# Misc...
?fire=emulator
?fire=emulator&skipCredentialsDisplay
?fire=fake&demo=egosCircle&skipCredentialsDisplay
&netView=true

?identity={"crv": "Ed25519","kty": "OKP","x": "Sf-EQHCY94WB_4QFzEQWkO2SYFNTBgtfsc-Ic25oL84"}&skipVerify=false&dev=true


# Fake simpsonsRelateDemo
?fire=fake&demo=simpsonsRelateDemo&debugUseSubjectNotToken=true

# Notifications gallery
?fire=fake&demo=notificationsGallery

# Emulator simpsonsDemo from PROD
# Lisa
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22NOqGmF9lMMWEUL9lMWs0mZZM9BSybVplqvawUkLbwOs%22%20}&skipCredentials=true
# Bart
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22DLKWtnSsw7P9ePCizuMP1Yxg5knCvT3Y7a7X7oMnxwc%22%20}&skipCredentials=true


# Emulator yotam
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo%22%20}&skipCredentials=true

&skipCredentialsDisplay=true&showCrypto=true

Bart's Credentials (Delegate Key included):
{"identity":{"crv":"Ed25519","kty":"OKP","x":"Mmm6pBj597NNqBc6gYqgupVJjYnPXWRSIVPG8O0aD4U"},"nerdster.org":{"crv":"Ed25519","d":"nVGl5mXckRnP09cJqBf7Bt9CEgru-luBuxNXgSvNbtk","kty":"OKP","x":"RRZjJbcfT6Vhx19EFODb0Kgx6XuLBx7jSTt38_WzETE"}}

Lisa's Credentials:
{"identity":{"crv":"Ed25519","kty":"OKP","x":"mF5aL7Gws_QhlrvpTv8qZiotC1zZntyimOmwSTQUPao"},"nerdster.org":{"crv":"Ed25519","d":"youO01NczJp6TZFDeAfn_58Id7M1gojaOMYBvwBxVQk","kty":"OKP","x":"v7unDWD7Vr_0VRuPTI6w8RjnT5FK1cyULR53vYCXyB4"}}

/m?fire=emulator&identity=%7B%22crv%22%3A%22Ed25519%22%2C%22kty%22%3A%22OKP%22%2C%22x%22%3A%22Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo%22%7D

# Nice ones:
```
git tag PROD-v`date2`
git tag PROD-11
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
firebase projects:list
gcloud projects list
gcloud auth login

# If running in 2 windows, make sure to set (export) NOW in both
export NOW=`date3`
echo $NOW
export NOW=26-01-05--16-45

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

