# Trust Model & Ordering

## Trust Distance
The "Network" is defined as a graph of identities connected by trust statements.
The "Distance" of an identity is the shortest path from the root (User) to that identity in the trust graph.
*   **Root:** Distance 0.
*   **Directly Trusted:** Distance 1.
*   **Friends of Friends:** Distance 2.

## Ordering Principle
Whenever the Network is represented as a list (e.g., for iteration, display, or fetching), it **must** be ordered by Trust Distance (ascending).
*   **More Trusted (Closer) -> Head of List**
*   **Less Trusted (Farther) -> Tail of List**

This ensures that:
1.  The most relevant identities are processed first.
2.  UI lists show the most trusted people at the top.
3.  Resource limits (e.g., "fetch max 100 users") drop the least trusted users first.

## Content Pipeline
When fetching content from the network:
1.  Identify trusted users.
2.  **Sort** them by distance.
3.  Fetch content.
4.  (Optionally) Sort content by Time, but the underlying network structure remains distance-ordered.

## Trust Algorithm Implementation

### Goals & Aspirations
The algorithm **needs to**:
*   Reliably identify a set of trusted keys starting from a user's root identity.
*   Enforce security constraints: blocking, revocation (`revokeAt`), and key replacement.
*   Operate efficiently on client devices (mobile/web) with limited resources.
*   Produce a deterministic output for a given set of inputs (statements).

The algorithm **hopes to**:
*   Maximize connectivity while minimizing exposure to spam or malicious actors (Sybil resistance).
*   **Eventual Consistency:** Ensure that once all statements are received, the calculated trust state is the same, regardless of the order in which the statements arrived (e.g., receiving a "block" before the original "trust").
*   Provide a "human-understandable" logic for why someone is trusted (e.g., "Trusted by Alice, who is trusted by you").

## Data Distinctness & Redundancy

> **Note:** This concept applies to both Trust and Content statements. See `docs/README.md` for a high-level overview.

To optimize bandwidth and processing, the system employs a **Distinctness** filter (often referred to as "the distincter").

### The Principle: Subject-Centric State
A user's relationship to a subject (Person or Content) is defined by their **latest** statement about that subject. Older statements are considered superseded and redundant.

*   **One State Per Subject:** You cannot simultaneously "trust" and "block" someone. You cannot "rate 5 stars" and "rate 1 star" the same content at the same time. The latest action defines the current state.
*   **The `clear` Verb:** The `clear` verb is a special action that effectively "deletes" the relationship. It supersedes any previous statement about the subject, returning the state to "neutral" (as if nothing was ever said).

### Mechanism
*   **Signature:** Each statement type defines a `DistinctSignature`.
    *   **Trust:** `Issuer:Subject` (e.g., `Alice:Bob`).
    *   **Content:** `Issuer:Subject` (or `Issuer:Subject:Other` for relationships).
*   **Filtering:** When fetching or processing a stream of statements:
    1.  Sort statements by time (Newest First).
    2.  Iterate through the list.
    3.  Keep the **first** statement seen for each unique Signature.
    4.  Discard the rest.

### Implication
This means `Alice trusts Bob` (Time 1) and `Alice blocks Bob` (Time 2) share the same signature (`Alice:Bob`). The system will only keep the "block" statement. This enforces the "latest state wins" rule and prevents the graph from being cluttered with historical flip-flops.

### Implementation Strategy
The Nerdster V2 Trust Algorithm is a **Greedy Breadth-First Search (BFS)** that traverses the "Web of Trust" starting from a user's root identity.

### Why Greedy BFS?
*   **Performance:** It prioritizes the shortest path to trust. If Alice trusts Bob directly (distance 1), we don't need to evaluate a path where Alice trusts Charlie who trusts Bob (distance 2).
*   **Simplicity:** It maps naturally to the concept of "degrees of separation."
*   **Resource Management:** It allows for easy truncation. We can stop scanning after a certain depth (e.g., 3 degrees) or a certain number of trusted keys (e.g., 1000 keys) to prevent resource exhaustion.

### Algorithm Steps
1.  **Initialize:** Start with the Root Key in the `trusted` set (distance 0).
2.  **Iterate:** For each key at the current distance `d`:
    *   Fetch the key's latest statements (respecting `revokeAt` if applicable).
    *   Process statements in **reverse chronological order** (newest first).
    *   **Trust:** If a key is trusted and not already seen, add it to the queue for distance `d+1`.
    *   **Block:** If a key is blocked, add it to the `blocked` set. Do not traverse it.
    *   **Replace:** If a key is replaced, map the old key to the new key. If the old key was trusted, the new key inherits that trust (subject to conflict resolution).
    *   **Revoke:** If a statement has `revokeAt`, it limits the validity of the *target* key's history.

### Limitations & Trade-offs
*   **Path Dependence:** The "Greedy" nature means the *first* valid path found determines the trust status. If Alice trusts Bob (who is malicious) and Charlie (who is honest), and both say conflicting things about Dave, the algorithm's result depends on who is processed first (usually determined by distance, then arbitrary order).
*   **Incomplete Global View:** The algorithm does not compute a global consensus. It computes a **subjective** view from the perspective of the Root Key.
*   **Sybil Attacks:** While `block` helps, a trusted user can still introduce many fake identities. The distance limit is the primary defense against this.

### Universal Trust Algorithm Limitations
No trust algorithm can be perfect. This is a variation of the **Byzantine Generals Problem**.
*   **Subjectivity:** Trust is inherently subjective. There is no "objective" truth about who is trustworthy, only who *you* trust.
*   **Conflict:** Contradictory statements (e.g., "A trusts B" vs "C blocks B") are inevitable. Any resolution strategy (e.g., majority vote, shortest path, newest statement) is a heuristic, not a proof.
*   **Key Compromise:** If a private key is stolen, the attacker *is* the user until a revocation/replacement is successfully propagated and observed.
