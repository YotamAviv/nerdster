
[aviv]: this doc is nearly useless, and no matter how I ask Agent to make it not useless, it ramains. Do not trust anything here.

# V2 Implementation Status

> **Date:** December 20, 2025
> **Focus:** Functional Data Pipeline & Trust Graph Logic

## 1. Architecture Overview

The V2 architecture moves away from stateful singletons (`OneofusNet`) towards a functional **Data Pipeline**.

### The Pipeline
1.  **Source**: Fetches raw JSON statements from the backend (Cloud Functions or Firestore).
2.  **Jsonish**: Wraps JSON data. Supports two modes:
    *   **Calculated Token**: Hashes the canonical JSON (requires full data).
    *   **Server Token**: Trusts the ID provided by the server (enables bandwidth optimization).
3.  **Trust Logic**: A pure function (`reduceTrustGraph`) that takes a graph and new statements to produce a new graph.
4.  **Orchestrator**: Manages the fetch-reduce loop.

## 2. Optimization Strategy

To reduce bandwidth, the `CloudFunctionsSource` requests optimized payloads from the server:
*   **Omit**: Large fields like `statement` (type) and `I` (public key) are omitted.
*   **Include ID**: The server returns the authoritative SHA-1 token in the `id` field.
*   **Reconstruction**: The client reconstructs the missing fields for UI compatibility but uses the provided `id` as the `serverToken` for `Jsonish`. This bypasses the need to hash the (imperfectly reconstructed) JSON on the client.

*See `docs/optimization_strategy.md` for details.*

## 3. Testing & Verification

### Integration Testing
We use `flutter drive` to run integration tests that verify the full pipeline against a local emulator.

**Prerequisites:**
Start the `one-of-us-net` emulator with the snapshot data:
```bash
firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start --import exports/oneofus-25-12-02--17-18/
```

**Running the Test:**
```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/v2_basic_test.dart -d web-server
```

**Coverage (`v2_basic_test.dart`):**
*   **Scenario**: Builds a trust graph from Marge's perspective using the "Simpsons" dataset.
*   **Permutations**: Iterates through 4 optimization configurations to ensure robustness:
    1.  **No Optimization**: Full JSON payload.
    2.  **Omit Statement**: `statement` field missing.
    3.  **Omit I**: `I` (public key) field missing.
    4.  **Full Optimization**: Both fields missing.
*   **Assertions**: Verifies that Marge correctly trusts Lisa and Bart at distance 1 in all cases.

## 4. Component Status

| Component | Status | Notes |
| :--- | :--- | :--- |
| **Trust Logic** | ✅ Stable | Pure functional core. Handles trust, block, replace, revokeAt. |
| **Cloud Source** | ✅ Stable | Supports `omit` optimization and `serverToken`. |
| **Jsonish** | ✅ Stable | Updated to support `serverToken` injection. |
| **Orchestrator** | 🚧 Beta | Basic fetch-reduce loop working. |
| **UI (Shadow View)** | 🚧 Beta | Debug view available. Needs Content Tree adapter. |

## 5. Next Steps

1.  **Content Tree**: Implement a `ContentTree` adapter to visualize content hierarchies in the Shadow View.
2.  **Migration**: Plan the replacement of V1 singletons (`OneofusNet`, `FollowNet`) with the V2 pipeline.
