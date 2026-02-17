const { test, describe } = require('node:test');
const assert = require('node:assert');
const { parseUrlMetadata } = require('../url_metadata_parser');

describe('IMDb Inference', () => {
    test('Should infer "movie" from IMDb URL even without JSON-LD', async () => {
        // Minimal HTML with just a title, NO JSON-LD
        const html = `<html><head><title>The Matrix (1999) - IMDb</title></head></html>`;
        const url = 'https://www.imdb.com/title/tt0133093/';
        
        const metadata = await parseUrlMetadata(url, html);
        
        assert.strictEqual(metadata.contentType, 'movie');
        // It might extract year from title if the logic is there?
        // Let's check if my previous read of url_metadata_parser.js showed year extraction from title.
        // Yes: "Fallback Year extraction from Title (e.g. "The Matrix (1999)")"
        assert.strictEqual(metadata.year, '1999');
        assert.strictEqual(metadata.title, 'The Matrix (1999) - IMDb');
    });
});
