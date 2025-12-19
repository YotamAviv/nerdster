# Trust Statement Semantics

> **Note:** This document is the **Source of Truth** for the V2 implementation. The code must implement the semantics defined here.

## Context: The Two Layers

It is important to distinguish between the **Identity Layer** (ONE-OF-US.NET) and the **Content Layer** (Nerdster).

### 1. Identity Layer (ONE-OF-US.NET)

- **Purpose:** To vouch for the "Identity and Humanity" of others.
- **Action:** People scan each other's QR codes to assert "This is a real human, capable and acting in good faith."
- **Blocking:** In this layer, `block` is a severe assertion. It means "This entity is NOT capable or NOT acting in good faith."
  - _Scope:_ This includes keys that do not represent a human at all (bots, scripts) as well as humans acting in bad faith.
  - _Example:_ A person vouching for bots or creating fake identities for spam is acting in bad faith.
  - _Usage:_ You should **not** block someone here just because you dislike their opinions.

### 2. Content Layer (Nerdster)

- **Purpose:** To share and consume content.
- **Action:** People `follow` other people (perhaps for certain contexts) and `rate` content (this includes relate, equate, and censor).
- **Blocking:** If you dislike someone's content, you simply **do not follow** them (or explicitly `dismiss` them in the content layer). This does not affect their standing as a "human" in the Identity Layer.

## Subject Semantics by Verb

### 1. Identity Verbs (`trust`, `block`, `replace`)

For these verbs, the Subject represents an **Identity** (a person or entity).

- **`trust`**: "I vouch for the humanity and good faith of the person holding Key X."
- **`block`**: "I assert that Key X does not represent a human, or that the person holding Key X is a bad actor (spammer, malicious)."
- **`replace`**: "I (New Key) am replacing Old Key X. X still represents me, but is invalid for new statements as of the time of replacement."

### 2. Delegation Verbs (`delegate`)

For this verb, the Subject represents a **Service Key** (a delegate).

- **`delegate`**: "I delegate Key X to represent me for a specific service (e.g., Nerdster)."
  - **Mechanism:** The user generates a key pair and provides it to the service (e.g., Nerdster). Then, using their main Identity Key (e.g., via the phone app), they publish a statement delegating to this new key.
  - **Revocation:** The user can later `clear` this statement or revoke the delegate key (via `revokeAt`) to invalidate it.
  - The Subject is **NOT** an identity. It is a temporary or device-specific key used for convenience/security.

## Identity Persistence & Vouching Responsibility

### 1. The Decentralized Model

In this system, people do not have "accounts" with a central service. Instead, they have relationships with other people. Your "account" is effectively the collection of people who vouch for you.

### 2. Vouching Responsibility

Vouching (`trust`) is an active responsibility, akin to **Sponsorship**.

- **Sponsorship:** When you trust someone, you are effectively sponsoring their entry into your web of trust. You are the bridge between them and the rest of your network.
- **Maintenance:** If a person you sponsor rotates their key (issues a `replace`), it is good practice to update your direct trust statement to point to their new key.
- **Mechanism:** The `replace` statement is signed by the **New Key**.
  - It claims: "I am the successor to Old Key X."
  - **Validation:** This claim is only accepted if the **New Key** is already trusted (reachable) in the graph.
  - **Equivalence:** Once accepted, the `replace` statement establishes a permanent **Equivalence Set**.
    - The old key and the new key are treated as the same identity.
    - Old statements (e.g., following a music curator) that point to the old key remain valid and meaningful. The software automatically resolves them to the current identity.

### 3. Stable State & Notifications

The system operates on a guarantee: **"Either the graph is in a Stable State, or there are outstanding Notifications."**

#### The Stable State
In a stable state, the graph is consistent and clean:
1.  **Singularity:** You do not directly trust two keys that represent the same person.
2.  **Currency:** Trust edges point to the latest valid key in an equivalence set.
3.  **No Conflicts:** There are no unresolved contradictions (e.g., trusting a blocked key) that require your attention.

#### Notifications as Action Items
If the graph is **not** in a stable state, the system must generate **Notifications** for the user. These are not just informational; they are calls to action to restore stability.

