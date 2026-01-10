# Content Statement Semantics

While the Identity Layer (ONE-OF-US.NET) handles "who is human," the Nerdster contributes to the **Affinity Layer**, "what is interesting."

High-level subjects (books, movies, etc.) are structured in JSON and have a `ContentType`.
Example:
```json
{
    "contentType": "movie",
    "title": "Caught Stealing",
    "year": "2025"
}
```

People can:
*   rate and comment on content simply (including 'dismiss' to not see it again).
*   censor content (content includes folks' ratings, not just high-level subjects).
*   state that subjects are specifically related, not related, equivalent, or not.
*   `follow` or `block` others for the default `<nerdster>` context or for specific contexts like `music`, `news`, `local`, etc.

## Subject Integrity & Tokenization

Statements about high-level subjects (books, movies, URLs) **must** include the full definition of the subject (the JSON map). This ensures that anyone reading the statement knows exactly what is being discussed without needing to perform a lookup in a separate database.

Exceptions where the **token** is sufficient:
1.  **Rate**: If the subject is another user's statement, OR the `rate` uses `censor` or `dismiss`.
2.  **Follow**: All `follow` statements use the subject token (identity key).
3.  **Clear**: All `clear` statements use the subject token.

*Note: All Relations (`relate`, `equate`, `dontRelate`, `dontEquate`) always use the full subject JSON to maintain the graph's discoverability.*

## Verbs

### `follow`
Defines the subscription relationship with another user.
The `<nerdster>` context is a special context used to follow anyone whose identity you've vouched for in the identity layer.
*   **Meaning**: Subscribe to or block content from an identity in specific contexts.
*   **Subject**: Identity token (the public key string).
*   **`with` Clause**: Requires `contexts`, a map of context names to integer values.
    *   `1`: Follow.
    *   `-1`: Block.
*   **Example**:
    ```json
    {
      "follow": <identity key>,
      "with": {
        "contexts": {
          "<nerdster>": 1,
          "music": -1
        }
      }
    }
    ```

### `rate`
Expresses a disposition or opinion about a subject.
*   **Meaning**: Apply a boolean flag to a subject.
*   **`with` Clause**: Supports the following boolean flags:
    *   `recommend`: True to recommend/like.
    *   `dismiss`: True to hide/dismiss.
    *   `censor`: True to censor.
*   **Subject**:
    *   **High-level subjects**: Must be the full JSON object.
        *   *Exception*: If `censor` or `dismiss` is used, the subject **token** is allowed.
    *   **Statements**: Use the statement token (string).
*   **Example**:
    ```json
    {
      "rate": <subject JSON (if high-level) OR subject token (if suppressing or rating a statement)>,
      "with": {
        "recommend": true
      }
    }
    ```

### Dismiss
*   **Meaning**: Hide the subject from the feed.
*   **`with` Clause**: The `dismiss` field can be one of:
    *   `true`: **Dismissed**. The subject is hidden indefinitely, regardless of future activity.
    *   `"snooze"`: **Snoozed**. The subject is hidden until *qualified new activity* occurs.
        *   **Qualified New Activity** (wakes up the subject):
            *   A `rate` statement with a `comment` or `recommend: true`.
            *   Any `relate` statement.
        *   **Disqualified Activity** (does not wake up the subject):
            *   A `rate` statement with `censor` or `dismiss`.
            *   Any `equate`, `dontRelate`, or `dontEquate` statement.
    *   *(Note: `null` and `false` are not used; omitting the `dismiss` field implies the subject is visible.)*
    *   **Re-Snoozing**: A user may issue a new "snooze" statement even if their current disposition is already "snooze". This is necessary to re-hide an item that was woken up by new activity, as the new statement's timestamp will be later than the activity.
*   **Example**:
    ```json
    {
      "rate": <subject JSON>,
      "with": {
        "dismiss": "snooze"
      }
    }
    ```


### `relate` / `dontRelate`
*   **Meaning**: The `subject` is related (or not related) to the `otherSubject`.
*   **`with` Clause**: Requires `otherSubject`.
*   **Example**:
    ```json
    {
      "relate": <Subject JSON>,
      "with": {
        "otherSubject": <Other subject JSON>
      }
    }
    ```

### `equate` / `dontEquate`
*   **Meaning**: The `subject` is equivalent (or not) to the `otherSubject` (e.g., different URLs for the same content).
*   **Subject**: Full JSON object.
*   **`with` Clause**: Requires `otherSubject`.
*   **Example**:
    ```json
    {
      "equate": <Subject JSON>,
      "with": {
        "otherSubject": <Other subject JSON>
      }
    }
    ```

### `clear`
Wipes a previous statement.
*   **Meaning**: Say nothing about the given subject or 2 subject combination.
