const { test, describe } = require('node:test');
const assert = require('node:assert');
const { parseUrlMetadata } = require('../url_metadata_parser');
const cheerio = require('cheerio');

describe('Magic Paste (parseUrlMetadata)', () => {

  test('Scenario A: Rich JSON-LD (Movie)', async () => {
    // Mock HTML with full Schema.org
    const html = `
      <html>
        <head>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Movie",
            "name": "The Godfather",
            "datePublished": "1972",
            "image": "https://example.com/godfather.jpg",
            "director": { "name": "Francis Ford Coppola" }
          }
          </script>
        </head>
      </html>
    `;
    const metadata = await parseUrlMetadata('https://imdb.com/godfather', html);
    
    assert.strictEqual(metadata.contentType, 'movie');
    assert.strictEqual(metadata.title, 'The Godfather');
    assert.strictEqual(metadata.year, '1972');
    assert.strictEqual(metadata.image, 'https://example.com/godfather.jpg');
    assert.strictEqual(metadata.author, 'Francis Ford Coppola');
  });

  test('Scenario B: NYT Style (Specialized Article Type)', async () => {
    // Test the logic that handles "ReportageNewsArticle" etc.
    const html = `
      <html>
        <head>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "ReportageNewsArticle",
            "headline": "Something Happened",
            "datePublished": "2026-02-17"
          }
          </script>
        </head>
      </html>
    `;
    const metadata = await parseUrlMetadata('https://nytimes.com/article', html);
    
    // Should be normalized to 'article'
    assert.strictEqual(metadata.contentType, 'article');
    assert.strictEqual(metadata.title, 'Something Happened');
    assert.strictEqual(metadata.year, '2026');
  });

  test('Scenario C: Fallback to Simple Title (No Metadata)', async () => {
    // This simulates a site that blocks scraper bots or has no schema.
    // The previous implementation would fail/return null here.
    // The new implementation should grab the <title> tag.
    const html = `
      <html>
        <head>
          <title>Just A Simple Blog Post</title>
        </head>
        <body>
          <h1>Welcome to my blog</h1>
        </body>
      </html>
    `;
    const metadata = await parseUrlMetadata('https://simpleblog.com/post', html);

    assert.strictEqual(metadata.title, 'Just A Simple Blog Post');
    // Should default to article if we have a title
    assert.strictEqual(metadata.contentType, 'article');
  });

  test('Scenario D: Broken JSON-LD', async () => {
    // JSON parse error should be caught and fallback to OpenGraph/Title
    const html = `
      <html>
        <head>
          <script type="application/ld+json">
            { BROKEN JSON ...
          </script>
          <meta property="og:title" content="OpenGraph Title" />
        </head>
      </html>
    `;
    const metadata = await parseUrlMetadata('https://broken.com', html);

    assert.strictEqual(metadata.title, 'OpenGraph Title');
    assert.strictEqual(metadata.contentType, 'article'); 
  });

});
