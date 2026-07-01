# Content Submission Improvement Specification

## 1. Principle: Heterogeneity & Subject Uniqueness

Both the Nerdster and the ONE-OF-US.NET phone app promote a heterogeneous environment.

If a person recommends "The Matrix" here, it should be possible for other technologies, services, or apps to understand and leverage that recommendation solely based on the user's public key (not necessarily a "ONE-OF-US.NET key").

The core purpose of `ContentType` is to maximize **Subject Uniqueness** across the web of trust:

*   **Abstract Subjects (Movies, Books, Albums):**
    These are defined by their inherent metadata (Title + Year + Creator) rather than a specific location.
    A rating for "The Matrix" is valid whether the user watched it on Netflix, DVD, or in a theater.
    It is NOT tied to a specific URL.

*   **Resource Subjects (Articles, Videos, Recipes, Events):**
    These are necessarily tied to a specific publisher or location. A newspaper article is uniquely identified by its URL (e.g., `nytimes.com/...`).

This distinction ensures that recommendations are portable where possible, and specific where necessary.

## 2. Problem Statement

Currently, submitting content to the Nerdster relies heavily on manual data entry or basic copy/paste mechanisms that vary by content type:
*   **Articles:** User pastes a URL; the app auto-fetches the title. (Good friction level).
*   **Books:** User manually finds and types Title, Author, and Year. (High friction).
*   **Movies:** User manually finds and types Title, Director/Year. (High friction).

## 3. Goals

*   **Minimize Friction:** Reduce data entry to near zero for all content types.
*   **Unified Workflow:** Provide a single entry point ("Add Content") that intelligently handles various inputs (Text, URL, Search).
*   **Enforce Uniqueness:** Automatically convert vendor-specific URLs (IMDb, Amazon) into abstract subjects where appropriate.

## 4. "Smart Paste" / Deep Link Submission

### Concept
Most users discover content in other apps (Kindle, IMDb, Netflix, Browser, YouTube). The natural behavior to "save" or "discuss" this content involves the system Share sheet.

### Workflow: "Share > Copy Link"
1.  **User Context:** User is in a content app (e.g., IMDb, Netflix, YouTube) or a web browser viewing specific content (e.g. "The Matrix").
2.  **Action:** User taps the "Share" icon within that app.
3.  **Selection:** User selects "Copy Link" from the system sheet. (Clipboard now contains `https://www.imdb.com/title/tt0133093/`).
4.  **Submission:**
    *   User opens **Nerdster** web app -> "Establish Subject".
    *   User taps "Paste".
    *   **App Logic:** Nerdster detects this is an IMDb URL.
    *   **Resolution:** Nerdster (via backend) queries the metadata provider, identifies it as a **Movie**, and auto-fills "The Matrix", "1999", etc.
    *   **Crucial Step (Uniqueness):** The IMDb URL is *discarded* as the subject identifier. The subject is established as `{"type": "movie", "title": "The Matrix", "year": 1999}`.

### Workflow: "Share > Nerdster" (Direct Intent - Future PWA/Native Capability)
*Ideally, if Nerdster is installed as a PWA or wrapped app, it could register the app to appear directly in the Share Sheet.*
1.  **User Context:** User is in a third-party app (e.g., IMDb).
2.  **Action:** User taps "Share".
3.  **Selection:** User taps the "Nerdster" icon directly involved in the share sheet.
4.  **Submission:** Nerdster opens directly to the "Establish Subject" dialog with the URL pre-filled and processing started.

## 5. Supported Sources & Logic

The system must distinguish between extracting **Identity** (for Resource Subjects) and extracting **Metadata** (for Abstract Subjects).

| Content Type | Common Sources / Domains | Strategy | Resulting Subject Identity |
| :--- | :--- | :--- | :--- |
| **Movie** | `imdb.com`, `netflix.com` | Parse ID -> Fetch Metadata (TMDB/OMDB) | `Title` + `Year` (URL discarded) |
| **Book** | `goodreads.com`, `amazon.com`, `audible.com` | Parse ISBN/ASIN -> Fetch Metadata (Google Books) | `Title` + `Author` + `Year` (URL discarded) |
| **Album** | `spotify.com`, `music.apple.com` | Parse ID -> Fetch Metadata (Spotify API) | `Title` + `Artist` (URL discarded) |
| **Video** | `youtube.com`, `vimeo.com` | Use URL as-is -> Fetch OEmbed Title | **The URL itself** |
| **Article** | (Generic URLs) | Use URL as-is -> Fetch OpenGraph Title | **The URL itself** |

