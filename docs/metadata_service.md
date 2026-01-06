# Metadata Fetching Architecture

## Overview
The metadata service extracts rich info (titles, images) from URLs and content types to populate the UI. It uses a tiered approach combining Cloud Functions and deterministic client-side fallbacks.


## Future Next Steps

-   **Streaming Responses**: Have the server stream the response to the client so that the first available image is not delayed by the rest (e.g., YouTube check returns immediately while Wikipedia fetch continues).
-   **Strategy Attribution**: Include a strategy name (e.g., `youtube`, `opengraph`, `openlibrary`) to the client along with each image. Update the debug server page to show these strategy names.
-   **Learning & Optimization**: The plan would be to over time learn which strategies are effective for which subjects and improve the client logic.

## Components

### 1. `MetadataService` (Client-Side)
Located in `lib/v2/metadata_service.dart`.
- **Purpose**: Helper functions to determine the best available image/title.
- **Key Functions**:
  - `fetchTitle(url)`: Calls cloud function `fetchTitle` to scrape just the page title (for canonicalization).
  - `fetchImages(subject)`: Calls cloud function `fetchImages` to get Open Graph (OG) metadata.
  - `getFallbackImageUrl(...)`: Deterministic local generator when cloud data is missing.

### 2. Client-Side Fallback Logic
If the cloud function returns no image (or it fails to load):
- **YouTube**: Regex extracts video ID -> `img.youtube.com`.
- **New York Times**: Keyword match -> Static NYT logo.
- **Content Types**: Hard-coded mapping of `contentType` (e.g., 'movie', 'book') to reliable Wikimedia Commons icons.
- **Default**: Generic "No Image" placeholder.

### 3. Cloud Functions (Server-Side)
Located in `functions/index.js` (and `metadata_fetchers.js`).
- `fetchTitle`: Quick HTML scrape for `<title>`.
- `fetchImages`: 
  - Uses `metadata_fetchers` strategy pattern.
  - Tries specific scrapers for known domains (NYT, YouTube, etc.).
  - Falls back to generic Open Graph (`og:image`) scraping.
  - Returns a JSON object with `title`, `image` (best single image), and `images` (list of candidates).

## Data Flow
1. **Input**: User pastes a URL or creates a subject.
2. **Fetch**: App calls `MetadataService.fetchImages`.
3. **Cloud**: Firebase function scrapes the URL.
4. **Display**: 
   - UI attempts to load the cloud-provided `image`.
   - If `image` is null/empty/broken, UI calls `getFallbackImageUrl`.
   - `getFallbackImageUrl` generates a URL based on the subject's `contentType` or domain logic.

## Search Strategy (Aggregation)
The Cloud Function (`fetchImages`) employs a "wide net" strategy to maximize the probability of finding an image. It aggregates results from multiple sources:
1. **YouTube**: If the URL indicates a video, thumbnails are extracted.
2. **HTML Scraping**: Standard HTTP fetch for Open Graph tags or image elements.
3. **OpenLibrary**: If `contentType` is 'book', it queries by title/author.
4. **Wikipedia**: Fallback search by title.

**Note on Usage**: The server returns both a single "best" `image` and a list of all candidates `images`. Currently, the client **only uses the first image** and disregards the rest.

## Caching & Performance
Since `ContentCard` widgets are frequently created and destroyed during list scrolling, `MetadataService` implements a simple **client-side in-memory cache** (`_metadataCache`).
- **Key**: Unique URL or Title.
- **Behavior**: Stores both successful results and errors.
- **Benefit**: Prevents redundant Cloud Function invocations (costs/latency) when a card scrolls back into view.

## Image Proxies & Fallbacks (Web Only)
On Flutter Web (`kIsWeb`), images are often blocked by CORS policies.
- **Strategy**: The app attempts to load images via `wsrv.nl` (a CORS proxy and resizer).
- **Issue**: Some servers (like Wikimedia) or specific filenames may cause the proxy to fail (404/Block), even if the original URL is valid and accessible.
- **Resolution**: The `ContentCard` implements a "try-both" mechanism:
  1.  Try `wsrv.nl` proxy.
  2.  If it fails (`errorBuilder`), fallback to the direct `imageUrl`.
  3.  If both fail, show `Icons.image_not_supported`.

## System Feedback
- **Stateless**: The system does not "learn" or track which URLs fail.
- **No Quality Metrics**: There is no feedback loop to tell the server if an image was successfully loaded or if it was a 404.
- **Error Handling**: Failed fetches are logged on the client but are not persisted or analyzed server-side.

