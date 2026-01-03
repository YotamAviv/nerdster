# V2 Lifecycle: From Sign-In to Refresh

This document details the end-to-end lifecycle of a user session in Nerdster V2, covering access, sign-in, content publication, and view refreshing.

## 1. User Access & Sign In

### Access
The user launches the application, which initializes the `NerdsterApp` (in `lib/main.dart`). The root widget `App` listens to the global `SignInState` singleton.

### Sign In
The user signs in using one of two methods:
1.  **QR Code**: Using the `QrSignIn` widget.
2.  **Copy/Paste**: Using the `PasteSignIn` widget.

**Mechanism:**
-   The user provides an **Identity Token** (and optionally a Delegate Key Pair).
-   `SignInState.signIn(identityToken, delegateKeyPair)` is called.
-   This updates the global state and notifies listeners (like `App`).

**Key Classes:**
-   `SignInState`: Singleton managing the current session.
-   `IdentityKey`: The user's persistent identity (ONE-OF-US.NET).
-   `DelegateKey`: The key used to sign content statements (ratings, comments).

## 2. Feed Initialization (The Pipeline)

Once signed in, the `App` navigates to the main view, typically `FancyShadowView`.

### Initialization
`FancyShadowView` initializes a `V2FeedController`. This controller is the central orchestrator for fetching and processing data.

### The "Waterfall" Fetch
The `V2FeedController.refresh()` method executes the following pipeline:

1.  **Trust Pipeline**:
    -   **Source**: `TrustSource` (ONE-OF-US.NET Firestore).
    -   **Action**: Fetches `TrustStatement`s starting from the Point of View (PoV).
    -   **Result**: `TrustGraph` (calculated by `TrustPipeline`).

2.  **Delegate Resolution**:
    -   **Action**: `DelegateResolver` analyzes the `TrustGraph` to map `IdentityKey`s to their active `DelegateKey`s.

3.  **Delegate Content Fetch**:
    -   **Source**: `DelegateContentSource` (Nerdster Firestore).
    -   **Action**: `ContentPipeline.fetchDelegateContent` fetches content (ratings, comments, follows) authored by the *delegates* of all identities in the Trust Graph.

4.  **Follow Network Calculation**:
    -   **Action**: `reduceFollowNetwork` uses the `TrustGraph` and the fetched Delegate Content to determine who the PoV follows in the current context (e.g., `<nerdster>`).
    -   **Result**: `FollowNetwork` (a list of followed identities).

5.  **Aggregation**:
    -   **Action**: `reduceContentAggregation` combines all fetched content into a unified model.
    -   **Result**: `ContentAggregation` (contains subjects, statements, equivalence maps).

**Key Classes:**
-   `V2FeedController`: Orchestrates the fetch.
-   `TrustPipeline` / `TrustGraph`: Manages the Web of Trust.
-   `DelegateResolver`: Resolves Identity -> Delegate.
-   `ContentPipeline`: Fetches content from both sources.
-   `FollowNetwork`: Represents the social graph for content.
-   `ContentAggregation`: The final data model for the UI.

## 3. Publishing a Rating

The user interacts with a `ContentCard` in the `NerdyContentView` and decides to rate a subject.

### Interaction
1.  User clicks "Rate" (or similar action).
2.  `V2RateDialog.show` is called.

### Submission Logic
1.  **Input**: User selects a rating (Like/Dislike), adds a comment, etc.
2.  **Construction**: `V2RateDialog` constructs a JSON object representing the `ContentStatement`.
    -   `verb`: `rate`
    -   `subject`: The token or object being rated.
3.  **Signing**: The statement is signed using the current `DelegateKey` from `SignInState.signer`.
4.  **Upload**:
    -   `SourceFactory.getWriter(kNerdsterDomain)` is used to get a `StatementWriter`.
    -   `StatementWriter.push` sends the signed statement to the Nerdster Firestore.

**Key Classes:**
-   `V2RateDialog`: UI for creating the rating.
-   `SignInState`: Provides the signer (`DelegateKey`).
-   `ContentStatement`: The data structure being created.
-   `StatementWriter`: Handles the network request to Firestore.

## 4. View Refresh

After publishing, the view needs to update to show the new rating.

### Trigger
-   `V2RateDialog` accepts an `onRefresh` callback.
-   `FancyShadowView` passes a callback that triggers `_controller.refresh()`.
-   Alternatively, `V2RefreshSignal` can trigger a refresh globally.

### Refresh Execution
1.  `V2FeedController.refresh()` is called.
2.  **Optimization**: The `CachedSource`s used by the controller may return cached data for the `TrustGraph` and `IdentityContent` if they haven't changed (using `HEAD` requests or memory cache).
3.  **New Fetch**: The `DelegateContentSource` will fetch the new data from Nerdster Firestore, including the just-published rating.
4.  **Re-Aggregation**: The pipeline runs `reduceContentAggregation` again with the new data.
5.  **UI Update**: The `V2FeedController` notifies its listeners. `FancyShadowView` rebuilds `NerdyContentView` with the updated `ContentAggregation`.

**Key Classes:**
-   `V2RefreshSignal`: Global signal for refreshes.
-   `CachedSource`: Optimizes fetching by caching unchanged data.
-   `V2FeedController`: Re-runs the pipeline.
