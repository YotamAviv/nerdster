# Nerdster Content & Follow Network Requirements

## Overview
Nerdster is a decentralized content aggregation platform built on the **Identity Layer**. This document defines the requirements for content statements (`org.nerdster`) and the logic for building the **Follow Network** that determines which content is visible to a user.

**Core Principle**: All participants in the network are humans with singular **identity keys**. The Follow Network is built exclusively upon the Identity Web of Trust; content is only aggregated from identities that are reachable from the user's Point of View (PoV).

**Important Distinction**:
*   **Identity Layer (Trust Graph)**: Managed by **Identity Keys**. Nerdster (the app) *cannot* modify this layer (Trust/Block/Replace) because it does not possess the user's private identity key. It only has a delegate key.
*   **Follow Network (Content Layer)**: Managed by **Delegate Keys**. Nerdster *can* modify this layer by issuing `ContentStatement`s with the `follow` verb. This allows users to Follow or Block identities for specific contexts (e.g., `nerd`, `politics`) *on top of* the Identity Layer. You can only follow/block identities that are already established in the Identity Layer.

---

## 1. Expression: Content Statements (`org.nerdster`)

All content in Nerdster is expressed as signed statements with the type `org.nerdster`. These statements are signed by **delegate keys**.

### 1.1. What can be expressed (Verbs)
A statement must contain exactly one of the following verb fields, which points to the **Subject** of the statement.

| Verb | Subject Type | Description |
| :--- | :--- | :--- |
| `rate` | Subject JSON or Token | Expresses an opinion or action on a subject (e.g., a movie, a book, or another statement). |
| `follow` | identity key or Token | Expresses a desire to follow or block an identity in specific contexts. |
| `relate` | Subject JSON or Token | Asserts that the subject is related to `otherSubject`. |
| `dontRelate` | Subject JSON or Token | Asserts that the subject is **not** related to `otherSubject`. |
| `equate` | Subject JSON or Token | Asserts that the subject (e.g., a news article) is identical to `otherSubject` (e.g., another article on the same event). Used to group content and comments under a canonical subject. |
| `dontEquate` | Subject JSON or Token | Asserts that the subject is **not** identical to `otherSubject`. |
| `clear` | Statement Token | Revokes a previous statement. |

### 1.2. Leveraging Tokens
The **Subject** of a statement can be a full JSON object or a **Token** (SHA-1 hash of the Jsonish canonical representation).
*   **Bandwidth & Storage**: Using tokens avoids repeating full metadata for existing items.
*   **Privacy & Censorship**: A `rate` statement with `censor: true` uses the token of the target subject to avoid revealing the objectionable content itself.
*   **Interactions**: Commenting on a **Like**, relating content, or equating subjects use tokens to point to specific statements or entities.

### 1.3. Metadata and Modifiers (The `with` Block)
Additional metadata is stored in an optional `with` object:
*   **`recommend`** (Boolean): Used with `rate`. `true` for a **Like**, `false` for a **Dislike**.
*   **`dismiss`** (Boolean): A personal flag to hide the subject from the user's own view.
*   **`censor`** (Boolean): A request to hide the subject for everyone in the user's trust network.
*   **`otherSubject`** (Any): The target for `relate` or `equate` verbs.
*   **`contexts`** (Map<String, Integer>): Used with `follow`. Maps a context name (e.g., `nerd`, `social`, `music`) to a weight.
    *   `1`: Follow the identity in this context.
    *   `-1`: Block the identity in this context.
    *   Absence of a context is equivalent to a `clear` action for that context.

### 1.4. Examples

#### A Content Statement
Here is an actual `org.nerdster` statement where a user (via their delegate key) recommends a banana bread recipe:

```json
{
  "statement": "org.nerdster",
  "time": "2025-12-23T22:44:27.041183Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "QR3DKTZV1tQDqaxUIu2juG6PHiCvqwuUvuczFBU9ev4"
  },
  "rate": {
    "contentType": "recipe",
    "title": "Banana Banana Bread Recipe (with Video)",
    "url": "https://www.allrecipes.com/recipe/20144/banana-banana-bread/"
  },
  "with": {
    "recommend": true
  },
  "comment": "#nutritious and #delicious",
  "signature": "590a92a30befcd69ae14c6567ef14bc77d36a2b28c4e5584d0f27568aaf6a847910703aedd6f9c639dba5c5731a2bc28e047a81b858ee4f4f5b86d42cfc9f109"
}
```

#### Referencing via Token
If another user wants to comment on this specific recommendation, they would use the **token** of the above statement as their subject:

```json
{
  "statement": "org.nerdster",
  "time": "2025-12-23T22:45:00.000000Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "tUrN6kYdxJnf7xELULF9V1_kT2I6Al6FGyBDlBX65J0"
  },
  "rate": "8faf56d2c0514c592a94e700d333b7e3d707ca57",
  "comment": "I agree, it's delicious!",
  "signature": "..."
}
```

---

## 2. Leverage: The Follow Network

### 2.1. Motivation
The goal is to aggregate content from humans, but not all humans are interesting to us, or interesting regarding specific topics like 'news', 'local', or 'music'. 

The Follow Network allows people to express who is interesting, or interesting for what. Services (including Nerdster) can leverage these expressions to show users content from a curated subset of the global human network. These expressions can be combined across services in clever ways—for example, your Pandora likes could potentially improve someone else's Spotify radio because they followed you for 'music' on Nerdster.

