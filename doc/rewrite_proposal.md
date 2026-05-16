# Nerdster Architecture Rewrite Proposal

## 1. The Core Problem: State Management vs. Data Flow
The current architecture uses the `Comp` mixin to manually manage dependencies and state synchronization.
*   **Current State:** `Comp` objects (`OneofusNet`, `FollowNet`) hold mutable state (`_network`, `_delegates`) and notify listeners when they change. They manually check `ready` flags of their dependencies.
*   **The Friction:** This leads to "glitches" (inconsistent intermediate states), complex `process()` logic to handle async fetching, and difficulty in reasoning about the exact state of the system at any point.
*   **The "Flaw":** The circular-ish dependency you noted (`MyDelegateStatements` needing `FollowNet`) is a symptom of trying to coordinate *fetching* (async) with *computing* (sync) in a stateful object graph.

## 2. The Vision: Reactive Pipelines (Map/Reduce)
A clean rewrite would treat the application as a **Data Pipeline**. Instead of objects that *hold* state, we have functions that *transform* streams of data.

### 2.1. The Pattern
Everything is a Stream (or `Observable`).
```dart
Stream<Input> -> [Transform/Map] -> [Reduce/Scan] -> Stream<Output>
```

### 2.2. The Trust Pipeline
Instead of `OneofusNet` being a singleton that holds a map, it becomes a transformation.

