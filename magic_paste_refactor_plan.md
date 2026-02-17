# Plan: Consolidate Magic Paste and specific URL Fetching

The goal is to unify the metadata fetching logic. The "Magic Paste" button will be the single, explicit action for populating the subject form from a URL. We will make the backend "smarter" (falling back to simple title scraping if needed) and the frontend "simpler" (removing automatic background fetching).

## 1. Backend: Robust Fallback for `magicPaste`
**File:** `functions/url_metadata_parser.js`

Currently, `magicPaste` is too strict and can return `null` if it doesn't find Schema.org/OpenGraph data, whereas the old `fetchTitle` simple scraper worked fine for sites like NYT.

- [ ] **Implement Fallback Logic:** 
    - In `parseUrlMetadata`, after attempting JSON-LD and OpenGraph parsing:
    - If `metadata.title` is still empty, run the simple `extractTitle($, html)` (the same logic used by the old `fetchTitle`).
    - If `metadata.contentType` is still unknown, default to `'article'`.
    - Ensure it returns a useful object `{ title: "Page Title", contentType: "article", ... }` instead of `null` or erroring, so the user always gets *something*.

## 2. Frontend: Remove Implicit "On Paste" Fetching
**File:** `lib/ui/dialogs/establish_subject_dialog.dart`

Currently, the app listens to changes or focus loss on the "url" text field and triggers `fetchTitle`. This conflicts with Magic Paste and causes double-fetching or confusing UI behavior.

- [ ] **Remove Auto-Fetch Listener:** 
    - Identify the `FocusNode` listener, `onChanged` callback, or `TextEditingController` listener attached to the URL input field.
    - Remove the code that calls `fetchTitle` (or `_onUrlChanged`, etc.) when the text changes.
- [ ] **Verify Magic Paste UI:**
    - Ensure the "Magic Paste" button remains the primary way to trigger this action.
    - (Optional) detailed check: make sure the Magic Paste loading state (`isMagicPasting`) creates a good UX since automatic background loading is gone.

## 3. Testing & Verification
**Reference:** `docs/testing.md` explains that backend tests use the Node.js test runner and live in `functions/test/`.

- [ ] **Create/Update Tests:** (`functions/test/magic_paste.test.js`)
    - Create a new test file or update `metadata.test.js` to specifically test `parseUrlMetadata`.
    - **Mocking:** Since we cannot rely on external sites (like NYT) being up or unchanged during CI, we should test against *mocked HTML strings* that represent different scenarios:
        - **Scenario A (Rich JSON-LD):** HTML with full Schema.org `NewsArticle`. -> Expect full metadata.
        - **Scenario B (Broken JSON-LD):** HTML with malformed JSON-LD. -> Expect fallback to OpenGraph/Title.
        - **Scenario C (No Metadata):** HTML with just `<title>`. -> Expect simple Title + 'article'.
    - **Live URL Samples (Optional/Manual):** Create a script or a separate "live" test suite (that doesn't run in standard CI) to verify against known URLs like the NYT link, ensuring our headers/scraping logic actually works against their current defenses.

**User Feedback:** Help link should always be visible (not just for no-URL types). "A TextEditingController was used after being disposed" error when switching types.

**File:** `lib/ui/dialogs/establish_subject_dialog.dart`

- [ ] **Fix Help Icon Logic:** 
    - Currently, the help icon is conditionally rendered inside `cornerWidget` only if the type *doesn't* have a URL.
    - **Change:** Move the Help Icon out of the conditional block. It should always be visible (perhaps next to the Type dropdown or as a dedicated button in the row).
    - **Content:** Ensure the dialog text ("Why no URL?") still makes sense if clicked for an Article (which *does* have a URL). Maybe adjust the title/text slightly to be more general about "Subject Identity" vs "Product Link".

- [ ] **Fix `TextEditingController` Disposal Error:**
    - The error "A TextEditingController was used after being disposed" happens in `_initControllers`.
    - **Cause:** When switching types (e.g., Article -> Album), the code disposes of *all* controllers in `key2controller.values`, clears the map, and re-creates them.
    - **But:** The `TextField` widgets in the tree might still be holding onto references to the old controllers during the build/frame cycle before they get updated with new ones.
    - **Fix:** Ensure we are not disposing controllers that are currently attached to active widgets *before* the widgets update. Or simpler: Create *new* controllers first, swap the map, and then dispose the *old* ones in a safe manner (e.g., via `addPostFrameCallback` or just letting GC handle if not explicitly disposed immediately, though explicit dispose is better).
    - **Specific Fix:** In `_initControllers`, I likely dispose the controller, then `_rebuildFields` uses the *new* map, but the `setState` might be triggering a rebuild where the *old* widget tree tries to use the *old* (now disposed) controller one last time.
    - **Refinement:** The issue is likely that `_validate` listener is still attached or `TextField` is still active. I will refactor `_initControllers` to duplicate the map, create new controllers, swap, and *then* dispose the old values.

## 5. Integration Testing
**Reference:** `docs/testing.md` and `integration_test/` folder.

- [ ] **Run Integration Tests:**
    - `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/basic_test.dart` (or similiar command from `package.json` or scripts).
    - Verify that the subject creation flow still works end-to-end.
- [ ] **Add Magic Paste Integration Test:**
    - Create a test case that opens the dialog, clicks Magic Paste with a mocked clipboard (if possible) or mocked backend response, and asserts the fields are filled.
    - *Note:* Mocking clipboard in integration tests can be tricky; might need to inject the URL via a hidden field or similar if clipboard is inaccessible.

## 6. Verification
- [ ] **Manual Verification (Again):**
    - NYT Link: `https://www.nytimes.com/2026/02/17/us/politics/trump-congress-budget-cuts.html` -> MUST work (Role: Article, Title populated).
    - Help Icon: MUST appear for ALL types (Book, Movie, Article, Album).
    - Switching Types: MUST NOT crash with "disposed controller" error.
    - Loading: MUST see spinner when Magic Paste is clicked.

## 5. Integration Testing
**Reference:** `docs/testing.md` and `integration_test/` folder.

- [ ] **Run Integration Tests:**
    - `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/basic_test.dart` (or similiar command from `package.json` or scripts).
    - Verify that the subject creation flow still works end-to-end.
- [ ] **Add Magic Paste Integration Test:**
    - Create a test case that opens the dialog, clicks Magic Paste with a mocked clipboard (if possible) or mocked backend response, and asserts the fields are filled.
    - *Note:* Mocking clipboard in integration tests can be tricky; might need to inject the URL via a hidden field or similar if clipboard is inaccessible.

## 6. Verification
- [ ] **Manual Verification (Again):**
    - NYT Link: `https://www.nytimes.com/2026/02/17/us/politics/trump-congress-budget-cuts.html` -> MUST work (Role: Article, Title populated).
    - Help Icon: MUST appear for Book/Movie types.
    - Loading: MUST see spinner when Magic Paste is clicked.
