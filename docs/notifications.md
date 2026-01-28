# V2 Notifications

## Detected Notifications (Implemented)

### Trust Logic (Identity Layer)

1.  **Self-Block Attempt**
    *   **Reason:** "Attempt to block your key."
    *   **Type:** Conflict
    *   **Cause:** An issuer in the trust graph attempts to block the POV's key.

2.  **Self-Replace Attempt**
    *   **Reason:** "Attempt to replace your key."
    *   **Type:** Conflict
    *   **Cause:** An issuer
    
3.  **Trusted Key Block Attempt**
    *   **Reason:** "Attempt to block trusted key by $issuer"
    *   **Type:** Conflict
    *   **Cause:** An issuer attempts to block a key that is already trusted.

4.  **Double Replacement**
    *   **Reason:** "Key $oldKey replaced by both $existingNewKey and $issuer"
    *   **Type:** Conflict
    *   **Cause:** Two different issuers attempt to replace the same key with different new keys.

5.  **Trust Blocked Key**
    *   **Reason:** "Attempt to trust blocked key by $issuer"
    *   **Type:** Conflict
    *   **Cause:** An issuer attempts to trust a key that has been blocked.

6.  **Blocked Key Replacement**
    *   **Reason:** "Blocked key $oldKey is being replaced by $issuer"
    *   **Type:** Notification (Info)
    *   **Cause:** An issuer attempts to replace a key that is already blocked.

7.  **Distant Replacement (Constraint Ignored)**
    *   **Reason:** "Trusted key $oldKey is being replaced by $issuer (Replacement constraint ignored due to distance)"
    *   **Type:** Notification (Info)
    *   **Cause:** A replacement is found for a trusted key, but the replacement comes from a distance greater than the key's current distance (so it doesn't override the existing trust path, but is noted).

8.  **Trusted Key Replacement**
    *   **Reason:** "Trusted key $oldKey is being replaced by $issuer"
    *   **Type:** Notification (Info)
    *   **Cause:** A trusted key is being replaced by another key. This is a standard key rotation notification.

9.  **Non-Canonical Trust**
    *   **Reason:** "$issuerName trusts a non-canonical key directly (replaced by $effectiveSubject)"
    *   **Type:** Notification (Info)
    *   **Cause:** An issuer trusts a key that has been replaced by another key (canonical identity).

10. **Delegate Already Claimed**
    *   **Reason:** "Delegate key $delegateKey already claimed by $existingIdentity"
    *   **Type:** Conflict
    *   **Cause:** An identity attempts to claim a delegate key that has already been claimed by another identity (which was discovered first/closer).

### Follow Logic (Content Layer)

There are no follow related conflicts or notifications. Being human is fact; if 2 people say that one is and another isn't, then they're in conflict. Appreciating someone's views is opinion.

# Below are legacy notifications (from V1) that appear to be missing or silently handled in the V2 architecture.

## Data Corruption (`CorruptionProblem`)

*   **Legacy Concept:** Notary Chain Violations and Time Violations.
*   **Location:** `lib/v2/direct_firestore_source.dart`.
*   **Current Behavior:** The code detects violations and prints to console:
    ```dart
    print('Notary Chain Violation ($token)');
    print('Time Violation ($token)');
    ```
    It breaks the processing loop but does not surface these errors to the UI or the `V2FeedModel`.
*   **Action:** Surface these as formal `TrustNotification` objects (or a specific `CorruptionNotification` subclass) so the user knows a feed source is corrupted.
