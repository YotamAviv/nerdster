const cheerio = require('cheerio');
const { decode } = require('html-entities');
const { extractTitle, extractImages } = require('./metadata_fetchers');
const { logger } = require("firebase-functions");

/**
 * Parses a URL to extract structured metadata for the "Magic Paste" feature.
 * Prioritizes Schema.org (JSON-LD) > OpenGraph > Standard HTML tags.
 * 
 * @param {string} url - The URL to parse.
 * @param {string} html - The raw HTML content (optional, if already fetched).
 * @returns {Object} Structured metadata { contentType, title, year, author, image, description, canonicalUrl }
 */
async function parseUrlMetadata(url, html) {
  logger.info(`[parseUrlMetadata] Start for URL: ${url}`); // DEBUG

  if (!html) {
      const fetch = require("node-fetch");
      try {
        logger.info(`[parseUrlMetadata] Fetching URL...`); // DEBUG
        const response = await fetch(url, {
             headers: { 
                 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                 'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                 'Accept-Language': 'en-US,en;q=0.5',
                 'Referer': 'https://www.google.com/'
             },
             redirect: 'follow',
             timeout: 10000
        });
        if (!response.ok) {
            logger.warn(`[MagicPaste] HTTP Error ${response.status} for ${url}`);
            logger.info(`[MagicPaste] Proceeding anyway to try HTML title scrape...`); // DEBUG
            // Do not return null immediately. Often, 403/429 responses still contain useful HTML/Title.
            // Continue to extract what we can from the body.
        }
        
        // Update URL to the final destination (handling redirects like a.co -> amazon.com)
        if (response.url && response.url !== url) {
             logger.info(`[MagicPaste] Redirected to: ${response.url}`); // DEBUG
             url = response.url;
        }
        
        html = await response.text();
        logger.info(`[MagicPaste] Fetched HTML, length: ${html.length}`); // DEBUG
      } catch (e) {
        logger.error(`[MagicPaste] Fetch error: ${e.message}`);
        return null;
      }
  }

  const $ = cheerio.load(html);
  const metadata = {
    contentType: null, // 'movie', 'book', 'article', etc.
    title: null,
    year: null,
    author: null,
    image: null,
    description: null,
    canonicalUrl: url
  };

  // 1. Try JSON-LD (Schema.org) - The Gold Standard
  try {
    const jsonLdScripts = $('script[type="application/ld+json"]');
    jsonLdScripts.each((i, el) => {
      try {
        const json = JSON.parse($(el).html());
        processJsonLd(json, metadata);
      } catch (e) {
        // Ignore parsing errors for individual scripts
      }
    });
  } catch (e) {
    logger.warn(`[MagicPaste] JSON-LD error: ${e.message}`);
  }

  // 2. Fallback: OpenGraph / Meta Tags
  if (!metadata.title) metadata.title = extractTitle($, html);
  
  // Google Books Specific Cleanup (Must run before general OpenGraph checks so we don't overwrite if not found)
  if (url.includes('google.com/books') || url.includes('books.google.')) {
      if (!metadata.contentType) metadata.contentType = 'book';
      
      // Attempt to extract author (Google Books often links authors with "inauthor" search)
      if (!metadata.author) {
          // Try standard semantic links first
          let authorText = $('a[href*="/search?q=inauthor"]').first().text().trim();
          
          // Fallback to finding the "About the author" section or similar div structures if link is missing
          if (!authorText) {
             // Look for simple text label "By " or similar near top
             const titleNode = $('h1').first();
             if (titleNode.length > 0) {
                 const potentialAuthor = titleNode.next().text().trim(); // Sibling of title often contains author
                 if (potentialAuthor && !potentialAuthor.includes('http')) {
                     authorText = potentialAuthor.replace(/^By\s+/i, '');
                 }
             }
          }
          if (authorText) metadata.author = authorText;
      }
      
      // Fallback date/year extraction
      if (!metadata.year) {
           const dateText = $('span:contains("Published")').next().text() || 
                            $('div:contains("Published")').text();
           if (dateText) {
               const yearMatch = dateText.match(/\b(19|20)\d{2}\b/);
               if (yearMatch) metadata.year = yearMatch[0];
           }
      }
  }

  // OpenGraph Fallbacks if JSON-LD missed
  if (!metadata.image) metadata.image = $('meta[property="og:image"]').attr('content');
  if (!metadata.description) metadata.description = $('meta[property="og:description"]').attr('content');
  if (!metadata.canonicalUrl) metadata.canonicalUrl = $('link[rel="canonical"]').attr('href') || $('meta[property="og:url"]').attr('content') || url;

  // 3. Inference / Cleanup
  if (!metadata.contentType) {
     metadata.contentType = inferContentType(url, metadata);
  }

  // Clean Year
  if (metadata.year) {
      // Ensure year is just the year (YYYY)
      const yearMatch = metadata.year.toString().match(/\b(19|20)\d{2}\b/);
      metadata.year = yearMatch ? yearMatch[0] : null;
  }
  
  // Fallback Year extraction from Title (e.g. "The Matrix (1999)")
  if (!metadata.year && metadata.title) {
      const titleYearMatch = metadata.title.match(/\(((?:19|20)\d{2})\)/);
      if (titleYearMatch) {
          metadata.year = titleYearMatch[1];
      }
  }

  // Final Safety Fallback:
  // If we still have no title, use the simple HTML scraper (same robust logic as the old fetchTitle)
  if (!metadata.title) {
      metadata.title = extractTitle($, html);
  }
  // If we have a title but no content type, default to 'article' so it's usable
  if (metadata.title && !metadata.contentType) {
      metadata.contentType = 'article';
  }

  return metadata;
}

