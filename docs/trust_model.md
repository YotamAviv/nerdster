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
