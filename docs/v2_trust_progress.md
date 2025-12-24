# V2 Trust Pipeline Progress & History

This document tracks the development, logic, and status of the V2 Trust Pipeline.

## Core Philosophy: Strictly Greedy BFS

The V2 Trust Pipeline implements a "Strictly Greedy" BFS algorithm. This means that information discovered closer to the root (the Point of View) has absolute authority over information discovered further away.

### Key Principles:
1.  **Distance Authority**: 
    *   **Blocks**: A node at distance $N$ cannot be blocked by a node at distance $> N$.
    *   **Replaces**: A node at distance $N$ can be *replaced* (linked) by a node at distance $> N$, but it cannot be *revoked* by it. We accept the identity equivalence but ignore the `revokeAt` constraint if the replacer is further away than the original trust path.
2.  **Next Degree Replacement**: A `replace` statement increments the distance ($dist + 1$). This treats a key rotation as a trust hop, matching legacy behavior and preventing "distance gaming."
3.  **Layer-by-Layer Processing**: The graph is built one distance layer at a time.
4.  **Intra-Layer Priority**: Within a single layer, statements are processed in this order:
    *   **Blocks**: Highest priority. If an issuer blocks someone in the same layer (or further), they are blocked.
    *   **Replaces**: Medium priority. Handles key rotations. Supports "Backward Discovery" (if you trust a new key, you automatically trust the old key it replaces at $dist + 1$).
    *   **Trusts**: Lowest priority. Discovers new nodes for the next layer.
5.  **Single Pass**: Due to the layer-by-layer coordination, the entire reachable and valid graph is built in a single pass of the orchestrator loop.

## Notification & Rejection Logic

The V2 algorithm generates `TrustNotification` objects when it encounters conflicts or invalid statements.

## Pending Refinements

1.  **Implement Double-Claimed Delegate Notification**: Add logic to detect and notify when multiple identities attempt to claim the same delegate key.
2.  **Use Merger for Statements**: Replace `sort` calls in `follow_logic.dart` and `content_logic.dart` with a `Merger` to handle pre-sorted statements efficiently.
 Analysis

| Legacy Notification | V2 Status | To Whom? | Decision / Logic |
|---------------------|-----------|----------|------------------|
| `Attempt to block your key.` | ✅ Tested | PoV User | Critical. Direct attack on the root. |
| `Attempt to replace your key.` | ✅ Tested | PoV User | Critical. Direct attack on the root. |
| `Attempt to block trusted key.` | ✅ Tested | PoV User | Conflict. Notifies when a trusted path is challenged. |
| `Attempt to trust blocked key.` | ✅ Tested | PoV User | Conflict. Notifies when an issuer ignores a block. |
| `Attempt to replace a replaced key.` | ✅ Tested | PoV User | Conflict. Multiple keys claiming the same identity. |
| `Attempt to replace trusted key.` | ✅ Tested | PoV User | Info. Distance Authority case: link accepted, revocation ignored. |
| `You trust a non-canonical key directly.` | ✅ Implemented | PoV User | Info. Suggests updating trust to the new key. |
| `Replaced key not in network.` | ✅ Resolved | N/A | Resolved by "Backward Discovery." |
| `Attempt to replace a blocked key.` | ✅ Tested | PoV User | Info. Identity link accepted, but the block remains. |

### Legacy Mapping & Status

| Legacy Notification | V2 Implementation Status | V2 Reason / Logic |
|---------------------|--------------------------|-------------------|
| `Attempt to block your key.` | ✅ Tested | "Attempt to block your key." |
| `Attempt to replace your key.` | ✅ Tested | "Attempt to replace your key." |
| `Attempt to block trusted key.` | ✅ Tested | "Attempt to block trusted key by [Issuer]" |
| `Attempt to trust blocked key.` | ✅ Tested | "Attempt to trust blocked key by [Issuer]" |
| `Attempt to replace a replaced key.` | ✅ Tested | "Key [Old] replaced by both [New1] and [New2]" |
| `Attempt to replace trusted key.` | ✅ Tested | "Trusted key [Old] is being replaced by [Issuer] (Revocation ignored due to distance)" |
| `You trust a non-canonical key directly.` | ✅ Implemented | "You trust a non-canonical key directly (replaced by [New])" |
| `Replaced key not in network.` | ✅ Resolved | In V2, "Backward Discovery" ensures that if you trust a new key, the old key is automatically pulled into the network at $dist + 1$. |
| `Attempt to replace a blocked key.` | ✅ Tested | "Blocked key [Old] is being replaced by [Issuer]" |

