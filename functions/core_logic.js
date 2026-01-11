const fetch = require("node-fetch");
const cheerio = require('cheerio');
const { 
  fetchFromOpenLibrary, 
  fetchFromWikipedia, 
  fetchFromYouTube,
  fetchFromOMDb,
  fetchFromTMDB,
  extractTitle, 
  extractImages 
} = require('./metadata_fetchers');

/**
 * Core implementation of fetchImages, decoupled from Firebase context.
 * @param {Object} subject - The subject object {url, title, contentType, author, ...}
 * @param {Object} logger - Logger object (defaults to console-like interface)
 * @param {number} maxImages - Optional limit. If set, creating 'maxImages' early terminates further fetching.
 * @returns {Promise<Object>} - { title, image, images }
 */
async function executeFetchImages(subject, logger = console, maxImages = null) {
  if (!subject) {
    throw new Error("Missing subject object.");
  }
  
  const contentType = subject.contentType || "";
  const url = subject.url || "";
  const author = subject.author || "";
  const year = subject.year || "";
  const type = contentType.toLowerCase();
  
  let title = subject.title || "";
  let images = [];

  logger.info(`--- fetchImages: ${type || 'no-type'} | ${title || 'no-title'} | ${url || 'no-url'} ---`);

  if (!contentType && !url) {
    throw new Error("Subject must have either a contentType or a url.");
  }

  // 1. YouTube check
  if (url && (url.includes('youtube.com') || url.includes('youtu.be'))) {
    const ytImages = await fetchFromYouTube(url);
    images = [...images, ...ytImages];
  }

  // Early termination if we have enough images
  if (maxImages && images.length >= maxImages) {
    return {
      "title": title,
      "images": images.slice(0, maxImages)
    };
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

  // Early termination
  if (maxImages && images.length >= maxImages) {
    return {
      "title": title,
      "images": images.slice(0, maxImages)
    };
  }

  // 3. Smart Fetch (Wikipedia/OpenLibrary/MovieAPIs)
  // Skip hash-like titles (e.g. content-addressed IDs)
  if (!/^[0-9a-f]{32,40}$/i.test(title)) {
    let searchTitle = title.replace(/ - Amazon\.com:.*$/i, '').replace(/ - YouTube$/i, '').trim();
    let cleanAuthor = (author && author.length < 50) ? author : "";

    if (type === 'book') {
      let ol = await fetchFromOpenLibrary(searchTitle, cleanAuthor);
      if (ol.length === 0 && searchTitle.includes(':')) {
        ol = await fetchFromOpenLibrary(searchTitle.split(':')[0].trim(), cleanAuthor);
      }
      images = [...images, ...ol];
    } else if (type === 'movie') {
      const omdb = await fetchFromOMDb(searchTitle, year);
      const tmdb = await fetchFromTMDB(searchTitle, year);
      images = [...images, ...omdb, ...tmdb];
    }
    
    // Fallback or supplement with Wikipedia
    if (images.length === 0 || type !== 'book') {
      let wiki = await fetchFromWikipedia(searchTitle, "", type, year);
      if (wiki.length === 0 && searchTitle.includes(':')) {
        wiki = await fetchFromWikipedia(searchTitle.split(':')[0].trim(), "", type, year);
      }
      images = [...images, ...wiki];
    }
  }

  // Final cleanup: unique, valid URLs
  const uniqueImages = [];
  const seenUrls = new Set();
  
  for (const img of images) {
    if (img && img.url && typeof img.url === 'string' && img.url.startsWith('http')) {
       if (!seenUrls.has(img.url)) {
         seenUrls.add(img.url);
         uniqueImages.push(img);
       }
    }
  }
  images = uniqueImages;
  
  return {
    "title": title,
    "images": images
  };
}

module.exports = { executeFetchImages };
