# Partial refresh

The goal is to avoid full refresh (actually fetching from the cloud / StatementSources) after using the UI to publish a new Statement (rate, dismiss, comment, etc...)

I expect that this will involve updating the CachedStatementSource along with the write to DirectFirestoreWriter.

In order to verify that this is working, I want to add something that we can watch (listen to) to know if an actual fetch from Firestore (wheter fake, prod, or emulator) has occured. 
The goal will include a test that updates something, refreshes (not from the underlying StatementSource), and verifies that the refresh includes our update.
The recent dismiss_bug_test can be used for this.

Note that if we change our follow network settings or change who we follow/block how, then we may need to fetch new content, and so the watching (or listening) to what is actually being fetched from Firestore should include which token is being fetched.

Before starting:
- verify that all writes use only DirectFirestoreWriter regardless of FireChoice (prod, emulator, fake)
- make a plan. Write the plan below

## plan

### 1. Verification of Writes
- [x] Verified that `SourceFactory.getWriter` always returns `DirectFirestoreWriter` (wrapped possibly in `LgtmStatementWriter`) regardless of `FireChoice`. `FireChoice` logic correctly routes `DirectFirestoreWriter` to the appropriate `FirebaseFirestore` instance (Fake, Emulator, or Prod).

### 2. Observability for Testing
- Create a `SpyStatementSource` class (or similar) that wraps a `StatementSource` and records all calls to `fetch`.
- This will allow tests to assert whether a network request was made and for which keys.

### 3. Update CachedSource
- Add an `push(T statement)` method to `CachedSource` (`CachedStatementSource` in the doc).
- This method will update the internal cache (`_fullCache` and `_partialCache`) with the new statement, ensuring it is available for subsequent in-memory fetches.
- **Verification**: Ensure that the statement being pushed is sound with respect to the notary chain (i.e., its `previous` pointer matches the hash of the last statement in the existing history).

### 4. Implement Partial Refresh Workflow
- Identify the code paths where statements are published (e.g., `RateDialog`, `DismissToggle`, etc.).
- After a successful write using `StatementWriter`, call `push()` on the relevant `CachedSource` (Trust or Content) held by `V2FeedController`.
- Trigger a refresh on `V2FeedController`.

### 5. Verification Test
- Adapt `dismiss_bug_test.dart` or create a new test.
- Use `SpyStatementSource` to wrap the underlying source.
- Perform a write (e.g., dismiss).
- Push the statement into the cache.
- Refresh the controller.
- **Assert**:
    - The UI/Model reflects the change (Dismissed item is removed/updated).
    - `SpyStatementSource` shows **no new network requests** for the affected entity (or minimal requests if other things need validation).