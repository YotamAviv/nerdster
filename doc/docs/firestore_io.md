# Firestore I/O: Reading and Writing Statements

This document describes how Nerdster and ONE-OF-US.NET interact with Google Cloud Firestore to store and retrieve cryptographically signed statements.

## 1. Storage Model

Data is organized by the **Issuer**, allowing the network to efficiently fetch signed content given the token of a cryptographic key.

- **Immutability**: Statements are identified by their cryptographic hash (token). Once written, they are never modified or deleted, ensuring a permanent and verifiable audit trail.
- **Public Access**: All content is public.

## 2. Reading Statements

To build the trust graph and aggregate content, the system must fetch large volumes of statements from many different issuers.

- **Batch Fetching**: The system is designed to fetch statements in bulk to minimize round trips.
- **Bandwidth Optimization**: Redundant data (such as repeated public keys or protocol identifiers) can be omitted during transport.

## 3. Cloud Functions Interface

The system exposes an optimized HTTP interface for fetching statements in bulk. This is the primary read path for production clients.

### 3.1. The `export` Endpoint

Mapped to `https://export.nerdster.org` (or the project's Cloud Functions URL), this endpoint returns a stream of statements.

- **Method**: `GET`
- **Parameters**:
  - `spec` (Required): A specification of which issuers to fetch. Can be:
    - A single **Issuer Token**.
    - A JSON object: `{"issuerToken": "revokeAtToken"}`.
    - A JSON array of the above.
  - `omit`: A list of fields to exclude from the response (e.g., `['I', 'statement']`) to save bandwidth.
  - `includeId`: Boolean. If true, includes the statement's authoritative token as an `id` field.
  - `distinct`: Boolean. If true, the server filters out redundant statements (e.g., multiple ratings for the same subject).
  - `after`: A timestamp. Only returns statements issued after this time.
  - `checkPrevious`: Boolean. If true, the server validates the notary chain integrity before returning data.
- **Response**: A newline-delimited JSON stream. Each line is an object mapping the **Issuer Token** to a list of their statements:
  ```json
  {"issuerTokenA": [ {...}, {...} ]}
  {"issuerTokenB": [ {...} ]}
  ```

## 4. Writing Statements

- **Notary Chain Integrity**: Every statement must link to the one that preceded it to prevent back-dating or statement omission. This creates a linear, chronological history for every issuer that cannot be reordered or tampered with.
- **Transactional Consistency**: While the system requires a linear chain, the current client-side implementation (using the Flutter Firestore SDK) cannot perform atomic "read-then-write" operations on the collection. This means that if multiple devices write simultaneously, the notary chain may fork. However, the system **does** use transactions to ensure that the same exact statement (same token) is never written twice, throwing an exception if a duplicate is detected.

### 4.1. Transactional Requirements (Ideal)

To maintain a single authoritative timeline, the following should be true for every write:

1. **Idempotency**: The statement being written must not already exist.
2. **Chain Continuity**: If the statement has a `previous` field, it must match the most recent statement in the issuer's collection.

## 5. Security and Integrity

The integrity of the data is protected by both cryptography and database-level constraints.

- **Cryptographic Verification**: While the cloud stores the data, the client is responsible for verifying the signatures and hashes. The cloud is a "dumb" relay; it does not need to be trusted to provide correct data, only to store what it is given.
- **Append-Only Rules**: Database security rules enforce an append-only model for statements. Once written, statements are immutable. This prevents malicious actors (or even the user themselves) from erasing or altering the historical record of trust and content.