### 2.2. Contexts and Authority
The network can be filtered by "context":
*   **`<identity>`**: Identical to the raw Identity Web of Trust. If you trust their identity, you follow their content.
*   **`<context>`**: A specific topic or community (e.g., `"news"`, `"family"`, `"nerdster"`).

### 2.3. Follow Network Reduction Logic
The Follow Network is reduced from the Identity Web of Trust and Content Statements:
1.  **Initialization**: The network starts with the PoV user and any identity that follows the context itself (e.g., `A follows <news>`).
2.  **Transitive Follows**: If `A` follows `B` for context `C`, and `B` follows `D` for context `C`, then `A` follows `D`.
3.  **Delegate Resolution**: If `A` follows `B`, `A` also follows all identities that `B` has delegated authority to in the Identity Layer.
4.  **Conflict Resolution**: A `block` (-1 weight) at a shorter distance in the trust graph overrides a `follow` (1 weight) at a greater distance.

---

## 3. Content Aggregation: Decentralized Censorship & Equivalence

Once the Follow Network for a context is established, content statements from those identities are aggregated and filtered.

### 3.1. Decentralized Censorship (Proximity Wins)
Nerdster implements a proximity-based censorship model (Censor-the-Censor):
*   **Censorship Statement**: A `rate` statement with `censor: true`.
*   **Filtering**: If any identity in your Follow Network censors a **Subject** (e.g., a URL) or a specific **Statement Token**, that content is hidden from your view.
*   **Proximity-Based Censorship**: If a trusted censor censors another censor's statement, the second censor's influence is removed. This allows the network to "censor the censors" if they become malicious or overzealous. Since statements are processed in trust order (closest to POV first), a closer node's censorship of a further node's statement takes precedence.

### 3.2. Equivalence Grouping (Canonicalization)
To prevent fragmentation of discussions (e.g., multiple URLs for the same news story), Nerdster uses `equate` statements:
*   **Equivalence Group (EG)**: A set of subjects that are asserted to be identical.
*   **Canonical Token**: Each EG is represented by a single canonical token (usually the token of the first subject discovered in the group).
*   **Aggregation**: All ratings, comments, and relations for any subject in the EG are aggregated under the canonical token.

### 3.3. Relational Discovery
The `relate` verb allows users to build a graph of related content:
*   **Related Subjects**: If `A` relates `Subject1` to `Subject2`, both subjects are marked as related.
*   **Discovery**: When viewing `Subject1`, the system can suggest `Subject2` as relevant context.

---

## 4. Implementation Status (V2)
The V2 implementation (`lib/v2/`) provides pure-function reducers for these layers:
*   `reduceTrustGraph`: Identity Layer reduction.
*   `reduceFollowNetwork`: Follow Network construction.
*   `reduceContentAggregation`: Censorship, Equivalence, and Relational logic.

### 4.1. Context-Specific Behavior
*   **`<nerdster>` (Default)**: 
    *   Includes everyone in the Identity Web of Trust by default.
    *   Explicit `follow` statements can **increase authority** by bringing a distant identity closer to the PoV (distance 1) or **override blocks** from intermediate nodes.
    *   Explicit `block` statements exclude identities otherwise in the WoT.
*   **Custom Contexts**: Only identities explicitly followed in that specific context (e.g., `"music"`, `"movies"`) are included.

This section briefly describes how the Nerdster application currently implements the requirements above. Detailed logic can be found in the code documentation.

### 3.1. Identity Resolution
Content is attributed to an **identity key**. The system verifies a valid `delegate` statement from an identity key to the signing **delegate key** for the `nerdster.org` domain. Statements from multiple delegates of the same identity are merged into a single timeline.

### 3.2. Aggregation & Moderation
1.  **Greedy BFS**: The network is discovered layer-by-layer from the PoV. Closer nodes have higher authority.
2.  **Network Pruning**: If a closer node blocks an identity that a more distant node follows, the block wins.
3.  **Identity-Based Distinct**: For any given subject, only the **most recent** statement from an identity is considered.
4.  **Decentralized Censorship**: Any identity in the Follow Network (within the specified context and degrees) can censor content.
    *   **Censor beats Rate**: If anyone in your network censors a subject, it is hidden from your view, regardless of how many others recommend it.
    *   **Censoring Censorship**: To "uncensor" a subject, one can censor the censor statement itself. The system processes identities in trust order (proximity to PoV). If a censor statement is itself censored by someone more trusted, it is ignored, effectively "uncensoring" its subject for the PoV.
    *   **Transparency & Control**: In the Nerdster implementation, decentralized censorship is opt-in and fully transparent. Users can toggle censorship on or off in their settings and can inspect which identities censored specific subjects.
5.  **Equivalence Grouping**: `equate` statements group different subjects (e.g., multiple URLs for the same news story) into an Equivalence Group (EG). One subject is treated as canonical, and all ratings and comments for any member of the EG are aggregated and displayed together. Disagreements (`dontEquate`) are respected, and all assertions are combined reasonably, prioritizing identities closer to the PoV.
6.  **Relational Discovery**: `relate` statements establish connections between subjects. These relationships are transitive (if X is related to Y, and Y is related to Z, then X is related to Z). Nerdster leverages these connections to display related content alongside the primary subject. Users can also express disagreement via `dontRelate`. All relational assertions are combined reasonably, prioritizing the input of identities closer to the PoV.