1.  **Source:** `Stream<String> povToken` (The user's ID).
2.  **Map (Fetch):** `povToken` -> `Stream<List<TrustStatement>>` (Fetches raw statements).
3.  **Reduce (Graph Build):** `List<TrustStatement>` -> `Graph` (The `GreedyBfsTrust` logic).
    *   *This is a pure function.* It takes a list of statements and returns a Graph. No side effects, no async fetching inside the logic.
4.  **Output:** `Stream<Graph>` (The live Trust Graph).

### 2.4. The Identity Equivalence Layer
Crucially, the "Trust Graph" is not just a set of keys, but a set of **Identities** (Equivalence Sets).
*   **Concept:** A "Person" is a set of keys `{KeyA, KeyB, KeyC}` linked by `replace` statements.
*   **Revocation Semantics:** Key A is not "dead"; it is valid *until* the replacement statement.
*   **Seamless Following:** If I follow Key A, the pipeline automatically resolves this to "Follow Identity(A)". Since Identity(A) includes Key B, I see content from Key B.
*   **Implementation:** The `GreedyBfsTrust` reducer outputs a `Map<Key, IdentityID>` alongside the trust graph. The Content Pipeline uses this map to aggregate content from all keys in an identity.

### 2.3. The Content Pipeline
1.  **Source:** `Stream<Graph>` (From the Trust Pipeline).
2.  **Map (Fetch Content):** `Graph` -> `Stream<List<ContentStatement>>`.
    *   "For every node in the Graph, subscribe to their content."
3.  **Reduce (Merge & Sort):** `List<List<ContentStatement>>` -> `List<ContentStatement>`.
    *   This is exactly the `Merger.merge` logic we just refactored.
4.  **Reduce (Censor & Tree):** `List<ContentStatement>` + `Graph` -> `ContentTree`.
    *   Apply censorship rules (using the Graph for trust rank).
    *   Group by Subject (build the tree).

### 2.5. Future Goal: Collusion Resistance
The current "Greedy BFS" is simple but vulnerable to a single bad actor bridging to a network of bots.
*   **Goal:** Limit exposure to fraud by requiring multiple, non-overlapping paths for distant nodes.
*   **Concept:** Immediate trusts (Distance 1) are trusted implicitly. For Distance > 1, we may require $K$ independent paths (e.g., 2, 3, or 4 colluding actors required to fake a trust).
*   **Complexity:** This complicates "Distance" (is it the shortest path, or the shortest *robust* path?) and requires handling overlapping paths (e.g., `I -> A -> X` vs `I -> B -> C -> X`). The algorithm must decide how to weigh path length vs. path multiplicity.

## 3. Cloud vs. Client
You mentioned porting to Cloud Functions. This architecture makes that decision easy: **The "Reduce" steps can move to the server.**

### Option A: Thick Client (Current)
*   **Client:** Fetches raw JSON. Runs BFS. Builds Tree.
*   **Pros:** Decentralized, private, no server compute cost.
*   **Cons:** Heavy bandwidth (fetching all history), heavy CPU on phone.

### Option B: Cloud Compute (Proposed)
*   **Cloud Function:**
    *   Trigger: New `TrustStatement` written to Firestore.
    *   Action: Re-runs `GreedyBfsTrust` for affected users (or on-demand).
    *   Output: Writes a `ComputedGraph` document (or JSON blob) to Firestore.
*   **Client:**
    *   Subscribes to `ComputedGraph`.
    *   Subscribes to `Content` filtered by that graph.
*   **Pros:** Client is extremely simple (just renders the Tree). Fast startup.
*   **Goal:** Enable "Thin Clients" that receive exactly what they need to display (e.g., just the content feed). Future clients might not visualize or calculate the trust graph at all.
*   **Cons:** Centralized dependency.

## 4. Implementation Strategy: "The Functional Core"

Regardless of Cloud vs. Client, the code should be rewritten as **Pure Functions**.

**Example: The Trust Reducer**
```dart
// Pure function. No fetching, no singletons, no async.
// Input: A list of statements. Output: A Network Graph.
Graph buildTrustGraph(String pov, List<TrustStatement> statements) {
  // 1. Sort by time (Map/Reduce)
  // 2. Apply Greedy BFS logic
  // 3. Return Graph
}
```

**Example: The Content Reducer**
```dart
// Pure function.
ContentTree buildContentTree(Graph trustGraph, List<ContentStatement> content) {
  // 1. Filter content not in trustGraph (Map)
  // 2. Apply Censorship based on trustGraph rank (Reduce)
  // 3. Group by Subject (Reduce)
  // 4. Return Root Node
}
```

## 5. Summary
The "clean rewrite" moves away from **"Components that wait for each other"** to **"Data that flows through functions"**.

1.  **Remove `Comp`**: Use Dart `Stream` or `ValueNotifier` chains.
2.  **Isolate Logic**: Extract `GreedyBfsTrust` and `ContentBase` logic into pure functions that take data and return results (no side effects).
3.  **Pipeline**: Connect these functions: `User -> Fetch -> TrustGraph -> ContentFetch -> ContentTree`.

## 6. Infrastructure & Testing Strategy
The rewrite addresses the complexity of testing across different environments (Linux/Fake vs. Chrome/Cloud Functions) by strictly decoupling **Logic** from **I/O**.

### 6.1. The Abstraction: `StatementSource`
We define a single interface for data retrieval. The "Logic" (GreedyBFS) never knows where data comes from.

```dart
abstract class StatementSource {
  /// Fetches statements for a set of keys.
  /// Returns a Stream or Future of statements.
  Future<List<Statement>> fetch(Set<String> keys);
}
```

### 6.2. Implementations
1.  **`CloudFunctionsSource` (Production / Web):**
    *   Implements the `batchFetch` optimization.
    *   Calls `functions/index.js` (streaming endpoint).
    *   Used in the live app and Chrome-based integration tests.
2.  **`FakeSource` (Unit Tests / Linux):**
    *   Reads from in-memory maps or local JSON files.
    *   Used for testing graph logic (loops, conflicts, censorship) without any network or Firebase dependencies.
3.  **`DirectFirestoreSource` (Optional / Legacy):**
    *   Uses direct Firestore SDK calls (if needed for specific debugging).

### 6.3. The Testing Benefit
*   **Logic Tests:** You can test complex scenarios (e.g., "Attempt to replace a replaced key") on Linux by simply feeding the `GreedyBfsTrust` pure function a list of crafted statements. No emulator required.
*   **Integration Tests:** You only need to verify that `CloudFunctionsSource` correctly talks to the Emulator. You don't need to re-test the graph logic in the integration suite.
