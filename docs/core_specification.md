# Core Specification

## 1. Data Structures & Cryptography

The protocol relies on asymmetric cryptography to establish identity and data integrity.

- **Keys:** Users control **Identity Keys** (long-term) and issue **Delegate Keys** (app-specific) to devices. Keys are represented as JSON Web Keys (JWK).
  ```json
  {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "<Base64 encoded public key>"
  }
  ```
- **Statements:** All data in the system exists as **Statements**—signed JSON objects asserting trust, content, or structural links.

### 1.1. The Token

A **Token** is a hash used to identify data. It can be computed for any JSON object (Keys, Statements, Content Subjects, etc.).

- **Algorithm:** SHA-1.
- **Input:** The canonical, pretty-printed JSON representation of the object.
- **Format:** Hexadecimal string.

> **CRITICAL:** The canonicalization rules and hashing algorithm (SHA-1) **MUST NOT CHANGE**. Changing them would result in different token values, breaking critical system functions including:
>
> - **Fetching:** We use a Key's token (**identity key** or **delegate key**) to query for statements issued by that key.
> - **Notary Chain:** The `previous` link is the token of the prior statement.
> - **Censorship:** Censorship statements use the _token_ of the subject (to avoid repeating the objectionable content), not the subject itself.

### 1.2. Statement Structure

Statements are JSON objects. The specific fields depend on the statement type, but they generally follow this pattern:

```json
{
  "statement": "<type identifier (e.g., net.one-of-us)>",
  "time": "<ISO-8601 Timestamp>",
  "I": <Identity public Key JSON>,
  "<verb>": <Subject JSON or Token>,
  "with": {
     "moniker": "...",
     "revokeAt": "...",
     "domain": "..."
  },
  "comment": "...",
  "previous": "<Token of previous statement>",
  "signature": "<Crypto Signature>"
}
```

- **`statement`**: Identifies the protocol/type (e.g., `net.one-of-us` for Identity Layer statements).
- **`I`**: The Issuer's public key (as a JSON object). This is either an **identity key** or a **delegate key**.
- **`<verb>`**: The key corresponding to the action (e.g., `trust`, `block`, `rate`). The value is the **Subject** of the statement.
- **`with`**: Optional metadata associated with the action (e.g., `revokeAt` for delegation/replacement).
- **`previous`**: The Notary Chain link.
- **`signature`**: The cryptographic signature.

### 1.3. Transport Optimization

To reduce bandwidth, the system supports an optimized transport format where redundant fields (`statement`, `I`) are omitted during transmission and reconstructed by the client. See [Firestore I/O](firestore_io.md) for details.

## 2. Trust Semantics


#### 1.2.1. Nerdster Content Statements

Nerdster uses the `org.nerdster` statement type.

```json
{
  "statement": "org.nerdster",
  "time": "...",
  "I": <Delegate Public Key JSON>,
  "<verb>": <Subject JSON or Token>,
  "with": {
     "recommend": true, // "Like"
     "dismiss": true,
     "censor": true,
     "otherSubject": "...", // For relate/equate
     "contexts": {...} // For follow
  },
  "comment": "...",
  "previous": "...",
  "signature": "..."
}
```

- **Verbs:** `rate`, `relate`, `dontRelate`, `equate`, `dontEquate`, `follow`, `clear`.
- **`with` Fields:**
  - `recommend`: Boolean. True = Like/Recommend.
  - `dismiss`: Boolean. True = Dismiss/Hide.
  - `censor`: Boolean. True = Censor (Subject must be a token).
  - `otherSubject`: The second subject for `relate`/`equate` verbs.
  - `contexts`: A map defining contexts for `follow` statements.

### 1.3. Canonicalization and Signing

To ensure consistent hashing and verifiable signatures, statements follow a strict multi-step process.

#### 1.3.1. Canonicalization Rules

JSON objects are ordered before any string conversion:

1.  **Known Keys First:** Keys are sorted based on a predefined precedence list.
    - Order: `statement`, `time`, `I`, `trust`, `block`, `replace`, `delegate`, `clear`, `rate`, `relate`, `dontRelate`, `equate`, `dontEquate`, `follow`, `with`, `other`, `moniker`, `revokeAt`, `domain`, `tags`, `recommend`, `dismiss`, `censor`, `stars`, `comment`, `contentType`, `previous`.