## 6. Alternative Workflows

### A. Integrated Search (The "I don't have a link" Scenario)
If the clipboard is empty or the user manually types:
1.  User types "The Matrix".
2.  App presents a "Search" button (or auto-suggests).
3.  User selects category "Movie".
4.  App queries TMDB/OMDB for query "The Matrix".
5.  User picks the correct result from a list.
6.  Metadata is auto-filled.

### B. Barcode Scanning (Books)
1.  User in "Establish Subject" taps "Scan Barcode".
2.  User scans ISBN on book jacket.
3.  App queries Google Books API by ISBN.
4.  Metadata is auto-filled.

## 7. Technical Implementation Suggestion

### Backend Proxy (Cloud Functions)
To keep the web app lightweight and secure (hiding API keys), implement a `fetchMetadata(url)` Cloud Function.
*   **Request:** `{ "url": "..." }`
*   **Response:**
    ```json
    {
      "detectedType": "MOVIE", 
      "subjectIdentity": {
         // Normalized fields for Abstract Subjects
         "title": "The Matrix",
         "year": 1999
      },
      "displayMetadata": {
         // Helper data for UI preview
         "image": "...",
         "creators": ["Lana Wachowski", "Lilly Wachowski"]
      }
    }
    ```

### Client Logic (Nerdster)
1.  `EstablishSubjectDialog` accepts text input.
2.  `onPaste`: Check if text is URL.
3.  If URL -> Call `fetchMetadata`.
4.  **Review Step:** Present the user with the *Detected Type* and *Identity Fields*.
    *   *User: "Ah, it found The Matrix (1999). Correct."*
