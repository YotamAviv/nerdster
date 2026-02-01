NOTE: This is duplicated in the other project

# Key Visualization Specification

This document outlines the visual representation rules for cryptographic keys within the application (e.g., Node Details, Sign In, Key Info).

## Color Scheme
*   **Identity Keys**: Green (`Colors.green`)
*   **Delegate Keys**: Blue (`Colors.blue`)

## Iconography
*   **Status**:
    *   **Active**: Standard Key Icon (e.g., `Icons.vpn_key` or `Icons.key`).
    *   **Revoked / Replaced**: Crossed-out Key Icon (e.g., `Icons.key_off`).


## Ownership / Possession
*   **Owned (Private Key Held)**: Solid / Filled Icon.
    *   Specifically applied to the **current active signing delegate key**.
    *   Visual cue: Standard Material filled icon style.
*   **Public (Others)**: Outline Icon.
    *   Visual cue: Outlined icon style (e.g., `Icons.vpn_key_outlined`).

## Common Widget
A `KeyIcon` widget should be used to enforce these rules centrally.

```dart
KeyIcon(
  type: KeyType.identity | KeyType.delegate,
  status: KeyStatus.active | KeyStatus.revoked, 
  isOwned: boolean
)
```
