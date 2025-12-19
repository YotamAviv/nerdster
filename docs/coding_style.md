# Coding Style Guide

## Philosophy
We prioritize correctness and explicitness over brevity or "defensive programming" that hides errors. If the system encounters an unexpected state, it should fail fast and loud (assert/throw) rather than attempting to recover silently.

## Rules

### 1. Explicit Typing
Avoid `var` and `final` (without type) whenever the type is not immediately obvious from the right-hand side.
*   **Bad:** `var x = getSomething();`
*   **Good:** `String x = getSomething();`
*   **Acceptable:** `final List<String> names = [];`

### 2. Fail Fast (Assertions)
Do not write code that "handles" impossible situations unless it's at the system boundary (e.g., user input or network IO). Internal logic should assume preconditions are met and assert them.
*   **Bad:** `if (list.isEmpty) return; // when list should never be empty`
*   **Good:** `assert(list.isNotEmpty, 'List must not be empty');`

### 3. Strict Data Integrity
*   Data sources (like Firestore) must return valid, sorted, and verified data.
*   Consumers of that data (like pipelines or logic functions) should **assert** validity, not fix it.
*   If a chain of trust is broken, the entire chain is invalid. Do not try to salvage partial data.

### 4. Immutability
Prefer immutable data structures for core models (`TrustGraph`, `TrustAtom`, etc.).

### 5. Comments
Explain *why*, not *what*. Document assumptions about data integrity.
