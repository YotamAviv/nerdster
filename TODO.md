# TODO

# Simpsons demo for both Hablotengo and Nerdster using the same Oneofus identities.

## Goals:

- The Nerdster is the naked app that demonstrates the crypto.
In NodeDetails, also show HabloTengo delegate keys if they exist.
This should allow running the demo startup code for both the Nerdster and HabloTengo and see
from the Nerdster that some folks also use HabloTengo, which fortifies the open, heterogeneous claim.

- The embedded Nerdster demo at https://nerdster.org/ where you can view as Lisa, etc.. would
also show that.

### Probably do these first:

- Clean up the ./bin/ start/stop emulators and have each project start and stop its own.
I think this is a good idea, but there may be pitfalls I haven't considered.

- Move Nerdster and Oneofus to New security model - cloud functions handle the writes and verify signatures.
This is done in Hablotengo. Oneofus and Nerdster should use similar tech.

The Nerdster has oneofus Firebase credentials, and it shouldn't.
It uses those to state the identity layer stuff in SimposonsDemo.
Once the upgrade to using the new security model:
- remove Firebase Oneofus related stuff from the Nerdster
- I think that having it still execute SimpsonsDemo is okay.

### Generate compatible SimpsonsDemo for both the Nerdster and HabloTengo.

It think that it's acceptable for the Nerdster to still be the project that runs SimpsonsDemo
to create the identity keys and state the identity layer stuff.
(A cleaner approach might have the Oneofus project create the basic vouch/block stuff, but 
the Nerdster and HabloTengo still need delegate keys which are identity layer.)

The nerdster should then make some kind of simpsonsData.json file available to HabloTengo so that
it can create the HabloTengo delegate key data (homer's contact info, etc...)

Some script should push out the Nerdster home page - one already exists.
This script does push out something, I lose track of the detailsm see nerdster14/web/common/data/demoData.js

When running the HabloTengo SimpsonsDemo thing, give it that file so that
it uses those identities to create HabloTengo demo data for the same identities.
This will let the embedded Nerdster demo at https://nerdster.org show that Homer and others also use HabloTengo.

Probably Serve HabloTengo similarly to the Nerdster, at https://hablotengo.com/app instead of at the root.
This will require a similar deploy script.

If possible, on the HabloTengo home page, embed HabloTengo where you can view as Homer, Lisa, etc..
This requires having them fully sign in and revealing their delegate keys, which isn't great.







## Dead code in cloud functions: OMDB / TMDB fetchers

`functions/metadata_fetchers.js` contains `fetchFromOMDb` and `fetchFromTMDB`, called
from `executeFetchImages` in `functions/core_logic.js` when the content type is `movie`.

Both functions guard on environment variables that are apparently never set:

```js
// fetchFromOMDb:
const apiKey = process.env.OMDB_API_KEY;
if (!apiKey || !title) return [];

// fetchFromTMDB:
const apiKey = process.env.TMDB_API_KEY;
if (!apiKey || !title) return [];
```

Since `OMDB_API_KEY` and `TMDB_API_KEY` are not known to be configured in Firebase,
both functions silently return `[]` on every call. Movie image fetching falls back to
Wikipedia only.

**Resolution options:**
1. Set `OMDB_API_KEY` and/or `TMDB_API_KEY` as Firebase environment variables (free-tier
   keys available at omdbapi.com and themoviedb.org).
2. Remove the dead calls to `fetchFromOMDb` and `fetchFromTMDB` from `core_logic.js` and
   delete the two functions from `metadata_fetchers.js`.
