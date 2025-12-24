# Delegate Services and Keys

The Delegate Service is a core component enabling the use of singular identities. It enables users to securely sign in to third-party applications (like Nerdster) and authorize those applications to act on their behalf using **delegate keys**.

Users issue **delegate keys** (App Keys) for specific domains (e.g., `nerdster.org`) by:

1.  Signing and publishing a **Delegate Statement** using their **identity key**.
2.  Giving the delegate key pair to a service to sign content on their behalf.

This separation allows users to:

1.  Keep their **identity key** secure.
2.  Manage delegate keys independently (rotate or revoke without service participation).
3.  Maintain a single identity across multiple services.

## Validity Conditions

Content signed by a delegate key is valid if:
- It is delegated by a statement signed by the issuer's **identity key**.
- The key is not revoked, or the content was signed before the `revokeAt` time.

## Examples

### 1. Active Delegation
A standard delegation to a key for use on Nerdster.
```json
{
  "statement": "net.one-of-us",
  "time": "2025-12-23T22:25:49.251554Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "tUrN6kYdxJnf7xELULF9V1_kT2I6Al6FGyBDlBX65J0"
  },
  "delegate": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "I4JaK2WOkjQEE3Bd3JRAqUDMGxJnYowpenRRmQW0gFc"
  },
  "with": {
    "domain": "nerdster.org"
  },
  "signature": "ae0f4e2caddae092f779f1e3c993ecbaed9d07ed97d7e4b6d48cb96a0fba6cb0e8ccc27b9468f93a5da609dca821ae3e699bf6eb55c45fb55a6a9736b2657c00"
}
```

### 2. Revoked at a Statement
This key was valid until the statement with token `Statement_X` was signed. Content signed after `Statement_X` is invalid.
```json
{
  "statement": "net.one-of-us",
  "time": "2025-12-23T22:25:49.281668Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "tUrN6kYdxJnf7xELULF9V1_kT2I6Al6FGyBDlBX65J0"
  },
  "delegate": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "I4JaK2WOkjQEE3Bd3JRAqUDMGxJnYowpenRRmQW0gFc"
  },
  "with": {
    "revokeAt": "d088a77ce833b7dfea62c3714fcc0ef07c7baee8",
    "domain": "nerdster.org"
  },
  "previous": "631acb4af55dbaac76a96e64ad5304f77168da0f",
  "signature": "05f6e3bdaafd3657a288702152ee321c8d0d4948984e7d6527b5f4bc97c3cb61e29e4a58ca629d8185010986fdd4a19e4de57b556c8bac3b06ec7e4e06e5a509"
}
```

### 3. Revoked Immediately (Since Always)
This key is declared but immediately revoked, rendering it invalid for any content signing.
```json
{
  "statement": "net.one-of-us",
  "time": "2025-12-23T22:25:49.292696Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "tUrN6kYdxJnf7xELULF9V1_kT2I6Al6FGyBDlBX65J0"
  },
  "delegate": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "I4JaK2WOkjQEE3Bd3JRAqUDMGxJnYowpenRRmQW0gFc"
  },
  "with": {
    "revokeAt": "<since always>",
    "domain": "nerdster.org"
  },
  "previous": "2e9ddc2c9251eb64d85181194a8d689e692269e5",
  "signature": "a32aefbbc1007c1acfc56fc2155ee2704c71118fb1fad24d73e0a45ed9e96c5a715708426a59d04ac936220867c47be2c27908c7e657804f68091becd5db3409"
}
```
