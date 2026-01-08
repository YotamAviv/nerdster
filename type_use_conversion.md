# Plan: Type Usage Conversion

This document outlines the plan to refactor the codebase to strictly use `DelegateKey`, `IdentityKey`, and `ContentKey` types instead of raw `String` tokens for statement issuers and subjects. This will prevent confusion and logic errors regarding key roles.

## 1. Refactor `Statement` (Base Class)

*   **Action**: Remove `iToken` (String) from the base `Statement` class entirely.
*   **Strategy**: "Rip off the band-aid".
    *   Move the concept of the issuer key to the subclasses where the specific type (`IdentityKey` vs `DelegateKey`) is known.
    *   `TrustStatement` will implement `IdentityKey get iKey`.
    *   `ContentStatement` will implement `DelegateKey get iKey`.
    *   Any code relying on the generic `Statement.iToken` string will intentionally break and must be updated to handle the specific statement type.

## 2. Refactor `TrustStatement`

*   **Objective**: Ensure all key-related properties return typed Key objects.
*   **Property Map**:
    *   **`iKey`**: Returns `IdentityKey`.
    *   **`subjectKey`**:
        *   If `verb == trust` (Trust/Vouch): Returns `IdentityKey`.
        *   If `verb == block`: Returns `IdentityKey`.
        *   If `verb == delegate`: Returns `DelegateKey`.
        *   If `verb == replace`: Returns `IdentityKey` (target of replacement).
        *   If `verb == clear`: Returns `null` (or throws), as the type depends on what is being cleared.

## 3. Refactor `ContentStatement`

*   **Objective**: Ensure all key-related properties return typed Key objects.
*   **Property Map**:
    *   **`iKey`**: Returns `DelegateKey`.
    *   **`subjectKey`**:
        *   If `verb == rate`: Returns `ContentKey`.
        *   If `verb == follow`: Returns `IdentityKey`.
        *   If `verb == equate`: Returns `ContentKey`.
    *   **`otherSubjectKey`**:
        *   Used in `equate`, `relate`: Returns `ContentKey`.

## 4. Handling `clear` with `clears(Statement)`

Instead of exposing ambiguous typed getters for `clear` statements, we will implement a logic-based method to check if a clear statement applies to a target statement. This encapsulates the type matching logic.

### In `TrustStatement`

```dart
bool clears(TrustStatement other) {
  if (verb != TrustVerb.clear) return false;

  // The 'clear' subject is stored as a raw string in the JSON/Token.
  // We compare it against the target's typed key value.
  
  // If other is simple identity trust (trust, block)
  if (other.verb == TrustVerb.trust || other.verb == TrustVerb.block) {
    return other.subjectKey.value == subjectToken;
  }
  
  // If other is delegation
  if (other.verb == TrustVerb.delegate) {
    return other.subjectKey.value == subjectToken; // subjectKey here is DelegateKey
  }
  
  return subjectToken == other.subjectToken;
}
```

### In `ContentStatement`

```dart
bool clears(ContentStatement other) {
  if (verb != ContentVerb.clear) return false;

  // 1. Basic Subject Match (Target Subject)
  if (other.subjectKey.value != subjectToken) return false;

  // 2. Binary Verbs (Relate/Equate) require matching 'other' subject too.
  if (other.verb == ContentVerb.relate || other.verb == ContentVerb.dontRelate ||
      other.verb == ContentVerb.equate || other.verb == ContentVerb.dontEquate) {
     
     // The clearing statement must also have an 'other' subject defined.
     if (otherSubjectKey == null) return false;

     // Compare the secondary keys.
     return other.otherSubjectKey?.value == otherSubjectKey?.value;
  }
  
  // 3. Unary Verbs (Rate, Follow) only require the primary subject match.
  // (We verified subject match in step 1).
  return true;
}
```

## 5. Refactor `DemoKey`

*   **Objective**: Ensure all key-related properties return typed Key objects.
*   **Property Map**:
    *   **`iKey`**: Returns `DelegateKey`.
        *   *Note*: Content Statements (`org.nerdster`) are always signed by Delegate Keys.
    *   **`subjectKey`**:
        *   If `verb == rate`: Returns `ContentKey`. (Target can be a subject map or a statement token).
        *   If `verb == follow`: Returns `IdentityKey`. (Following a user/identity).
        *   If `verb == equate`: Returns `ContentKey`.
    *   **`otherSubjectKey`**:
        *   Used in `equate`, `relate`: Returns `ContentKey`.

## 4. Refactor `DemoKey`

*   **Objective**: Clean up test helper to enforce typed keys.
*   **Action**:
    *   `DemoKey` should likely hold both an `IdentityKey` (for Trust statements) and a `DelegateKey` (for Content statements), or we split it into `DemoIdentity` and `DemoDelegate`.
    *   Currently, it seems to act as an "Actor" that can sign both.
    *   Update methods `signTrust(...)` and `signContent(...)` to return properly typed statements or accept properly typed targets.

## 5. Implementation Steps (All-at-Once)

1.  **Preparation**:
    *   Ensure `IdentityKey`, `DelegateKey`, `ContentKey` are available globally.
2.  **Breaking Changes**:
    *   Remove `final String iToken` from `Statement_base`.
    *   Implement `IdentityKey get iKey` in `TrustStatement`.
    *   Implement `DelegateKey get iKey` in `ContentStatement`.
    *   Implement typed `subjectKey` getters in both.
3.  **Fix Consumption**:
    *   Fix compile errors in `FeedModel`, `TrustGraph`, `GraphController`, `ContentCard`, etc.
    *   This forces all logic to immediately reckon with the correct key type.
4.  **Fix Tests**:
    *   Update `DemoKey` and test helpers to match the new API.

## Concerns & Questions

*   **Base Class Generics**: Does `Statement` need a generic `KeyType get iKey`? Probably not, just rely on concrete subclasses.
*   **Jsonish Compatibility**: The backing store is `Jsonish` (Strings). The typed getters will be wrappers around `jsonish['I']['val']` or similar.
*   **String Tokens**: Most "Keys" are just Strings (SHA-256 or base64 keys). The `extension type` wrapper is zero-cost, but we need to ensure we don't accidentally unwrap and re-wrap incorrectly.
*   **Test Data**: Extensive string-based test data in `simpsons_data_helper.dart` will need updating or wrapping.
