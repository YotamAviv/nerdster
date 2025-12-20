# Cloud Functions Optimization Strategy

## Goal
To reduce network bandwidth usage when fetching large numbers of statements from the Cloud Functions endpoint.

## The Optimization
The `CloudFunctionsSource` requests statements with specific optimizations to omit redundant data that the client can reconstruct or doesn't strictly need for identification if the server provides the token.

### 1. Request Parameters
The client sends the following parameters to the `export` Cloud Function:
*   `omit=['statement', 'I']`: Tells the server to exclude the `statement` type string (e.g., "net.one-of-us") and the `I` object (the issuer's public key). These fields are large and repetitive.
*   `includeId=true`: Tells the server to include the document ID (the statement's SHA1 token) in the response as an `id` field.

### 2. Server Response
The server returns a list of JSON objects. Each object:
*   Lacks the `statement` field.
*   Lacks the `I` field.
*   Includes an `id` field containing the statement's authoritative token.

### 3. Client-Side Reconstruction (`CloudFunctionsSource`)
When processing the response:
1.  **Rehydrate Fields**: The client adds the missing `statement` type and a placeholder `I` object (e.g., `{'id': token}`) to the JSON. This ensures the map structure resembles a valid statement for UI/logic consumers.
2.  **Extract Token**: The client extracts the `id` field provided by the server and treats it as the `serverToken`.
3.  **Create Jsonish**: The client instantiates `Jsonish(json, serverToken)`.

### 4. Jsonish Logic
The `Jsonish` class has a specific constructor flow to handle this optimization:
*   **Standard Behavior**: Calculates the token by hashing the canonicalized (ordered) JSON. This requires the *exact* original JSON, including the full `I` (public key).
*   **Optimized Behavior (with `serverToken`)**: If a `serverToken` is passed to the constructor:
    *   It **skips** the hash calculation.
    *   It uses the `serverToken` as the object's identity.
    *   It stores the provided JSON (even if partial/reconstructed) as the underlying data.

### Why This Failed Previously
In the initial attempt, the `omit` optimization was enabled, but `includeId` was missing or not used correctly.
*   The client received partial JSON.
*   It tried to reconstruct `I` with `{'id': token}`.
*   It called `Jsonish(json)` *without* a `serverToken`.
*   `Jsonish` tried to calculate the hash of this reconstructed JSON.
*   Because `{'id': token}` is not the same as the original `{'kty': 'OKP', ...}` public key, the calculated hash was different from the actual statement token.
*   The Trust Logic, relying on exact token matches, failed to link these statements to the graph.

### The Fix
By passing `includeId=true` and using the returned `id` as the `serverToken` in `Jsonish`, we bypass the client-side hashing requirement. We trust the server's assertion of the statement's identity, allowing us to safely omit the bulky `I` field during transport.
