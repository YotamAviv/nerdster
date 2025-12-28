# V2 Feed Filtering, Dismissals, and Censorship Specification

## 1. Rating

In V2, any interaction with a subject is considered a **Rating**.

- Most are obvious (like, dislike, comment).
- **Dismiss**: A mild hide action for what's already been seen.
- **Censor**: A harsh hide action for content that is deemed inappropriate or harmful.

Dismissal and Censorship are **not related**.

## 2. Dismissal Logic

Dismissing a subject is intended to clear the user's feed (empty feed) without expressing a negative opinion.

### Show dismissed content when it has new activity

### Dimiss Interaction with Like/Dislike

- **Like + Dis**: Subject remains liked (contributing to the score) but is hidden until new activity occurs.
- **Dislike + Dis**: Subject remains disliked even if new activity occurs.

## 3. Censorship

- **Effect**: When censorship is enabled, censored subjects are removed (wiped, invisible) from the view. When censorship is not enabled, censor statements are ignored.
- **UI**: include an Enable Censorship checkbox.

## 4. Dismissal Filtering Modes

The feed includes a control to determine which dismissals to respect:

1. **My Disses (Default)**:

   - Respect my own dismissal timestamps, even when viewing another PoV's trust graph.

2. **PoV's Disses**:

   - Respect the dismissal timestamps of the current PoV identity.

3. **Ignore Disses**:
   - useful for finding things you previously dismissed or seeing everything a PoV has access to.

## 5. Tag Filtering and Equivalence

Tags are extracted from comments (e.g., `#tag`).

### Tag Equivalence Logic

- **Implicit Equivalence**: If a single comment contains multiple tags (e.g., `#news #politics`),
  the app will interpret an implicit relationship: the first tag is considered the primary tag, and all subsequent tags in that same comment are considered equivalent to it.
- **Transitivity**: Tag equivalence is transitive. If `#A` is equivalent to `#B`, and `#B` is equivalent to `#C`, then `#A` is equivalent to `#C`.
- **Filtering**: When filtering the feed by a specific tag, the system should show any subject that has that tag OR any equivalent tag.

### Subject Matching

A subject matches a tag filter if:

1. The subject itself contains the tag (or an equivalent).
2. Any comment or rating on that subject contains the tag (or an equivalent).
3. Any reply to a comment on that subject contains the tag (or an equivalent), and so on recursively.

### Clickable Tags

- Tags in comments should be rendered as clickable links.
- Clicking a tag should:
  1. Set that tag as the active filter in the feed.
  2. Update the UI to show only subjects matching that tag (and its equivalents).
  3. Provide visual feedback (e.g., a snackbar or highlighting) that the filter has been applied.

### Most Frequent Tags

- The system should track the frequency of tags across all visible content.
- A list of the most frequent tags should be available to populate filter selection UIs (e.g., a dropdown or a "trending" list).
- This list should respect the current PoV and follow context.

## 6. Implementation Details

### Data Structures

`ContentAggregation` will be updated to include:

- `tagEquivalence`: A map or structure representing groups of equivalent tags.

`SubjectAggregation` will be updated to include:

- `lastActivity`: Timestamp of the most recent statement in the cluster.
- `userDismissalTimestamp`: Timestamp of the current user's latest dismissal.
- `povDismissalTimestamp`: Timestamp of the PoV's latest dismissal.
- `isCensored`: Boolean indicating if any trusted statement has the `censor` flag.
- `tags`: A set of all tags found in the subject or its comments.

### Filtering Logic

The `V2FeedController` will apply the following filter to the subjects list:

```dart
bool shouldShow(SubjectAggregation subject, FilterMode mode, bool censorshipEnabled) {
  if (censorshipEnabled && subject.isCensored) return false;

  switch (mode) {
    case FilterMode.myDisses:
      if (subject.userDismissalTimestamp == null) return true;
      return subject.lastActivity > subject.userDismissalTimestamp;

    case FilterMode.povDisses:
      if (subject.povDismissalTimestamp == null) return true;
      return subject.lastActivity > subject.povDismissalTimestamp;

    case FilterMode.ignoreDisses:
      return true;
  }
}
```
