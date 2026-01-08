# Test Refactoring Notes

## Fixes Implemented

1.  **Resolved `getToken` Ambiguity in `TrustStatement` and `ContentStatement`**
    *   **Issue**: The `getToken(i)` call was picking up a top-level utility function `i(dynamic)` from `package:nerdster/oneofus/util.dart` instead of the `Statement.i` field, causing `Exception: (dynamic) => int`.
    *   **Fix 1**: Updated `TrustStatement` and `ContentStatement` to explicitly use `this.i`.
    *   **Fix 2**: Renamed `i(dynamic)` in `util.dart` to `countNonNull(dynamic)` to prevent future shadowing issues.
    *   **Cleanup**: Updated usages of `i()` in `lib/demotest/demo_key.dart` to `countNonNull()`.

2.  **DemoKey Improvements**
    *   **Objective**: Make `DemoKey` usage stricter regarding Identity vs Delegate roles.
    *   **Action**: Added `DemoIdentity` and `DemoDelegate` wrapper classes in `lib/demotest/demo_key.dart`.
    *   **Usage**: Access via `alice.asIdentity` or `alice.asDelegate`.
    *   **Benefit**: Tests can now strictly enforce which role an actor is playing, preventing logic errors where a single key is confused for both.

## Status

*   All tests in `test/` passed successfully.
*   Reproduction scripts verified the fix.
*   Compilation check verified the new `DemoKey` wrappers.