## Implementation Details

### `resolveRevokeAt`
Handles the `revokeAt` token in `replace` statements.
*   If the token is missing or is the sentinel `"<since always>"`, it returns `date0` (epoch 0), revoking the entire history of the old key.
*   If the token is valid, it revokes all statements issued *after* that token's timestamp.

### `reduceTrustGraph`
A pure function that takes a `Map<String, List<TrustStatement>>` and returns a `TrustGraph`. It is deterministic and synchronous.

### `TrustPipeline` (Orchestrator)
Manages the loop between fetching data (I/O) and reducing it (Logic). It uses a generic `StatementSource<T>` to allow for efficient, type-safe data retrieval.

## Progress Log

- **2025-01-24**: Refactored `TrustGraph` and `reduceTrustGraph` to remove `delegates`.
- **2025-01-24**: Refactored `FollowNetwork` to use an ordered `List<String>` for `identities` and removed the `authority` map.
- **2025-01-24**: Updated `SubjectAggregation` model and `reduceContentAggregation` logic to support likes, tags, and last activity.
- **2025-01-24**: Enforced explicit typing (no `var`) and fail-fast assertions in V2 logic.
*   **2025-12-22**: Initial implementation of V2 Trust Pipeline.
*   **2025-12-22**: Refactored IO layer to be generic (`StatementSource<T>`).
*   **2025-12-22**: Implemented "Since Always" revocation logic.
*   **2025-12-22**: Refactored `reduceTrustGraph` to use Layer-by-Layer logic, resolving race conditions in a single pass.
*   **2025-12-22**: Implemented "Distance Authority" for replacements: Identity links are always accepted, but revocations are ignored if the replacer is further away than the original trust path.
*   **2025-12-22**: Aligned V2 with legacy "Next Degree" replacement logic (rotations cost 1 degree).
*   **2025-12-22**: Verified all 13 core trust scenarios with unit tests (including Double Replacement).
*   **2025-12-23**: Implemented V2 Follow Network logic (`reduceFollowNetwork`).
    *   Supports context-aware filtering.
    *   Handles transitive follows (if A follows B for context C, and B follows D for context C, A follows D).
    *   Resolves delegates (if A follows B, A also follows B's trusted delegates).
    *   Initializes network with identities that follow the context itself.
*   **2025-12-23**: Implemented V2 Content Aggregation logic (`reduceContentAggregation`).
    *   **Decentralized Censorship**: "Censor beats Rate". If a trusted identity censors a subject or a statement, it is filtered out for everyone who follows them.
    *   **Equivalence Grouping**: Groups subjects (URLs, articles) under a canonical token based on `equate` statements.
    *   **Relational Discovery**: Maps related subjects via `relate` statements.
    *   Verified with unit tests including Simpsons and Custom Context scenarios.
*   **2025-12-23**: Updated documentation and specifications for V2 logic.
*   **2025-12-23**: Configured VS Code settings to prevent "run anyway" prompts from interrupting the flow.

## Open Questions & Future Considerations

### 1. Identity Shortcuts vs. Forks
In the "Double Replacement" scenario (Bob3 replaces both Bob2 and Bob1, while Bob2 also replaces Bob1), the algorithm currently flags the second replacement as a potential conflict or a "Distance Authority" override.

*   **The Shortcut**: Bob is being thorough. He wants to make sure anyone who trusts *any* of his old keys finds his new one.
*   **The Fork**: Two different people are claiming the same old key.

**Current Decision**: We notify the user. While Bob's shortcut is technically valid, the ambiguity of multiple keys claiming the same identity is a security risk that deserves visibility. We prioritize "Distance Authority" (the shortest path to the identity link wins).

**Future Consideration**: Could we detect if the two "new" keys are themselves linked? If Bob3 replaces Bob2, and both replace Bob1, we could theoretically suppress the notification because the chain is consistent. However, this adds complexity to the BFS (requires looking "ahead" or "sideways" at other replacements).
