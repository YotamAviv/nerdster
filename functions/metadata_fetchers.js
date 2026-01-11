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
        return [{ url: `https://covers.openlibrary.org/b/id/${data.covers[0]}-L.jpg`, source: 'openlibrary' }];
      }
    }

    // 2. Search by Title/Author
    if (title) {
      searchUrl = `https://openlibrary.org/search.json?title=${encodeURIComponent(title)}&limit=1`;
      if (author) searchUrl += `&author=${encodeURIComponent(author)}`;
      
      const response = await fetch(searchUrl, { timeout: 5000 });
      const data = await response.json();
      if (data.docs && data.docs.length > 0 && data.docs[0].cover_i) {
        return [{ url: `https://covers.openlibrary.org/b/id/${data.docs[0].cover_i}-L.jpg`, source: 'openlibrary' }];
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
async function fetchFromWikipedia(title, url = "", contentType = "", year = "") {
  logger.info(`[Wikipedia] Searching: "${title}" | "${contentType}" | "${year}"`);
  try {
    let bestTitle = title;
    if (url && url.includes('wikipedia.org/wiki/')) {
      bestTitle = decodeURIComponent(url.split('/wiki/')[1].replace(/_/g, ' '));
    }

    if (bestTitle) {
      const searchTerms = [bestTitle];
      if (contentType === 'movie') {
        if (!bestTitle.toLowerCase().includes('film') && !bestTitle.toLowerCase().includes('movie')) {
          searchTerms.unshift(`${bestTitle} (film)`);
          if (year) {
            searchTerms.unshift(`${bestTitle} (${year} film)`);
          }
          searchTerms.push(`${bestTitle} movie`);
        }
      }

      for (const term of searchTerms) {
        let currentTitle = term;
        // Search for the best page title if we don't have a direct URL
        if (!url || term !== bestTitle) {
          const searchUrl = `https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(term)}&format=json&origin=*`;
          const response = await fetch(searchUrl, {
            headers: { 'User-Agent': 'NerdsterBot/1.0' },
            timeout: 5000
          });
          const data = await response.json();
          if (data.query?.search?.length > 0) {
            currentTitle = data.query.search[0].title;
          } else {
            continue;
          }
        }
        
        // 1. Try PageImages API (High quality thumbnails)
        const imageUrl = `https://en.wikipedia.org/w/api.php?action=query&titles=${encodeURIComponent(currentTitle)}&prop=pageimages&format=json&pithumbsize=1000&origin=*`;
        const response = await fetch(imageUrl, {
          headers: { 'User-Agent': 'NerdsterBot/1.0' },
          timeout: 5000
        });
        const data = await response.json();
        const pages = data.query.pages;
        const pageId = Object.keys(pages)[0];
        if (pageId !== "-1" && pages[pageId].thumbnail) {
          return [{ url: pages[pageId].thumbnail.source, source: 'wikipedia' }];
        }

        // 2. Fallback: Scrape the infobox image
        const pageUrl = `https://en.wikipedia.org/wiki/${encodeURIComponent(currentTitle.replace(/ /g, '_'))}`;
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
            return [{ url: fullImgUrl, source: 'wikipedia' }];
          }
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
    if (content && !images.some(img => img.url === content)) {
      images.push({ url: content, source: 'opengraph' });
    }
  });

  // 2. Scrape <img> tags (limit to 10)
  $('img').each((i, el) => {
    if (images.length >= 10) return false;
    let src = $(el).attr('src');
    if (src && !src.includes('icon') && !src.includes('logo') && !src.includes('pixel')) {
       // Check duplication against URL
       if (!images.some(img => img.url === src)) {
          images.push({ url: src, source: 'html-scrape' });
       }
    }
  });

  // Normalize relative URLs
  return images.map(img => {
    if (img.url && !img.url.startsWith('http')) {
      try {
        const baseUrl = new URL(url);
        return { ...img, url: new URL(img.url, baseUrl.origin).href };
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
async function fetchFromYouTube(url) {
  if (!url) return [];
  let videoId = null;
  if (url.includes('youtu.be/')) videoId = url.split('youtu.be/')[1].split(/[?#]/)[0];
  else if (url.includes('v=')) videoId = url.split('v=')[1].split(/[&?#]/)[0];
  else if (url.includes('embed/')) videoId = url.split('embed/')[1].split(/[?#]/)[0];

  if (videoId) {
    const maxResUrl = `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`;
    const hqUrl = `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`;
    
    try {
      // Check if maxresdefault exists
      const response = await fetch(maxResUrl, { method: 'HEAD', timeout: 2000 });
      if (response.ok) {
        return [
          { url: maxResUrl, source: 'youtube' },
          { url: hqUrl, source: 'youtube' }
        ];
      }
    } catch (e) {
      // ignore error, fallback to hqdefault
    }

    return [
      { url: hqUrl, source: 'youtube' }
    ];
  }
  return [];
}

/**
 * Searches OMDb for movie metadata and images.
 * Requires an API key (OMDB_API_KEY).
 */
async function fetchFromOMDb(title, year = "") {
  const apiKey = process.env.OMDB_API_KEY;
  if (!apiKey || !title) return [];
  
  logger.info(`[OMDb] Searching: "${title}" (${year})`);
  try {
    let url = `http://www.omdbapi.com/?apikey=${apiKey}&t=${encodeURIComponent(title)}`;
    if (year) url += `&y=${year}`;
    
    const response = await fetch(url, { timeout: 5000 });
    const data = await response.json();
    
    if (data.Response === "True" && data.Poster && data.Poster !== "N/A") {
      return [{ url: data.Poster, source: 'omdb' }];
    }
  } catch (e) {
    logger.error(`[OMDb] Error: ${e.message}`);
  }
  return [];
}

/**
 * Searches TMDB for movie posters.
 * Requires an API key (TMDB_API_KEY).
 */
async function fetchFromTMDB(title, year = "") {
  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey || !title) return [];
  
  logger.info(`[TMDB] Searching: "${title}" (${year})`);
  try {
    let url = `https://api.themoviedb.org/3/search/movie?api_key=${apiKey}&query=${encodeURIComponent(title)}`;
    if (year) url += `&year=${year}`;
    
    const response = await fetch(url, { timeout: 5000 });
    const data = await response.json();
    
    if (data.results && data.results.length > 0 && data.results[0].poster_path) {
      const posterUrl = `https://image.tmdb.org/t/p/w1280${data.results[0].poster_path}`;
      return [{ url: posterUrl, source: 'tmdb' }];
    }
  } catch (e) {
    logger.error(`[TMDB] Error: ${e.message}`);
  }
  return [];
}

module.exports = {
  fetchFromOpenLibrary,
  fetchFromWikipedia,
  fetchFromYouTube,
  fetchFromOMDb,
  fetchFromTMDB,
  extractTitle,
  extractImages
};
