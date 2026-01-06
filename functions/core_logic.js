const fetch = require("node-fetch");
const cheerio = require('cheerio');
const { 
  fetchFromOpenLibrary, 
  fetchFromWikipedia, 
  fetchFromYouTube,
  extractTitle, 
  extractImages 
} = require('./metadata_fetchers');

/**
 * Core implementation of fetchImages, decoupled from Firebase context.
 * @param {Object} subject - The subject object {url, title, contentType, author, ...}
 * @param {Object} logger - Logger object (defaults to console-like interface)
 * @returns {Promise<Object>} - { title, image, images }
 */
async function executeFetchImages(subject, logger = console) {
  if (!subject) {
    throw new Error("Missing subject object.");
  }
  
  const contentType = subject.contentType || "";
  const url = subject.url || "";
  const author = subject.author || "";
  const type = contentType.toLowerCase();
  
  let title = subject.title || "";
  let images = [];

  logger.info(`--- fetchImages: ${type || 'no-type'} | ${title || 'no-title'} | ${url || 'no-url'} ---`);

  if (!contentType && !url) {
    throw new Error("Subject must have either a contentType or a url.");
  }

  // 1. YouTube check
  if (url && (url.includes('youtube.com') || url.includes('youtu.be'))) {
    const ytImages = fetchFromYouTube(url);
    images = [...images, ...ytImages];
  }

  // 2. Fetch HTML if URL is present
  if (url && url.startsWith('http')) {
    try {
      const response = await fetch(url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
        timeout: 5000
      });
      if (response.ok) {
        const html = await response.text();
        const $ = cheerio.load(html);
        const scrapedTitle = extractTitle($, html);
        if (!title) title = scrapedTitle;
        const scrapedImages = extractImages($, url);
        images = [...images, ...scrapedImages];
      }
    } catch (e) {
      logger.error(`[fetchImages] HTML Fetch Error: ${e.message}`);
    }
  }

  // 3. Smart Fetch (Wikipedia/OpenLibrary) for specific types
  const smartTypes = ['book', 'movie', 'person', 'place', 'work', 'video'];
  if (title && (images.length === 0 || smartTypes.includes(type))) {
    // Skip hash-like titles (e.g. content-addressed IDs)
    if (!/^[0-9a-f]{32,40}$/i.test(title)) {
      let searchTitle = title.replace(/ - Amazon\.com:.*$/i, '').replace(/ - YouTube$/i, '').trim();
      let cleanAuthor = (author && author.length < 50) ? author : "";

      if (type === 'book') {
        let ol = await fetchFromOpenLibrary(searchTitle, cleanAuthor);
        if (ol.length === 0 && searchTitle.includes(':')) {
          ol = await fetchFromOpenLibrary(searchTitle.split(':')[0].trim(), cleanAuthor);
        }
        images = [...ol, ...images];
      }
      
      // Fallback or supplement with Wikipedia
      if (images.length === 0 || type !== 'book') {
        let wiki = await fetchFromWikipedia(searchTitle);
        if (wiki.length === 0 && searchTitle.includes(':')) {
          wiki = await fetchFromWikipedia(searchTitle.split(':')[0].trim());
        }
        images = [...wiki, ...images];
      }
    }
  }

  // Final cleanup: unique, valid URLs
  images = [...new Set(images)].filter(img => img && typeof img === 'string' && img.startsWith('http'));
  
  return {
    "title": title,
    "image": images.length > 0 ? images[0] : null,
    "images": images
  };
}

module.exports = { executeFetchImages };
