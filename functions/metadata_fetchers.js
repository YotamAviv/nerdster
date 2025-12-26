/**
 * Metadata Fetchers
 * 
 * Utilities for fetching titles and images from external sources like 
 * OpenLibrary, Wikipedia, and YouTube, or by scraping HTML.
 */

const fetch = require("node-fetch");
const cheerio = require('cheerio');
const { decode } = require('html-entities');
const { logger } = require("firebase-functions");

/**
 * Searches OpenLibrary for a book cover.
 */
async function fetchFromOpenLibrary(title, author = "", url = "") {
  logger.info(`[OpenLibrary] Searching: "${title}" | "${author}"`);
  try {
    let searchUrl;
    
    // 1. Direct Work/Book ID from URL
    if (url && url.includes('openlibrary.org/works/')) {
      const workId = url.split('/works/')[1].split('/')[0];
      searchUrl = `https://openlibrary.org/works/${workId}.json`;
    } else if (url && url.includes('openlibrary.org/books/')) {
      const bookId = url.split('/books/')[1].split('/')[0];
      searchUrl = `https://openlibrary.org/books/${bookId}.json`;
    }

    if (searchUrl) {
      const response = await fetch(searchUrl, { timeout: 5000 });
      const data = await response.json();
      if (data.covers && data.covers.length > 0) {
        return [`https://covers.openlibrary.org/b/id/${data.covers[0]}-L.jpg`];
      }
    }

    // 2. Search by Title/Author
    if (title) {
      searchUrl = `https://openlibrary.org/search.json?title=${encodeURIComponent(title)}&limit=1`;
      if (author) searchUrl += `&author=${encodeURIComponent(author)}`;
      
      const response = await fetch(searchUrl, { timeout: 5000 });
      const data = await response.json();
      if (data.docs && data.docs.length > 0 && data.docs[0].cover_i) {
        return [`https://covers.openlibrary.org/b/id/${data.docs[0].cover_i}-L.jpg`];
      }
    }
  } catch (e) {
    logger.error(`[OpenLibrary] Error: ${e.message}`);
  }
  return [];
}

/**
 * Searches Wikipedia for a representative image.
 */
async function fetchFromWikipedia(title, url = "") {
  logger.info(`[Wikipedia] Searching: "${title}"`);
  try {
    let bestTitle = title;
    if (url && url.includes('wikipedia.org/wiki/')) {
      bestTitle = decodeURIComponent(url.split('/wiki/')[1].replace(/_/g, ' '));
    }

    if (bestTitle) {
      // Search for the best page title if we don't have a direct URL
      if (!url) {
        const searchUrl = `https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(bestTitle)}&format=json&origin=*`;
        const response = await fetch(searchUrl, {
          headers: { 'User-Agent': 'NerdsterBot/1.0' },
          timeout: 5000
        });
        const data = await response.json();
        if (data.query?.search?.length > 0) {
          bestTitle = data.query.search[0].title;
        } else {
          return [];
        }
      }
      
      // 1. Try PageImages API (High quality thumbnails)
      const imageUrl = `https://en.wikipedia.org/w/api.php?action=query&titles=${encodeURIComponent(bestTitle)}&prop=pageimages&format=json&pithumbsize=1000&origin=*`;
      const response = await fetch(imageUrl, {
        headers: { 'User-Agent': 'NerdsterBot/1.0' },
        timeout: 5000
      });
      const data = await response.json();
      const pages = data.query.pages;
      const pageId = Object.keys(pages)[0];
      if (pageId !== "-1" && pages[pageId].thumbnail) {
        return [pages[pageId].thumbnail.source];
      }

      // 2. Fallback: Scrape the infobox image
      const pageUrl = `https://en.wikipedia.org/wiki/${encodeURIComponent(bestTitle.replace(/ /g, '_'))}`;
      const pageResponse = await fetch(pageUrl, {
        headers: { 'User-Agent': 'NerdsterBot/1.0' },
        timeout: 5000
      });
      if (pageResponse.ok) {
        const html = await pageResponse.text();
        const $ = cheerio.load(html);
        const infoboxImg = $('.infobox img').first().attr('src');
        if (infoboxImg) {
          let fullImgUrl = infoboxImg.startsWith('//') ? `https:${infoboxImg}` : infoboxImg;
          if (fullImgUrl.includes('/thumb/')) {
            const parts = fullImgUrl.split('/');
            fullImgUrl = parts.slice(0, parts.length - 1).join('/').replace('/thumb/', '/');
          }
          return [fullImgUrl];
        }
      }
    }
  } catch (e) {
    logger.error(`[Wikipedia] Error: ${e.message}`);
  }
  return [];
}

/**
 * Extracts the title from HTML using OpenGraph, Twitter, or <title> tags.
 */
function extractTitle($, htmlString) {
  let title = $('meta[property="og:title"]').attr('content') || 
              $('meta[name="twitter:title"]').attr('content');
  
  if (!title) {
    const match = htmlString.match(/<title>(.*?)<\/title>/i);
    title = match ? match[1].trim() : null;
  }
  
  return title ? decode(title).trim() : null;
}

/**
 * Extracts images from HTML, prioritizing meta tags and then <img> tags.
 */
function extractImages($, url) {
  const images = [];
  if (!url) return images;
  
  // 1. Meta Tags
  const metaSelectors = [
    'meta[property="og:image"]',
    'meta[property="og:image:url"]',
    'meta[name="twitter:image"]',
    'link[rel="image_src"]'
  ];
  metaSelectors.forEach(selector => {
    const content = $(selector).attr('content') || $(selector).attr('href');
    if (content && !images.includes(content)) images.push(content);
  });

  // 2. Scrape <img> tags (limit to 10)
  $('img').each((i, el) => {
    if (images.length >= 10) return false;
    let src = $(el).attr('src');
    if (src && !src.includes('icon') && !src.includes('logo') && !src.includes('pixel')) {
      images.push(src);
    }
  });

  // Normalize relative URLs
  return images.map(img => {
    if (img && !img.startsWith('http')) {
      try {
        const baseUrl = new URL(url);
        return new URL(img, baseUrl.origin).href;
      } catch (e) {
        return img;
      }
    }
    return img;
  });
}

/**
 * Extracts YouTube thumbnails from a URL.
 */
function fetchFromYouTube(url) {
  if (!url) return [];
  let videoId = null;
  if (url.includes('youtu.be/')) videoId = url.split('youtu.be/')[1].split(/[?#]/)[0];
  else if (url.includes('v=')) videoId = url.split('v=')[1].split(/[&?#]/)[0];
  else if (url.includes('embed/')) videoId = url.split('embed/')[1].split(/[?#]/)[0];

  if (videoId) {
    return [
      `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`,
      `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`
    ];
  }
  return [];
}

module.exports = {
  fetchFromOpenLibrary,
  fetchFromWikipedia,
  fetchFromYouTube,
  extractTitle,
  extractImages
};
