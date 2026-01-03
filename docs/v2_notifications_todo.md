# V2 Notifications TODO

This document tracks legacy notifications (from V1) that appear to be missing or silently handled in the V2 architecture. These should be implemented as `TrustNotification`s to provide visibility into network conflicts and data integrity issues.

## 1. Delegate Conflicts (`delegateAlreadyClaimed`)

*   **Legacy Concept:** "Delegate already claimed."
*   **Location:** `lib/v2/delegates.dart` inside `DelegateResolver.resolveForIdentity`.
*   **Current Behavior:** The code silently ignores subsequent claims:
    ```dart
    if (!_delegateToIdentity.containsKey(delegateKey)) {
      // ... claims delegate
    }
    ```
    The first identity to claim a delegate key wins (based on proximity/trust order), but no notification is generated for the conflict.
*   **Action:** Detect when a delegate key is claimed by multiple identities and generate a `TrustNotification`.

## 2. Equivalence Rejection (`Web-of-trust key equivalence rejected`)

*   **Legacy Concept:** "Web-of-trust key equivalence rejected."
*   **Location:** `lib/v2/content_logic.dart` calling `lib/equivalence/equivalence.dart`.
*   **Current Behavior:** `reduceContentAggregation` calls `eqLogic.process()`, which returns a boolean indicating success or failure.
    ```dart
    eqLogic.process(EquateStatement(...)); // Return value ignored
    ```
    If an equivalence statement is rejected (e.g., due to a conflict with an existing group or a `dontEquate` statement), it fails silently.
*   **Action:** Capture the return value of `eqLogic.process()`. If `false`, generate a `TrustNotification` explaining the equivalence conflict.

## 3. Data Corruption (`CorruptionProblem`)

*   **Legacy Concept:** Notary Chain Violations and Time Violations.
*   **Location:** `lib/v2/direct_firestore_source.dart`.
*   **Current Behavior:** The code detects violations and prints to console:
    ```dart
    print('Notary Chain Violation ($token)');
    print('Time Violation ($token)');
    ```
    It breaks the processing loop but does not surface these errors to the UI or the `V2FeedModel`.
*   **Action:** Surface these as formal `TrustNotification` objects (or a specific `CorruptionNotification` subclass) so the user knows a feed source is corrupted.

## 4. Replacement Conflicts (`replaceReplacedKey`)

*   **Legacy Concept:** "Attempt to replace a replaced key."
*   **Location:** `lib/v2/trust_logic.dart`.
*   **Current Behavior:** V2 handles "Key replaced by both X and Y" as a conflict notification. However, the specific legacy case (replacing a key that has already been replaced by someone else in a way that violates the graph structure) might need explicit verification.
*   **Action:** Review `TrustLogic` to ensure all invalid replacement attempts (cycles, double-replacements, replacing blocked keys) generate clear notifications.