2.  **Unknown Keys:** Any keys not in the known list are sorted **alphabetically** and placed _after_ the known keys.
3.  **Signature Last:** The `signature` key is **always** placed at the very end of the map.

#### 1.3.2. Formatting Rules

- **Indentation:** 2 spaces (`JsonEncoder.withIndent('  ')`).
- **Encoding:** UTF-8.
- **Recursion:** Nested maps are also recursively ordered. Lists preserve their element order, but the elements themselves are canonicalized.

#### 1.3.3. The Signing Sequence

To sign a statement:
1.  **Prepare**: Create the JSON object with all fields **except** `signature`.
2.  **Canonicalize**: Apply the ordering and formatting rules above to produce a pretty-printed string.
3.  **Sign**: Calculate the cryptographic signature of this string.
4.  **Finalize**: Add the `"signature"` key to the JSON object.

#### 1.3.4. Token Generation

The **Token** (the object's unique ID) is generated **after** signing:
1.  **Canonicalize**: Apply the ordering and formatting rules to the *complete* object (including the signature).
2.  **Hash**: Calculate the **SHA-1** hash of the resulting pretty-printed string.
3.  **Format**: Represent the hash as a hexadecimal string.

### 1.4. The Notary Chain

The **Notary Chain** is a fundamental security and integrity mechanism. It ensures that the history of statements made by an identity is linear, tamper-evident, and immutable, preventing **backdating** or selective omission of statements.

#### 1.4.1. Concept

Every statement published by an identity contains a cryptographic link to the immediately preceding statement. This creates a blockchain-like structure (a hash chain) for each individual identity.

#### 1.4.2. Mechanism

1.  **`previous` Field**: Each statement (except the very first one) includes the hash (token) of the previous statement.
2.  **`signature`**: The statement, including the `previous` field, is signed by the identity's private key.

#### 1.4.3. Verification

To verify an identity's feed:

1.  **Fetch** the statements.
2.  **Order** them by time (Newest to Oldest).
3.  **Traverse** the chain:
    - Ensure the `previous` field of statement $N$ matches the `token` (hash) of statement $N+1$ (the older one).
    - Ensure timestamps are strictly descending.

#### 1.4.4. Consequences of Violation

If a gap or mismatch is found in the chain (e.g., Statement A points to B, but the aggregator presents C instead of B), the **entire chain is considered corrupt**. The client must reject the data completely. This forces aggregators to either present the full, unaltered history or nothing at all. They cannot selectively edit the past.

### 1.5. Singular Disposition

The protocol enforces a **Singular Disposition** model (also known as "Latest-Write-Wins" per subject).

#### 1.5.1. The Principle
One key's disposition towards another is singular. If you trust a key and then block it, only the most recent statement is your key's disposition towards the other.

*   **Overwrite (Re-state):** You can re-state any statement (e.g., updating "moniker" or "comment"). This will override whatever you previously stated.
*   **Clear (Erase):** The `clear` verb acts as "erase". If you trust a key and then clear the key, it's like you never said anything at all. Whatever you do can always be undone.

#### 1.5.2. Mechanism
To enforce this, the system uses a **Distinct Signature** for filtering:
*   **Trust Statements:** `Issuer:Subject` (e.g., `Alice:Bob`).
*   **Content Statements:** `Issuer:Subject` (or `Issuer:Subject:Other` for relationships).

When processing a stream of statements:
1.  Sort statements by time (Newest First).
2.  Iterate through the list.
3.  Keep the **first** statement seen for each unique Signature.
4.  Discard the rest.

### 1.6. Example: Censorship via Token

Tokens allow referring to content without repeating it. This is critical for censorship, where repeating the objectionable content would be counter-productive.

**Content Object:**

```json
{
  "contentType": "movie",
  "title": "Caught Stealing",
  "year": "2025"
}
```

**Censorship Statement:**
The statement targets the **Token** of the content, not the content itself.

```json
{
  "statement": "org.nerdster",
  ...
  "censor": "<SHA-1 Token of the content object>"
}
```

### 1.7. Immutability & Schema Constraints

The schema defined in this document is **cryptographically frozen**.

*   **Signed Data:** Every statement is signed by a person's private key.
*   **No Migration:** It is impossible to "migrate" existing data to a new schema (e.g., renaming a field) because doing so would change the hash, invalidating the signature. We cannot re-sign the data because we do not possess the users' private keys.
*   **Backward Compatibility:** The codebase must **always** be able to parse and validate valid statements from the past. New features can be added (e.g., new optional fields), but existing structures must remain supported indefinitely.

## 2. The Identity Network

The **Identity Network** is the foundational layer of trust. It is a graph of **Identity Keys** connected by statements that vouch for the identity and that subject is "human, capable, and acting in good faith".

> For detailed semantics on trust, blocking, and the distinction between Identity and Content layers, refer to `docs/trust_statement_semantics.md`.

- **Trust:** A `trust` statement is a strong assertion that the subject is a real human acting in good faith. It is the mechanism by which the network grows.
- **Block:** A `block` statement in this layer is a severe assertion. It signifies that the subject is a bad actor (e.g., a bot, a spammer, or a malicious entity), not merely someone with disagreeable opinions.
- **Replace:** Users may rotate their keys using `replace` statements. This allows a new key to take over the identity and reputation of an old key, ensuring continuity without central authority.

### 2.1. Philosophy & Goals

The goal is to create a **Web of Trust** where:

1.  **Subjectivity:** There is no global "truth" about who is trusted. Each user's view of the network is calculated relative to their own trust anchors.
2.  **Resilience:** The network is resistant to Sybil attacks and censorship because trust must be earned through human connection.
3.  **Autonomy:** Users own their identity (keys) and their social graph, independent of any specific application or server.

This network establishes _who_ is trusted. It does not contain application-specific data (like movie ratings), only trust relationships.

## 3. The Delegate Network & Follow Contexts

The **Delegate Network** is the graph used for application-level interactions (Nerdster). It is distinct from the Identity Network but anchored by it.

### 3.1. Derivation Process

1.  **Identity Trust:** First, the system calculates the **Identity Network**. This results in an **ordered list of trusted Identity Keys**.
2.  **Delegation:** For every trusted Identity Key, the system identifies valid `delegate` statements. This produces an **ordered list of Delegate Keys** (App Keys) that represent those identities.
3.  **Follow Contexts:**
    - **Follow Statements:** Delegate Keys can sign `follow` statements targeting other identities or delegates. These statements are specific to a **context** (e.g., 'music', 'news').
    - **The `<nerdster>` Default:** The `<nerdster>` context is special. By default, a user implicitly follows (in the `<nerdster>` context) everyone they have vouched for in the Identity Layer.
    - **Overrides:** Users can explicitly sign `follow` or `block` statements in the `<nerdster>` context to override this default (e.g., following someone they haven't vouched for, or blocking someone they have).
    - **Signatures:** Crucially, `follow` statements are signed by **Delegate Keys** (App Keys), whereas `trust` statements are signed by **Identity Keys**.

## 4. Storage & Sync Requirements

The storage and synchronization layer must support the specific access patterns of the Trust Graph while minimizing latency and bandwidth.

- **Storage Pattern:** Statements are sharded by **Issuer** (Identity/Delegate Key) and indexed by **Time**. This aligns with the graph traversal algorithm, which discovers keys and then fetches their feeds.

### 4.1. Optimization Goals

- **Minimize Round Trips:** The client must be able to request statements for multiple keys in a single network call (Batching).
- **Minimize Bandwidth:**
  - **Field Omission:** The server should omit redundant data (like the Issuer's public key) that the client already possesses.
  - **Server-Side Filtering:** The server should filter out revoked or redundant (non-distinct) statements before transmission.

### 4.2. Testing Requirements

- **Environment Independence:** The system must be testable in environments without a live backend (e.g., Linux CI, local unit tests).
- **Logic Replication:** Because test doubles (like `FakeFirestore`) cannot execute server-side logic (Cloud Functions), critical logic such as revocation filtering and distinctness checks must be available in the client codebase to support realistic unit testing.
