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
  if (!html) {
      const fetch = require("node-fetch");
      try {
        const response = await fetch(url, {
             headers: { 
                 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                 'Accept-Language': 'en-US,en;q=0.9',
                 'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
             },
             redirect: 'follow',
             timeout: 10000
        });
        if (!response.ok) {
            logger.warn(`[MagicPaste] HTTP Error ${response.status} for ${url}`);
            return null;
        }
        
        // Update URL to the final destination (handling redirects like a.co -> amazon.com)
        if (response.url && response.url !== url) {
             url = response.url;
        }
        
        html = await response.text();
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
          // Optional: Clean title? Keeping it might be safer for now.
      }
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
  else if (['NewsArticle', 'BlogPosting', 'Article'].includes(type)) {
     // Only set if we haven't found a more specific type yet
     if (!metadata.contentType) {
         metadata.contentType = 'article';
         metadata.title = val('headline') || val('name');
         metadata.image = getImage();
         metadata.author = getAuthor();
         metadata.year = val('datePublished');
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
