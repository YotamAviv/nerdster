AI NOTE: This is my (the human) file with my own notes.

# Corrupt the database and check what happens
- Corrupt the data by:
  - deleting 1 statement from a notary chain, or 
  - modifying any value in it.

# Misc...

http://localhost:8765/?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22WXf0AG-EMWH8mZLXOnVY2n37jxIGNIKhpRkYs0Wfyto%22%20}


?fire=emulator&showCrypto=true&lgtm=true

# Notifications gallery
?fire=fake&demo=notificationsGallery

?fire=emulator&demo=loner

# Emulator yotam
?fire=emulator&identity={%20%22crv%22:%20%22Ed25519%22,%20%22kty%22:%20%22OKP%22,%20%22x%22:%20%22Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo%22%20}


```
Push to PROD:
bin/deploy_web.sh
firebase --project=nerdster deploy --only functions

add to .bashrc:
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

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

