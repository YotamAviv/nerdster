# Trust Statement Semantics

## Scope: The Identity Layer (ONE-OF-US.NET)

This document defines the semantics of the verbs used in the **Identity Layer**. These statements are used to build the Web of Trust.

- **Purpose:** To vouch for the "Identity and Humanity" of others.
- **Assertion:** "This is a real human, capable and acting in good faith."

## Subject Semantics by Verb

### 1. Identity Verbs (`trust`, `block`, `replace`)

For these verbs, the Subject represents an **Identity** (a person or entity).

- **`trust`**: "I vouch for the humanity and good faith of the person holding Key X."
    - *Implication:* I am willing to introduce this person to my network.
- **`block`**: "I assert that Key X does not represent a human, or that the person holding Key X is a bad actor (spammer, malicious)."
    - *Implication:* This key should be excluded from the network.
- **`replace`**: "I (New Key) am replacing Old Key X. X still represents me, but all its statements are revoked."
    - *Implication:* All trust and reputation associated with Old Key X should transfer to New Key.
    - The old key is always revoked since always. The user restates what they want to preserve using the new key.

### 2. Delegation Verbs (`delegate`)

For this verb, the Subject represents a **Service Key** (a delegate).

- **`delegate`**: "I delegate Key X to represent me for a specific service (e.g., Nerdster)."
    - *Implication:* Statements signed by Key X should be treated as if they were signed by me, within the scope of the service.
    - *Note:* The Subject is **NOT** an identity. It is a temporary or device-specific key.

## Revocation Semantics (`revokeAt`)

The `revokeAt` field is a modifier that can be attached to `delegate` statements.

- **Meaning:** "The delegated key is only valid for statements issued *up to and including* the token specified in `revokeAt`."
- **Use Case:** Revoking a specific delegate key at a point in time, while leaving others intact.
- **`"<since always>"`:** The special sentinel string that revokes all statements from the delegate.

Note: `revokeAt` on `replace` statements must be `"<since always>"`; any other value throws `UnimplementedError`.