To avoid **Notification Fatigue**, the system focuses on events that directly affect the people you have **Sponsored** (directly trusted).
*   *Example:* "Key A (who you sponsor) replaced by Key B. Update your trust?" (Restores Currency)
*   *Example:* "You trust A and B, but A blocks B. Resolve conflict?" (Restores Consistency)
*   *Example:* "You blocked A, who is now replaced by B. Block B too?" (Prevents Block Evasion)

The algorithm's job is to identify these unstable states and prompt the human to resolve them.

## Design Consideration: Blocking across Key Rotation

- **Scenario:** Person A blocks Key B1. Key B1 is replaced by Key B2. Mutual friend C trusts B2.
- **Relevance:** This scenario only matters if B2 is actually present in the graph (e.g., introduced by C).
- **The Risk (Block Evasion):** If A simply ignores B1 (due to the block), A might not see the `replace` link. A might then trust B2 via C, inadvertently circumventing their own block.
- **The Solution (Notification):**
  - The system must detect that B2 is claimed to be a successor of the blocked B1.
  - Instead of automatically blocking B2 (which might be unfair in a compromise recovery) or automatically trusting B2 (which evades the block), the system should **Notify Person A**.
  - _Notification:_ "You blocked Key B1. B1 claims to be replaced by Key B2. Do you want to block B2 as well?"

## Implications for V2 Logic

- **Graph Traversal:** We traverse edges defined by `trust` and `replace`.
- **Delegation:** We do **not** traverse `delegate` edges as trust relationships. Instead, `delegate` statements are used to validate signatures from those delegate keys.

## Revocation Semantics (`revokeAt`)

The `revokeAt` field is a critical security mechanism used primarily with `replace` (key rotation) and `delegate` statements.

### 1. The Mechanism: Token vs. Timestamp

`revokeAt` points to a specific **Statement Token** (hash), not a timestamp.

- **Precision:** Timestamps can be ambiguous (multiple events in one second) or spoofed (backdated). A Token is a cryptographic pointer to a specific event in the Notary Chain.
- **Causal Anchoring:** It defines an exact cut-off point in the history.

### 2. Partial Validity & History Preservation

When a key is lost or compromised, the person issues a `replace` statement from their **New Key**.

- **The Problem:** If we simply "revoke" the old key, we lose the person's entire history signed by that key.
- **The Solution:** The person specifies `revokeAt: <Token of Last Valid Statement>` in the `replace` statement.
  - **Before:** All statements signed by the old key **up to and including** the `revokeAt` statement remain **VALID**.
  - **After:** Any statement signed by the old key that appears **after** the `revokeAt` statement in the chain (or in a fork) is **INVALID**.

This allows a person to recover from a hack without erasing their digital existence. The system trusts the "Old Self" up until the moment of the hack, and trusts the "New Self" from that point forward.

## Conflict Resolution & Algorithm Philosophy

### 1. Conflicts & Errors

- **Conflicts:** A conflict occurs when different keys provide contradictory information.
  - _Example:_ I trust A and B, but A blocks B.
- **Errors:** Even with **no** conflicts, the graph is not guaranteed to be perfect. There may be undetected bad actors or erroneous trust assignments.

### 2. The "First Wins" Rule (BFS Traversal)

We use a simple **Breadth-First Search (BFS)** to traverse the graph. "First" refers to the order in which we encounter keys/statements during this traversal.

- **Distance Priority:** Keys closer to the observer are processed first.
  - _Example:_ If I trust A (Distance 1) and A trusts B (Distance 2), A is "ahead" of B.
- **Resolution:** The first definitive status (Trusted or Blocked) established for a key "wins".
  - Any subsequent conflicting statements (from keys further away or processed later) are ignored, even if they outnumber the first one.
- **Deterministic Order:** For keys at the same distance, a deterministic sorting ensures the "First" is consistent.

### 3. Human Resolution

The algorithm chooses a winner to maintain consistency, but it doesn't "solve" the social problem.

- **Notification:** The system should notify the involved parties so they can communicate.
- **Action:** Actual people must resolve the conflict (e.g., A unblocks B, or I stop trusting A).

### 4. Known Weaknesses & Future Work

- **Blocking Evidence:** Currently, `block` does not require pointing to a specific "offending statement". Requiring evidence would be robust but difficult for users to provide (UX challenge). We defer this for now.
