# NerdyContentView V2 Specification

## Overview
The `NerdyContentView` V2 is the successor to the legacy `ContentTree`. It moves away from a strict hierarchical tree structure in favor of a more fluid, subject-centric aggregation that is optimized for both discovery and social proof. It follows a testable MVC architecture:
- **Model**: `V2FeedModel` holds the immutable snapshot of the aggregated feed.
- **View**: `NerdyContentView` and `ContentCard` handle the UI rendering.
- **Controller**: `V2FeedController` manages state, filtering, sorting, and the data pipeline.

Show aggregated content about subjects at top, one per row.


## Follow network context / Identity network
Choose the follow context (network) to use for aggregation, much like `ContentBar` and `NetBar` does for the legacy content tree.
- This sets the `fcontext` setting.
- The available options are dynamically populated from the most frequently used contexts in the network (like the legacy`FollowNet.most`).
- Includes special contexts:
  - `<nerdster>`: The default Nerdster trust network.
  - `<identity>`: The "everyone" network (all identities).
- Examples of discovered contexts: `nerd`, `social`, `movies`, `crypto`, etc.

## PoV
Ability to change PoV quickly and to "reset" back to the signed-in identity.
- The `V2FeedController` manages this state, effectively replacing the state management of the legacy `NetBar` and `ContentBar`.
- **UI**: The PoV selector should include a "Reset to Me" option, similar to the legacy PoV dropdown.

## Progress Tracking
The feed displays a progress bar during the multi-stage aggregation process.
- **Stages**: Trust Graph (Identity), Content Map (Content), Follow Network, and Aggregation.
- **UI**: A `LinearProgressIndicator` with percentage text is shown during the loading state.

## other switches
order by:
- **Recent Activity**: Based on the timestamp of the latest statement (rating, comment, etc.) in the aggregation.
- most sum(likes) - sum(dislikes)
- most comments



## 1. Subject image row / card
While the underlying data (equates, relates) can form a graph, the user interface should prioritize clarity and relevance over structural depth.
- Group all statements about a subject (and its related and equivalent subjects) into a single "Content Card".
- Instead of nesting subjects, show relationships (e.g., "Related to...") as metadata or links within the card.
- Present content as a prioritized feed rather than a static tree to be explored.
- Optimized for mouse, keyboard, and large monitor usage.

## 2. Visual Elements: The Content Card
Each subject is represented by a card that aggregates the network's collective wisdom.

### Header
- **Subject Identity**: Title and Type (Movie, Book, etc.).
- **Discovery Link**: If the subject has a URL, the title links to it. If not, the title links to a Google search containing all values from the subject JSON (matching legacy behavior).

### Media & Content
- **Rich Preview**: Image and description fetched via `MetadataService` (Cloud Functions only).
- **Small Square Leading Image**: Images are displayed as a small (80x80) square at the start of the card to keep row sizes reasonable while maintaining visual context.
- **Fallback**: If metadata is unavailable, use:
  - A standard image for the content type (movie, recipe, etc.).
  - **Stock Images**: For common domains (New York Times, Wall Street Journal, YouTube, etc.), use a hardcoded stock image representing that publisher.
- **Tags**: Aggregated hashtags from all trusted statements.

### The "Review" Section
- **Comment Tree**: Supports a nested tree of ratings (e.g., liking a comment, commenting on a dislike).
  - **Style**: Indentation-based layout (Reddit-style).
- **Main Feed Depth**: Initially show only the top 2 most recent comments/ratings from the most trusted contributors.
- **Expanded View**: Inline expansion within the card shows the full tree.
  - Support scrolling for long threads.
  - Allow manual expand/collapse of sub-trees.
- **Filtering**: Individual comments and statements are subject to the same dismissal and censorship filtering as the top-level subjects.
- **Link to Trust / Follow Graph**: Contributors are displayed using labeled names. Clicking a contributor's name opens the graph view focused on that person, showing the trust or follow paths from the current PoV.

### Action Bar
- **Quick Rate**: Explicit Icon Buttons for Like, Dislike, and Dismiss.
  - **Icons**: Uses legacy-style icons (`thumb_up`, `thumb_down`, `swipe_left` for dismiss, `delete` for censor).
- **Comment**: Open a dialog to add your own rating or comment.
- **Relate/Equate**: Tools to link this subject to others (accessible via context menu or expanded view).

## Show Crypto
When the menu setting to **Show Crypto** is on, show a special crypto icon (or similar indicator) throughout the interface.
- Clicking this icon opens a `JsonDisplay` or `JsonQrDisplay` (matching legacy behavior) of the signed statement supporting the content.
- This applies to all ratings and statements in the view.

## 3. Interactions & Navigation
- **Mouse & Keyboard**: Primary interaction model.
- **Icon Buttons**: All primary actions (Like, Dislike, Dismiss, Censor) are accessible via explicit buttons.
- **Inline Expansion**: Tapping the card expands it inline to show the full history of statements. (Trust graph integration is planned for the future).
- **Right Click / Context Menu**: Access advanced actions (Equate, Relate).
  - **Implementation**: Uses `ContextMenuRegion` to provide a native-feeling desktop menu.

## 4. Filtering & Sorting
- **Tag Filtering**: Respect the global tag selection (e.g., `#nfl`, `#crypto`).
- **Dismissal & Censorship**: Advanced logic for hiding content based on user or PoV dismissals and censorship flags. See [v2_feed_filtering_spec.md](v2_feed_filtering_spec.md) for details.
- **Recency**: Option to sort by the latest activity in the network.
- **Seen vs. Unseen**: Persistent setting to hide subjects you have already rated or dismissed. (To be replaced by the Dismissal Filtering Modes).

## 5. Technical Architecture
- **MVC Pattern**: Decouples data processing (`V2FeedController`), state representation (`V2FeedModel`), and UI rendering (`NerdyContentView`).
- **Pipeline Driven**: Uses `ContentPipeline` to fetch data and `reduceContentAggregation` to process it.
- **Reactive State**: Built using `ValueNotifier` and `ValueListenableBuilder` for efficient, granular UI updates.
- **Lazy Loading**: Efficiently render large feeds using `ListView.builder`.
- **Image Caching**: Use a centralized cache for metadata and images to minimize network calls.

## 6. Comparison with Legacy ContentTree
| Feature | ContentTree (Legacy) | NerdyContentView (V2) |
|---------|----------------------|-----------------------|
| **Structure** | Deeply nested tree | Flat/Prioritized Feed |
| **Focus** | Structural relationships | Subject relevance & Social proof |
| **Navigation** | Manual expansion of nodes | Scroll, Icon Buttons, and Inline Expansion |
| **Media** | Text-heavy | Rich media previews (where available) |
| **Performance** | Rebuilds entire tree | Incremental updates |