/**
 * Process a JSON-LD object to populate metadata.
 * Handles single objects and logic for nested execution in a Graph.
 */
function processJsonLd(json, metadata) {
  if (!json) return;

  // Handle Graph array
  if (json['@graph'] && Array.isArray(json['@graph'])) {
    json['@graph'].forEach(item => processJsonLdItem(item, metadata));
  } else if (Array.isArray(json)) {
    json.forEach(item => processJsonLdItem(item, metadata));
  } else {
    processJsonLdItem(json, metadata);
  }
}

function processJsonLdItem(item, metadata) {
  const type = Array.isArray(item['@type']) ? item['@type'][0] : item['@type'];
  if (!type) return;

  // Helper to extract clean text
  const val = (prop) => {
      if (!item[prop]) return null;
      if (typeof item[prop] === 'string') return decode(item[prop]);
      if (Array.isArray(item[prop])) return val(item[prop][0]); // Recursion for first item? No, just recursive call logic below.
      if (item[prop].name) return decode(item[prop].name);
      return null;
  };
  
  // Helper for authors list
  const getAuthor = () => {
      if (item.author) {
          if (Array.isArray(item.author)) return item.author.map(a => a.name).join(', ');
          return item.author.name;
      }
      if (item.creator) {
          if (Array.isArray(item.creator)) return item.creator.map(a => a.name).join(', ');
          return item.creator.name;
      }
      return null;
  };

  // Helper for Images
  const getImage = () => {
      if (typeof item.image === 'string') return item.image;
      if (item.image && item.image.url) return item.image.url;
      if (Array.isArray(item.image)) return item.image[0];
      return null;
  };

  if (type === 'Movie' || type === 'Film') {
    metadata.contentType = 'movie';
    metadata.title = val('name');
    metadata.year = val('datePublished');
    metadata.image = getImage();
    metadata.description = val('description');
    if (item.director) metadata.author = item.director.name; // Mapping Director to "Author" field for consistency if needed, or ignore.
  } 
  else if (type === 'Book') {
    metadata.contentType = 'book';
    metadata.title = val('name');
    metadata.author = getAuthor();
    metadata.year = val('datePublished');
    metadata.image = getImage();
  }
  else if (type === 'Recipe') {
    metadata.contentType = 'recipe';
    metadata.title = val('name');
    metadata.image = getImage();
    metadata.description = val('description');
  }
  else if (item['@type']) {
     // Flexible check for news/articles (e.g. 'ReportageNewsArticle', 'OpinionNewsArticle', 'NewsArticle')
     const typeStr = Array.isArray(item['@type']) ? item['@type'].join(',') : item['@type'];
     
     if (typeStr.includes('NewsArticle') || typeStr.includes('BlogPosting') || typeStr.includes('Article')) {
         if (!metadata.contentType) {
             metadata.contentType = 'article';
             metadata.title = val('headline') || val('name');
             metadata.image = getImage();
             metadata.author = getAuthor();
             metadata.year = val('datePublished');
             metadata.description = val('description');
         }
     }
  }
  else if (['MusicAlbum'].includes(type)) {
      metadata.contentType = 'album';
      metadata.title = val('name');
      metadata.author = item.byArtist ? item.byArtist.name : null;
      metadata.image = getImage();
      metadata.year = val('datePublished');
  }
}

/**
 * Infers content type from URL or OpenGraph if JSON-LD failed specifically.
 */
function inferContentType(url, metadata) {
    if (url.includes('imdb.com/title/')) return 'movie'; // Could be TV, but movie is a safe default
    if (url.includes('youtube.com') || url.includes('youtu.be')) return 'video';
    if (url.includes('spotify.com/album')) return 'album';
    if (url.includes('allrecipes.com')) return 'recipe';
    if (url.includes('goodreads.com')) return 'book';
    if (url.includes('google.com/books') || url.includes('books.google.')) return 'book';
    
    // Default to article if title exists but unknown specific type
    if (metadata.title) return 'article';
    
    return 'article'; // Fallback
}

module.exports = { parseUrlMetadata };
