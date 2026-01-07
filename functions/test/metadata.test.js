const { test, describe } = require('node:test');
const assert = require('node:assert');
const { fetchFromYouTube, extractTitle, extractImages } = require('../metadata_fetchers');
const cheerio = require('cheerio');
const subjects = require('./subject_samples.json');

describe('Metadata Fetcher Tests', () => {

  test('YouTube thumbnail extraction', async () => {
    const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    const images = await fetchFromYouTube(url);
    assert.ok(images.length > 0);
    assert.ok(images[0].url.includes('dQw4w9WgXcQ'));
  });

  test('Title extraction from HTML', () => {
    const html = '<html><head><title>Test Title</title></head></html>';
    const $ = cheerio.load(html);
    const title = extractTitle($, html);
    assert.strictEqual(title, 'Test Title');
  });

  test('OpenGraph title extraction', () => {
    const html = '<html><head><meta property="og:title" content="OG Title"></head></html>';
    const $ = cheerio.load(html);
    const title = extractTitle($, html);
    assert.strictEqual(title, 'OG Title');
  });

  test('Image extraction from meta tags', () => {
    const url = 'https://example.com';
    const html = '<html><head><meta property="og:image" content="https://example.com/img.jpg"></head></html>';
    const $ = cheerio.load(html);
    const images = extractImages($, url);
    assert.ok(images.some(img => img.url === 'https://example.com/img.jpg'));
  });

  test('Subject samples verification', async () => {
    // This test ensures our extractors work on the known samples
    // Note: We don't do network calls here to keep tests fast and reliable
    for (const s of subjects) {
      if (s.url && s.url.includes('youtube.com')) {
        const images = await fetchFromYouTube(s.url);
        assert.ok(images.length > 0, `Failed to get YouTube images for ${s.url}`);
        assert.ok(images[0].url, 'Image object missing url property');
      }
    }
  });
});
