/**
 * magicPaste — callable Cloud Function handler
 *
 * "Magic Paste" - Smart URL Parser.
 * Fetches the URL and extracts metadata (Title, Year, Author, Image, ContentType)
 * using Schema.org (JSON-LD), OpenGraph, or standard HTML tags.
 */

const fetch = require("node-fetch");
const { parseUrlMetadata } = require('./url_metadata_parser');

async function handleMagicPaste(data, logger) {
  const url = data.url;
  logger.info(`[magicPaste] CALL RECEIVED for URL: ${url}`);

  try {
    let html;
    try {
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
      return {
        title: "Error: Fetch timeout",
        contentType: 'article',
        canonicalUrl: url,
        error: "Fetch timeout"
      };
    }

    logger.info(`[magicPaste] HTML length: ${html.length}`);

    let metadata = await parseUrlMetadata(url, html);

    if (metadata) {
      metadata = JSON.parse(JSON.stringify(metadata));
    }

    logger.info(`[magicPaste] parseUrlMetadata returned: ${JSON.stringify(metadata)}`);

    if (metadata && metadata.title) {
      logger.info(`[magicPaste] Successful. Title: "${metadata.title}"`);
      if (!metadata.contentType) metadata.contentType = 'article';
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
      contentType: 'article',
      canonicalUrl: url,
      error: eFallback.message
    };
  }

  logger.info(`[magicPaste] All methods failed. Returning generic object.`);
  return {
    title: "",
    contentType: 'article',
    canonicalUrl: url
  };
}

module.exports = { handleMagicPaste };
