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


## Verbs

### `follow`
Defines the subscription relationship with another user.
The `<nerdster>` context is a special context used to follow anyone whose identity you've vouched for in the identity layer.
*   **Meaning**: Subscribe to or block content from an identity in specific contexts.
*   **`with` Clause**: Requires `contexts`, a map of context names to integer values.
    *   `1`: Follow.
    *   `-1`: Block.
*   **Example**:
    ```json
    {
      "follow": <identity key JSON>,
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
*   **Example**:
    ```json
    {
      "rate": <subject JSON or token (token in case of censor for obvious reasons)>,
      "with": {
        "recommend": true
      }
    }
    ```

### `relate` / `dontRelate`
*   **Meaning**: The `subject` is related (or not related) to the `otherSubject`.
*   **`with` Clause**: Requires `otherSubject`.
*   **Example**:
    ```json
    {
      "relate": <Subject JSON or token>,
      "with": {
        "otherSubject": <Other subject JSON or token>
      }
    }
    ```

### `equate` / `dontEquate`
*   **Meaning**: The `subject` is equivalent (or not) to the `otherSubject` (e.g., different URLs for the same content).
*   **`with` Clause**: Requires `otherSubject`.
*   **Example**:
    ```json
    {
      "equate": <Subject JSON or token>,
      "with": {
        "otherSubject": <Other subject JSON or token>
      }
    }
    ```

### `clear`
Wipes a previous statement.
*   **Meaning**: Say nothing about the given subject or 2 subject combination.