5.  **Submit:** The active subject becomes the normalized identity, *not* the source URL (unless it's an article/video).

## 8. Handling "Dirty" URLs and Paywall/Gift Links

Users often encounter URLs contaminated with tracking parameters, session IDs, or specific "gift" tokens (e.g., WSJ, NYT).

### The Problem
*   **Dirty URLs:** `https://www.wsj.com/...tsunami-95a625dc?mod=hp_opin_pos_1`
    The `mod=...` part is irrelevant to the identity of the article. Including it splits the discussion (User A rates the clean link, User B rates the dirty link).
*   **Gift Links:** `https://www.nytimes.com/.../some-article.html?unlocked_article_code=...`
    These links are great for reading but terrible for identity. They expire or differ per sharer.

### Solution: URL Normalization (Sanitization)

The `fetchMetadata` cloud function must act as a **Canonicalizer**.

1.  **Strict Cleaning:**
    Unlike Abstract Subjects where the URL is discarded, for Resource Subjects (Articles), the URL *is* the identity. Therefore, we must aggressively strip tracking parameters.
    *   **Common Trackers:** Remove `utm_*`, `fbclid`, `gclid`, `ref`, `source`.
    *   **Site-Specific Trash:**
        *   **WSJ:** Remove `mod`, `st` (share token).
        *   **NYT:** Remove `unlocked_article_code`, `smid`.
        *   **Medium:** Remove `source`.

2.  **Canonical Link Reference:**
    Most modern news sites include a `<link rel="canonical" href="..." />` tag in their HTML head.
    *   **Action:** When fetching metadata, the backend should *always* prefer the URL found in the `canonical` tag over the URL provided by the user.
    *   **User Feedback:** "We found the clean version of this link and are using that instead."

### User Guidance
*   Users should generally **Copy the Browser URL** or use **Share > Copy Link**.
*   Users *should not* worry about the trash at the end. The system handles cleanup.
*   **Implementation Detail:** If a user pastes a "Gift Link", the system fetches the content, finds the canonical (non-gift) URL, and uses *that* as the subject. This ensures the Recommendation is permanent, even if the Gift access expires.

## 9. Implementation Plan: "Magic Paste" Button

### UI Component: `EstablishSubjectDialog`
The existing dialog currently requires users to manually select a Content Type or provides a basic Paste for articles.
We will Introduce a prominent new action button.

**Button Name Proposal:**
*   **"Magic Paste"** (Recommended: Fits the "Magic" theme)
*   *Alternative:* "Paste Link" or "Auto-Fill"

**Button Behavior:**
1.  User clicks **"Magic Paste"**.
2.  App reads the system clipboard.
3.  **Validation:**
    *   If clipboard is empty/not text -> Show error "Clipboard empty".
    *   If clipboard is not a URL -> Treat as search query or show error.
4.  **Processing:** Show a spinner ("Analyzing Link...").
5.  **Resolution:**
    *   **Success:** Automatically switches the `ContentType` dropdown to the detected type (e.g., Movie) and populates the fields (Title, Year).
    *   **Ambiguity:** If the type isn't certain, stay on the current type but try to fill `url` and `title`.

### Logic Flow
`Clipboard -> URL -> Cloud Function (Fetch Metadata) -> Schema.org/OG Parse -> ContentType Mapping -> Form Population`

### Expected Site Compatibility (By Content Type)

We expect the following sites to support **Schema.org (JSON-LD)** or robust **OpenGraph** tags, allowing for high-fidelity extraction without site-specific scrapers.

| Content Type | Primary Domains (Expected to work) | Extraction Strategy |
| :--- | :--- | :--- |
| **Movie** | `imdb.com`<br>`rottentomatoes.com`<br>`netflix.com` (Web)<br>`letterboxd.com` | **JSON-LD:** Look for `@type: Movie`.<br>Extract `name`, `datePublished`. |
| **Book** | `goodreads.com`<br>`amazon.com` (Books)<br>`audible.com`<br>`books.google.com` | **JSON-LD:** Look for `@type: Book`.<br>Extract `name`, `author`, `datePublished`. |
| **Recipe** | `allrecipes.com`<br>`nytimes.com/cooking`<br>`foodnetwork.com`<br>`bonappetit.com` | **JSON-LD:** Look for `@type: Recipe`.<br>Extract `name`, `image`. |
| **Article** | `nytimes.com`<br>`wsj.com`<br>`washingtonpost.com`<br>`wired.com`<br>`medium.com`<br>`substack.com` | **JSON-LD:** Look for `NewsArticle` or `BlogPosting`.<br>**Fallback:** OpenGraph (`og:title`, `og:url`). |
| **Video** | `youtube.com`<br>`vimeo.com`<br>`tiktok.com` (Web) | **OEmbed / OG:** Robust standard support.<br>Extract `title`, `author_name`. |
| **Album** | `spotify.com`<br>`music.apple.com`<br>`bandcamp.com` | **JSON-LD:** Look for `MusicAlbum`.<br>Extract `name`, `byArtist`. |
| **Event** | `eventbrite.com`<br>`meetup.com`<br>`facebook.com/events` | **JSON-LD:** Look for `Event`.<br>Extract `name`, `startDate`, `location`. |

### Privacy & Architecture Note
The parsing logic resides in the **Cloud Function**, not the client. This ensures:
1.  **Agility:** We can fix parsers when sites change their layout without updating the app.
2.  **Privacy:** User cookies/session data are NOT sent. The cloud function fetches the *public* version of the page.

## 10. Issue: Editable Title Abuse vs. Unreliable Fetch

### The Problem
The title field in `EstablishSubjectDialog` is freely editable. This causes two
distinct failure modes, pulling in opposite directions:

1.  **Eager over-editing / sabotage (want the field *locked*).**
    A user pastes a URL, gets a correctly fetched title, and immediately rewrites
    it — turning the *subject identifier* into what should have been a *comment*.
    - Example: An article fetches the headline "Victor Willis, Village People lead
      singer, dies at 74". The user edits the title to "Job opens up for Will
      Scruggs". The subject is now polluted for everyone: it no longer collapses
      with the same article submitted by others, and it misrepresents the source.
    - Motivation is mixed and hard to distinguish automatically:
        - **Misunderstanding:** the user doesn't grasp that a "Logical Subject" is a
          shared, canonical identity — not their personal take. Comments are the
          place for commentary.
        - **Deliberate sabotage:** the user knows, and edits the title as a joke or
          to degrade the shared record.

2.  **Failed / low-quality fetch (want the field *editable*).**
    Fetching is unreliable, so sometimes the title must be corrected by hand.
    - Example: An NYT article URL fetches a title of just "nytimes.com" (a site-name
      fallback, not the headline). The user *must* be able to fix this or the
      subject is useless.

We cannot simply make the title read-only (the desired fix for case 1) because
case 2 is common. The two cases require opposite affordances on the *same field*.

### Key Insight: The Backend Already Knows Its Confidence
Title extraction is already tiered by source (see §9 and
`functions/url_metadata_parser.js`), and the source *is* a confidence signal:

| Source | Confidence | Interpretation |
| :--- | :--- | :--- |
| JSON-LD `@type` + `name` (Schema.org) | **High** | Canonical, publisher-declared. |
| OpenGraph `og:title` / oEmbed `title` | **High/Medium** | Intended share title. |
| Scraped `<title>` tag | **Low** | Often includes site name / cruft. |
| Site-name fallback (e.g. "nytimes.com"), or empty | **None** | Fetch effectively failed. |

Today this signal is discarded — the client only receives the final `title`
string and can't tell "Victor Willis…" (High) from "nytimes.com" (None). Surfacing
it is the enabler for most options below.

### Options

**A. Return a confidence/source code from the backend; gate editing on it.**
Have `magicPaste` return `{ title, titleSource, confidence }` alongside the title.
Then in the dialog:
- **High confidence** → title locked by default (prevents case 1), with a small
  "Edit anyway" / "Wrong title?" escape hatch (preserves case 2 for the rare
  high-confidence-but-wrong result).
- **Low / no confidence** → title editable as today, ideally flagged ("Couldn't
  confirm this title — please check it").
- *Pro:* Directly targets the abuse while keeping the safety valve. Cheap — the
  signal already exists internally.
- *Con:* "Edit anyway" still lets a determined saboteur through; confidence tiers
  need tuning per source.

**B. Improve the UI to teach what a Logical Subject is (and where comments go).**
- Rename/reinforce: the dialog already says "Establish **Logical Subject**" with a
  "Logical Subject?" help link — make that explanation more prominent on first use.
- Show an inline **"Add a comment"** affordance *inside* the establish flow, so an
  eager commenter has the correct outlet at the moment of temptation instead of
  editing the title.
- Micro-copy near the title: "This is the shared name for this subject. Save your
  own take for a comment."
- *Pro:* Addresses the root cause (misunderstanding) and reduces friction for the
  honest majority. *Con:* Does nothing against deliberate sabotage.

**C. Constrain editing instead of free text (esp. Abstract subjects).**
For Movies/Books/Albums, offer *candidate* titles (from the metadata provider) to
pick from rather than a free text box, reserving free text for true misses. For
Resource subjects (Articles/Videos) the fetched title *is* the canonical identity,
so lean toward locking on a good fetch.
- *Pro:* Structurally prevents both cases for abstract subjects. *Con:* More UI;
  depends on provider search (see §5/§6A).

**D. Lean on the trust layer for sabotage.**
A polluted subject is still a signed `ContentStatement` attributable to its author
and filtered by the Trust Algorithm. Deliberate sabotage from a low-trust identity
is naturally down-ranked/hidden from most PoVs. This doesn't *prevent* pollution
but bounds its blast radius — worth stating so we don't over-engineer prevention.

### Decision
Implement **A only**. The backend (`magicPaste` / `parseUrlMetadata`) returns
`titleSource` and a derived `titleConfidence` ('high' | 'low' | 'none'). In
`EstablishSubjectDialog`:
- **high** → title field locked (read-only) with an "Edit anyway" escape hatch.
- **low / none** → title editable as today.

Options B (teaching UI / inline comment affordance), C (candidate-title picker),
and D (rely on trust filtering) are **not** being implemented; they are retained
above for the record.

Confidence is derived from the extraction source:

| titleSource | titleConfidence |
| :--- | :--- |
| `jsonld`, `opengraph`, `oembed` | `high` |
| `htmlTitle` | `low` |
| empty, or title equals the site hostname (e.g. "nytimes.com") | `none` |

### Related robustness fix: native fallback on error pages
Independent of Option A: on native (phone), `magicPaste` fetches the URL directly
and only falls back to the cloud function (better IP reputation) when the direct
fetch yields *no* title. Some sites serve a bot-challenge/error page with a
non-empty title (e.g. Goodreads' "unexpected error", Cloudflare's "Just a
moment..."), which defeated that fallback. `magicPaste` now also falls back when
the native title matches a small denylist of high-signal error-page phrases
(`_looksLikeErrorPage`), deliberately avoiding broad tokens that collide with real
titles (e.g. "(500) Days of Summer").
