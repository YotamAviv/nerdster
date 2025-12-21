# Documentation Guide

Welcome to the Nerdster/OneOfUs project! This guide outlines the recommended reading order to understand the system's architecture, trust model, and implementation details.

## Recommended Reading Order

### 1. High-Level Overview
Start here to understand the "Why" and "What" of the system.
*   **`docs/concepts.md`**: Explains the separation between the Identity Layer (OneOfUs) and the Application Layer (Nerdster), and core concepts like Self-Sovereign Identity and the Web of Trust.

### 2. Core Protocol
Understand the immutable rules that define the system.
*   **`docs/core_specification.md`**: Defines the data structures (Keys, Statements), cryptography, hashing (Tokens), and the fundamental protocol rules that must not change.
*   **`docs/trust_semantics.md`**: The "Source of Truth" for the meaning of verbs (`trust`, `block`, `replace`, `delegate`) and how they affect the network.

### 3. Trust Model & Algorithm
Dive into how the "Web of Trust" is actually computed.
*   **`docs/trust_model.md`**: Details the Trust Algorithm (Greedy BFS), the ordering principles (Trust Distance), and the **Data Distinctness** principle (Subject-Centric State).

### 4. Implementation Details
For developers working on the code.
*   **`docs/data_flow.md`**: Describes how data moves through the system (Firestore -> Client -> Trust Logic -> UI).
*   **`docs/v2_implementation_status.md`**: Tracks the current state of the V2 rewrite, including known issues and pending tasks.
*   **`docs/coding_style.md`**: Guidelines for writing code in this repository.

### 5. Specific Topics
*   **`docs/optimization_strategy.md`**: (Optional) Deep dive into performance considerations.
*   **`docs/rewrite_proposal.md`**: (Historical) Context on why the V2 rewrite was initiated.

---

## Key Concepts Summary

### The Two Layers
*   **Identity Layer (OneOfUs):** Who is a real human? (Vouching).
*   **Content Layer (Nerdster):** Who is interesting? (Following).

### Subject-Centric State (Distinctness)
A user's relationship to a subject is defined by their **latest** statement.
*   **Example:** If Alice `trusts` Bob at 10:00 and `blocks` Bob at 10:05, the system only sees the `block`.
*   **Clear:** The `clear` verb removes any relationship, resetting to neutral.
*   **Implementation:** This is enforced by the "Distincter" logic, which filters statements based on the `Issuer:Subject` signature, keeping only the newest one.

### Trust Algorithm
*   **Greedy BFS:** We traverse the graph layer by layer (Distance 0, 1, 2...).
*   **Subjective:** Trust is calculated from *your* perspective (Root Key).
*   **Eventual Consistency:** The final state depends on the *timestamps* of statements, not the order they arrived in.
