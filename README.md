# Nerdster & ONE-OF-US.NET

## Recommended Reading Order

### 1. High-Level Overview

- **`docs/concepts.md`**: Separation between Identity Layer (ONE-OF-US.NET) and Application Layer (Nerdster).

### 2. Core Protocol

- **`docs/core_specification.md`**: Data structures, cryptography, hashing, and the **Singular Disposition** principle.
- **`docs/trust_statement_semantics.md`**: Meaning of verbs (`trust`, `block`, `replace`, `delegate`).
- **`docs/content_statement_semantics.md`**: Meaning of content verbs (`follow`, `rate`, `relate`, etc.).

### 3. Trust Model & Algorithm

- **`docs/trust_algorithm.md`**: Trust Algorithm (Greedy BFS) and ordering principles.

### 4. Implementation Details

- **`docs/data_flow.md`**
- **`docs/v2_implementation_status.md`**
- **`docs/coding_style.md`**

### 5. Specific Topics

- **`docs/optimization_strategy.md`**
- **`docs/rewrite_proposal.md`**: (Historical) Context on why the V2 rewrite was initiated.
- **`docs/hosting.md`**: Web hosting setup and deployment.

---

## Key Concepts Summary

### The Two Layers

- **Identity Layer (ONE-OF-US.NET):** Who is a real human? (Vouching).
- **Content Layer (Nerdster):** Leverages the identity layer and adds Content: rate (movies, articles, ...), relate, censor, and follow for different contexts.

### Singular Disposition

A user's relationship to a subject (or a pair of subjects) is defined by their **latest** statement about that subject.

- **Example:** If Alice `trusts` Bob at 10:00 and `blocks` Bob at 10:05, the system only sees the `block`.
- **Clear:** The `clear` verb says nothing, and so after you clear a subject (or a pair of subjects), it's like you never said anything at all about them.
- This applies to Nerdter content as well

### Trust Algorithm

- **Greedy BFS:**
- **Subjective:** Trust is calculated from a Point of View (PoV).
