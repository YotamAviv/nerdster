# Coding Style Guide

## Philosophy
We prioritize correctness and explicitness over brevity or "defensive programming" that hides errors. If the system encounters an unexpected state, it should fail fast and loud (assert/throw) rather than attempting to recover silently.

## Rules

### 1. Explicit Typing
Avoid `var` and `final` (without type) whenever the type is not immediately obvious from the right-hand side.
*   **Bad:** `var x = getSomething();`
*   **Good:** `String x = getSomething();`
*   **Good:** `final List<String> names = [];`

### 2. Fail Fast (Assertions and Bang Operator)
Do not write code that "handles" unexpected situations.
Assume preconditions are met and assert them.
*   **Bad:** `if (list.isEmpty) return; // when list should never be empty`
*   **Good:** `assert(list.isNotEmpty, 'List must not be empty');`

Prefer using the bang operator (`!`) over explicit null checks and exceptions for internal logic where a value is guaranteed to be present.
*   **Bad:**
    ```dart
    final String? value = map[key];
    if (value == null) throw Exception('Value must be present');
    return value;
    ```
*   **Good:** `return map[key]!;`

Do not implement "fallback".

### 3. Strict Data Integrity
*   Data sources (like Firestore) must return valid data.
*   Consumers of that data (like pipelines or logic functions) should **assert** validity, not fix it.


### 5. Comments
Explain *why*, not *what*. Document assumptions about data integrity.
Avoid long-winded explanations of protocol mechanics or implementation details that can be inferred from the code or the concise description of the data mapping.
*   **Bad:** A paragraph explaining the history and purpose of a concept.
*   **Good:** "Maps identities keys to delegate keys and vice versa."

### 6. Merge, don't sort!
All our **statements lists** are **sorted** and ensure **singular disposition**


