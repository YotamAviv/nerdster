/**
 * magicPaste — callable Cloud Function handler
 *
 * "Magic Paste" - Smart URL Parser.
 * Fetches the URL and extracts metadata (Title, Year, Author, Image, ContentType)
 * using Schema.org (JSON-LD), OpenGraph, or standard HTML tags.
 */

const fetch = require("node-fetch");
const { parseUrlMetadata, inferContentType, resolvesWithoutHtml } = require('./url_metadata_parser');

async function handleMagicPaste(data, logger) {
  const url = data.url;
  logger.info(`[magicPaste] CALL RECEIVED for URL: ${url}`);

  try {
    let html;
    // Some URLs are resolved from an API rather than the page (YouTube oEmbed,
    // IMDb via TMDB). Skip the fetch for those: it's a wasted request to a host
    // that often blocks us, and a timeout here used to return early — before
    // parseUrlMetadata ever got the chance to resolve the URL properly.
    if (resolvesWithoutHtml(url)) {
      logger.info(`[magicPaste] ${url} resolves via API; skipping HTML fetch.`);
    } else try {
      const timeoutMs = 15000;

      const fetchAndRead = async () => {
        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Referer': 'https://www.google.com/'
          }
        });
        if (!response.ok) {
          logger.warn(`[magicPaste] HTTP status: ${response.status} (attempting to parse anyway)`);
        }
        return await response.text();
      };

      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Fetch timeout')), timeoutMs)
      );

      html = await Promise.race([fetchAndRead(), timeoutPromise]);
    } catch (e) {
      if (e.message === 'Fetch timeout') logger.warn(`[magicPaste] Fetch timed out after 15s`);
      // Content type is inferred from the URL, so it survives a failed fetch.
      // Don't fall back to 'article' — that throws away the one signal we still have.
      return {
        title: "Error: Fetch timeout",
        contentType: inferContentType(url, {}),
        canonicalUrl: url,
        error: "Fetch timeout"
      };
    }

    logger.info(`[magicPaste] HTML length: ${html ? html.length : 'n/a (API-resolved URL)'}`);

    let metadata = await parseUrlMetadata(url, html);

    if (metadata) {
      metadata = JSON.parse(JSON.stringify(metadata));
    }

    logger.info(`[magicPaste] parseUrlMetadata returned: ${JSON.stringify(metadata)}`);

    if (metadata && metadata.title) {
      logger.info(`[magicPaste] Successful. Title: "${metadata.title}"`);
      if (!metadata.contentType) metadata.contentType = inferContentType(url, metadata);
      if (metadata.image && typeof metadata.image === 'object') {
        metadata.image = metadata.image.url || metadata.image.contentUrl || null;
      }
      return metadata;
    } else {
      logger.info(`[magicPaste] All methods found no title.`);
    }

  } catch (eFallback) {
    logger.error(`[magicPaste] Exception: ${eFallback.message}`);
    return {
      title: "Error: " + eFallback.message,
      contentType: inferContentType(url, {}),
      canonicalUrl: url,
      error: eFallback.message
    };
  }

  logger.info(`[magicPaste] All methods failed. Returning generic object.`);
  // Still report the URL-inferred type: a blocked scrape (e.g. IMDb's bot
  // interstitial) leaves us with no title, but the URL alone is enough to know
  // this is a movie / video / book. The user types the title; the type is right.
  return {
    title: "",
    contentType: inferContentType(url, {}),
    canonicalUrl: url
  };
}

module.exports = { handleMagicPaste };
