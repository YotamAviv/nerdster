# Nerdster V2 Mobile Feed Specification (Draft)

The V2 Mobile Feed (PhoneView) is a mobile-optimized, gesture-driven interface for exploring and interacting with aggregated content.

## Based on the Content Card, but less
* no guard icons for crypto proofs
* DEFER: option to relate
* DEFER: graph

TODO: I do want to repect relations and show them, but we have less room for the card that pops up, might just insert it below in the feed if it's clicked. Maybe inform the user about that with a snackbar.

# new Dismiss options

## The following are currently on the quick mock phone view but are just stubs, not connected to any actual data

### Interactive Elements (Clickable but do nothing):
* **Swipe Gestures:** Swiping left (Red/Dismiss) or right (Green/Like) only removes the card visually from the UI. It does not save any rating or hide preference to the backend.
* **Action Bar Buttons:**
     * **Rate/Review Icon:** The `rate_review_outlined` icon below the image has an empty `onTap: () {}` action.
     * **"View all reviews" Link:** The text "View all 5 reviews" (dynamic number, static action) has an empty `onTap: () {}` action.
 * **Modal Sheet (Tap on Image):**
     * **Star Selection:** Clicking any stars immediately closes the modal without saving a rating.
     * **Text Field:** You can type in "Add a comment...", but the text is lost immediately.
     * **"Post Review" Button:** Closes the modal without submitting any data.

### Static Display Elements (Non-interactive):
 * **Header "More" Icon:** The `Icons.more_horiz` (three dots) in the top-right of the card is just an `Icon` widget. It is not clickable (no `IconButton` or `GestureDetector` wrapper).
 * **Comment Actions:** Each individual comment row shows a small `rate_review_outlined` icon on the far right, which is purely decorative and not interactive.
 * **Fallback Imagery:** Uses `loremflickr.com` with a hash of the title to generate random images when `og:image` is missing.

## 1. Visual Elements (The "Content Card")

Each item in the feed is represented as a card containing:

### Header
*   **Identity Icon:** A color-coded circle avatar with an icon representing the content type (e.g., Movie, Book, Article, Album).
*   **Title:** The subject's title, wrapping up to 3 lines before truncating.
*   **Metadata:** The content type label (e.g., "MOVIE") displayed in small, spaced typography.
*   **Options Menu:** A "more" (horizontal dots) icon for secondary actions (placeholder).

### Media Area
*   **Dynamic Image:** A square (1:1) image area that attempts to scrape the `og:image` from the source URL.
*   **Fallback Imagery:** If no image is found, a deterministic, relevant image is generated via LoremFlickr using the subject's tags and a unique hash seed.
*   **Overlay Stats:** A "Star" badge in the top-right corner showing the total number of likes/ratings if greater than zero.
*   **Readability Gradient:** A subtle dark gradient at the bottom of the image to ensure text contrast.

### Action Bar
*   **Like/Favorite:** A heart icon (red if already liked).
*   **Comment:** A speech bubble icon to jump to the review section.
*   **Repost/Repeat:** A circular arrow icon for sharing/re-stating content.
*   **Bookmark:** A ribbon icon for saving content locally (placeholder).

### Content & Social Proof
*   **Hashtags:** A list of blue-colored tags extracted from all statements related to the subject.
*   **Top Reviews:** The two most recent comments, prefixed by the reviewer's moniker/label.
*   **Review Count:** A "View all X reviews" link if there are more than two statements.

---

## 2. Gestures & Interactions

### Feed Navigation
*   **Vertical Scroll:** Standard momentum-based scrolling through the feed.
*   **Pull-to-Refresh:** (Planned) Triggering the `_runPipeline` to fetch the latest aggregations.
TODO: QUESTIONABLE: Can we do this?

### Card Gestures (Dismissible)
*   **Swipe Right (Green):** Quick "Like" action. Removes the card from the current view and (planned) publishes a "Like" statement.
TODO: Very similar (maybe same as) to RatingDialog.
Reveal some options to:
- dismiss (pre-checked) (TODO: New "dismiss" setting: until new activity)
- like
- comment
*   **Swipe Left (Red):** Quick "Dismiss/Censor" action. Removes the card from the view and (planned) marks it as hidden or publishes a "Dismiss" statement.
TODO: Very similar (maybe same as) to RatingDialog.
Reveal some options to:
- dismiss (pre-checked) (TODO: New "dismiss" setting: until new activity)
- dislike
- comment
- censor

### Media Interactions
*   **Single Tap:** Opens the **Quick Rate Bottom Sheet**.
TODO: Probably just union of swipe left/right
    *   **Star Rating:** 1-5 star selection.
    *   **Comment Field:** Text input for adding a review.
    *   **Post Button:** Publishes the rating and comment to the network.

### Header/Footer Interactions
*   **Tap Title/Image:** Navigate to the full external source URL (or search, same as ContentCard).
*   **Tap Tag:** (Planned) Filter the feed by that specific hashtag.
*   **Tap "View all reviews":** (Planned) Open a full-screen view of all statements (TODO: Unlikely: and the trust-path) for that subject.

### Global Actions
*   **Floating Action Button (FAB):** A "+" button in the bottom-right corner to **Submit New Content**.
    *   **Step 1: Establish Subject:** Enter a URL or Title. Metadata is automatically fetched via Cloud Functions if a URL is provided.
    *   **Step 2: Rate/Review:** A secondary dialog (RateDialog) allows the user to provide their initial rating, tags, and comment.
    *   **Step 3: Publish:** The content is signed by the delegate key and published to the network.

---

## 3. Filtering & State
*   **Tag Filtering:** The feed respects the global `tag` setting (e.g., `?tag=nfl`). If set, only subjects containing that hashtag are displayed.
*   **POV (Point of View):** The feed is personalized based on the signed-in user's trust network.
*   **Image Caching:** Dynamically fetched URLs are cached in memory to prevent flickering and redundant Cloud Function calls during a session.
