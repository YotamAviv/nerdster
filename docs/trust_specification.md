# Trust Algorithm Specification (V2)

## Overview
The V2 Trust Algorithm is a **Strictly Greedy, Layer-by-Layer BFS** designed to build a trusted identity graph from a specific Point of View (PoV). It prioritizes proximity to the root and ensures that "shallow" trust decisions are never overturned by "deep" discoveries.

## Core Logic: `reduceTrustGraph`

### 1. Layer-by-Layer Traversal
The algorithm processes the graph one distance layer at a time ($d=0, 1, 2, \dots$). This ensures that all nodes at distance $N$ are evaluated before any nodes at distance $N+1$.

### 2. Intra-Layer Priority (The "Stage" System)
Within each layer, statements from all issuers in that layer are processed in three distinct stages:

#### Stage 1: Blocks (Highest Priority)
*   If an issuer in the current layer blocks a subject, that subject is added to the `blocked` set.
*   **Greedy Constraint**: A block is rejected if the subject is already trusted at the *current or a shallower* distance.

#### Stage 2: Replaces (Medium Priority)
*   Handles key rotations (Identity management).
*   **Next Degree Replacement**: A `replace` statement increments the distance ($dist + 1$). This treats a key rotation as a trust hop, matching legacy behavior and preventing "distance gaming."
*   **Backward Discovery**: If a trusted key `New` replaces `Old`, `Old` is automatically added to the *next* layer so its history can be discovered.
*   **Distance Authority**: 
    *   Identity links (replacements) are always accepted to maintain the graph's integrity.
    *   Revocations (`revokeAt`) are only honored if the issuer is at least as close to the root as the `Old` key's existing trust path.
*   **Revocation**: If a `replace` statement includes a `revokeAt` token, all statements by the `Old` key issued after that token are ignored.
*   **Sentinel**: A `revokeAt` value of `"<since always>"` (or an invalid token) revokes the entire history of the `Old` key.

#### Stage 3: Trusts (Lowest Priority)
*   Discovers new nodes for the next layer ($dist + 1$).
*   **Confidence Levels (Node-Disjoint Paths)**: A node is only added to the next layer if it meets the `PathRequirement`.
    *   **Definition**: For a node at distance $D$ to be trusted with a confidence level of $N$, there must exist $N$ paths from the Root to that node such that no two paths share any intermediate nodes.
    *   **The Bottleneck Rule**: If all paths to a subject pass through a single person (e.g., Alice), then that subject has only 1 distinct path, regardless of how many people Alice trusts or how many people trust the subject.
*   **Canonicalization**: If a trusted key has been replaced, the algorithm automatically follows the replacement to the "effective" subject.

## Notifications & Conflicts

The algorithm generates `TrustNotification` objects to explain why certain statements were rejected or why the graph looks the way it does.

| Notification Reason | Type | Logic |
|---------------------|------|-------|
| `Attempt to block your key.` | Conflict | Issuer tried to block the PoV root. |
| `Attempt to replace your key.` | Conflict | Issuer tried to replace the PoV root. |
| `Attempt to block trusted key by [Issuer]` | Conflict | Issuer tried to block someone already trusted at a shallower/equal level. |
| `Attempt to trust blocked key by [Issuer]` | Conflict | Issuer tried to trust someone already blocked. |
| `Key [Old] replaced by both [New1] and [New2]` | Conflict | Multiple keys claim to replace the same old key. |
| `Trusted key [Old] is being replaced by [Issuer] (Revocation ignored due to distance)` | Info | A distant node tried to revoke a closer node. We link them but ignore the revocation. |
| `Trusted key [Old] is being replaced by [Issuer]` | Info | A key already in the graph is being replaced (Identity discovery). |
| `Blocked key [Old] is being replaced by [Issuer]` | Info | A blocked key is being replaced; the identity link is accepted but the block remains. |
| `You trust a non-canonical key directly` | Info | An issuer trusts an old key that has already been replaced. |

## Orchestration: `TrustPipeline`
The `TrustPipeline` manages the loop between the **Pure Logic** (`reduceTrustGraph`) and **Side-Effecting I/O** (`StatementSource`).

1.  **Fetch**: Get statements for the current "frontier" (trusted but not yet fetched).
2.  **Reduce**: Run the pure logic on the accumulated history.
3.  **Repeat**: Continue until `maxDegrees` is reached or the frontier is empty.

### Single Pass Efficiency
Due to the layer-by-layer coordination in `reduceTrustGraph`, the entire reachable and valid graph is built in a single pass of the orchestrator loop. The orchestrator simply expands the "known world" until it hits the distance limit.

## History & Evolution
*   **Legacy (`GreedyBfsTrust`)**: Used a similar layer-by-layer approach but was tightly coupled to the I/O and UI models.
*   **V2 Refactor**: Decoupled logic from I/O. Introduced generic `StatementSource<T>`.
*   **Strict Greediness**: Formalized the rule that deep nodes cannot affect shallow nodes.
*   **Next Degree Replacement**: Aligned with legacy behavior where key rotations cost 1 degree of distance.
*   **Revocation Sentinels**: Added explicit support for `"<since always>"` to handle full-history key revocations.
