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
- [x] Verified that `SourceFactory.getWriter` always returns `DirectFirestoreWriter` (wrapped possibly in `LgtmStatementWriter`) regardless of `FireChoice`.

### 2. Update CachedSource (Write-Through Cache)
- Modify `CachedSource` to implement `StatementWriter`.
- **Constructor Change**: Accept both:
  - `StatementSource<T> _reader` (for fetching misses).
  - `StatementWriter _writer` (for persisting new statements).
  - Note: `SourceFactory.getWriter` creates transient writers. This instance inside `V2FeedController` will be the single "long-lived" access point for the current view.
- **Implement `push(Json json, StatementSigner signer)`**:
  - Delegate to `_writer.push(json, signer)`.
  - On success:
    - Receive the new `Statement`.
    - Manually insert it into `_fullCache` (prepend to history).
    - This ensures the cache is immediately consistent with the write.
  - On failure: Throw (do not update cache).

### 3. Refactor Publishing Logic & Remove LGTM from IO Layer
- **Goal**: Clean separation of concerns. IO Layer (`StatementWriter`) should just write. `V2FeedController` handles the business transaction including confirmation (LGTM).
- **Remove** usage of `SourceFactory.getWriter()` in UI components (`V2RateDialog`, `V2RelateDialog`, `v2Submit`, `DismissToggle`, etc.).
- **Remove** `LgtmStatementWriter`. It conflates UI (BuildContext) with IO.
- **New Workflow**:
  1.  Dialog constructs the JSON.
  2.  Dialog calls `await controller.push(json, signer, context: context)`.
  3.  `controller.push` calls `await Lgtm.check(json, context, ...)`.
  4.  If confirmed, `controller` delegates to `CachedSource.push`.
  5.  `CachedSource` updates cache & delegates to `DirectFirestoreWriter`.
- **Note**: `SourceFactory` should no longer accept `BuildContext` or `V2Labeler`. It just returns a bare `DirectFirestoreWriter`.

### 4. Remove `V2RefreshSignal`
- **Deletion**: Delete `V2RefreshSignal` class and remove all usages. It is a source of confusion and hidden coupling.
- **Manual Refresh**: The "Refresh" button in `EtcBar` should call `controller.refresh()` directly.
- **Implementation**:
  - `EtcBar` needs access to the `V2FeedController` (it already has it via constructor!).
  - `ContentView` no longer needs to listen to a global signal.
  - `DirectFirestoreWriter` (and others) no longer fire a global signal. The cache update is handled explicitly via the Write-Through path (`CachedSource.push`).

### 5. Refresh Semantics (Simplified)
- **`refresh()`**: Public method. Forces network sync (previously `clearCache: true`). Only used by the explicit "Refresh" UI button.
- **`notify()`** (or internal update): Re-runs the view logic (reduction/filtering) over the *existing* cache. This happens automatically after a `push` updates the cache in-memory.
- **Lifecycle**: `V2FeedController` manages its own refresh state. No external event bus.

### 6. Verification Test
- [x] `test/v2/partial_refresh_test.dart` exists and uses `SpyStatementSource` to verify network isolation.
- Update this test (or add new ones) to verify the `Write-Through` behavior: ensuring that `push` updates the cache and subsequent fetches use that cache.