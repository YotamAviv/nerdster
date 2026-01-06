# Metadata Fetching Architecture

## Overview
The metadata service extracts rich info (titles, images) from URLs and content types to populate the UI. It uses a tiered approach combining Cloud Functions and deterministic client-side fallbacks.

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
Currently, the `MetadataService` does **not** implement active caching.
- **Behavior**: Each call to `fetchImages` triggers a new Cloud Function invocation.
- **Impact**: Since `ContentCard` widgets are created and destroyed during list scrolling, scrolling back to an item will cause the metadata to be re-fetched.

## System Feedback
- **Stateless**: The system does not "learn" or track which URLs fail.
- **No Quality Metrics**: There is no feedback loop to tell the server if an image was successfully loaded or if it was a 404.
- **Error Handling**: Failed fetches are logged on the client but are not persisted or analyzed server-side.

