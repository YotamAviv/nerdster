# V2 Implementation Status
Date: December 10, 2025

## Overview
We are iterating on a V2 architecture for Nerdster, moving towards a functional "Data Pipeline" approach. The current focus is on the Trust Graph logic and visualizing it alongside the existing V1 app.

## Completed Work

### 1. Core Logic (`lib/v2/`)
*   **`trust_logic.dart`**: Implemented the pure functional core.
    *   Breadth-First Search (BFS) traversal.
    *   Handling of `trust`, `block`, `replace`, `delegate` verbs.
    *   **Conflict Detection**: Parity with V1 verified (detects blocking trusted keys, replacing trusted keys).
    *   **`revokeAt`**: Implemented time-based revocation constraints.
*   **`model.dart`**: Defined immutable data structures (`TrustGraph`, `TrustAtom`, `TrustConflict`).

### 2. Infrastructure
*   **`io.dart` / `firestore_source.dart`**: Abstractions for fetching data, decoupled from logic.
*   **`cached_source.dart`**: In-memory caching decorator to speed up the Shadow View and reduce Firestore reads during debugging.
*   **`orchestrator.dart`**: Manages the fetch-reduce loop.

### 3. UI Integration
*   **`shadow_view.dart`**: A debug view accessible from the Dev menu.
    *   Runs the V2 pipeline for the current user.
    *   Displays stats, conflicts, and blocked nodes.
    *   **Caching**: Includes "Clear Cache" functionality.
*   **`net_tree_view.dart` / `net_tree_model.dart`**:
    *   Created an adapter (`V2NetTreeModel`) to map V2 `TrustGraph` to the existing `NetTreeModel` interface.
    *   Allows reusing the existing `NetTreeTree` widget to visualize the V2 graph.

### 4. Testing
*   **`test/v2/parity_test.dart`**: Integration test using the `simpsonsDemo` dataset. Verifies that V2 reports the same conflicts as V1 (specifically for Bart).

## Next Steps

1.  **Verification**:
    *   Run the app and open **Dev -> V2 Shadow View**.
    *   Run the pipeline and click **"Show Tree"**.
    *   Verify the tree structure matches expectations.

2.  **Content Tree**:
    *   The current "Content" tab in Shadow View shows a flat list.
    *   Need to implement a `ContentTree` adapter (similar to `V2NetTreeModel`) to show content in a hierarchical view if desired.

3.  **Migration**:
    *   Once V2 is fully verified, plan the replacement of `OneofusNet` and `FollowNet` singletons with the V2 pipeline.
