# The Notary Chain

## Concept

The **Notary Chain** is a fundamental security and integrity mechanism in the Nerdster/OneOfUs ecosystem. It ensures that the history of statements made by an identity is linear, tamper-evident, and immutable.

### Why it exists

The primary goal is to allow individuals to "litter the Internet" with signed content that can be aggregated meaningfully by third parties (like search engines or social graph aggregators) without fear of selective censorship.

If an aggregator "doesn't like" a specific statement you made, they might be tempted to simply omit it from their display of your feed. Without a notary chain, this omission would be undetectable to a viewer.

### How it works

Every statement published by an identity contains a cryptographic link to the immediately preceding statement.

1.  **`previous` Field**: Each statement (except the very first one) includes the hash (token) of the previous statement.
2.  **`signature`**: The statement, including the `previous` field, is signed by the identity's private key.

This creates a blockchain-like structure (a hash chain) for each individual identity.

### Verification

To verify an identity's feed:
1.  **Fetch** the statements.
2.  **Order** them by time (Newest to Oldest).
3.  **Traverse** the chain:
    *   Ensure the `previous` field of statement $N$ matches the `token` (hash) of statement $N+1$ (the older one).
    *   Ensure timestamps are strictly descending.

### Consequences of Violation

If a gap or mismatch is found in the chain (e.g., Statement A points to B, but the aggregator presents C instead of B), the **entire chain is considered corrupt**. The client must reject the data completely. This forces aggregators to either present the full, unaltered history or nothing at all. They cannot selectively edit the past.
