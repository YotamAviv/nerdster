# Partial refresh

The goal is to avoid full refresh (actually fetching from the cloud / StatementSources) after using the UI to publish a new Statement (rate, dismiss, comment, etc...)

I expect that this will involve updating the CachedStatementSource along with the write to DirectFirestoreWriter.

In order to verify that this is working, I want to add something that we can watch (listen to) to know if an actual fetch from Firestore (wheter fake, prod, or emulator) has occured. 
The goal will include a test that updates something, refreshes (not from the underlying StatementSource), and verifies that the refresh includes our update.
The recent dismiss_bug_test can be used for this.

Note that if we change our follow network settings or change who we follow/block how, then we may need to fetch new content, and so the watching (or listening) to what is actually being fetched from Firestore should include which token is being fetched.

Before starting:
- verify that all writes use only DirectFirestoreWriter regardless of FireChoice (prod, emulator, fake)
- make a plan

