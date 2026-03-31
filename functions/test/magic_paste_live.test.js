const { test, describe } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const { parseUrlMetadata } = require('../url_metadata_parser');

describe('Magic Paste Live Network Integrations', () => {

  // Load the shared test cases JSON
  const casesPath = path.join(__dirname, 'magic_paste_cases.json');
  const rawData = fs.readFileSync(casesPath, 'utf8');
  const allCases = JSON.parse(rawData);

  const requiredCases = allCases.filter(c => c.expectSuccess === true);
  const optionalCases = allCases.filter(c => c.expectSuccess === false);

  describe('Required Cases (Must Pass)', () => {
    for (const tc of requiredCases) {
      const caseName = tc.note ? `${tc.url} (${tc.note})` : tc.url;
      
      test(caseName, async () => {
        // We explicitly omit the second parameter (html) to force a live fetch
        const result = await parseUrlMetadata(tc.url);
        
        // Assert it didn't completely fail
        assert.notStrictEqual(result, null, `magicPaste returned null for ${tc.url}`);

        if ('expectedContentType' in tc) {
          assert.strictEqual(result.contentType, tc.expectedContentType, 
            `Expected contentType: ${tc.expectedContentType}, got: ${result.contentType}`);
        }
        
        if ('expectedTitle' in tc) {
          assert.ok(result.title && result.title.includes(tc.expectedTitle), 
            `Expected title to contain: "${tc.expectedTitle}", got: "${result.title}"`);
        }
        
        if ('expectedYear' in tc) {
          assert.strictEqual(result.year, tc.expectedYear, 
            `Expected year: ${tc.expectedYear}, got: ${result.year}`);
        }
        
        if ('expectedAuthor' in tc) {
          assert.strictEqual(result.author, tc.expectedAuthor, 
            `Expected author: ${tc.expectedAuthor}, got: ${result.author}`);
        }
      });
    }
  });

  describe('Optional Cases (Expect Failure / Unreliable)', () => {
    for (const tc of optionalCases) {
      const caseName = tc.note ? `${tc.url} (${tc.note})` : tc.url;
      
      test(caseName, async () => {
        // These are evaluated just to ensure they don't crash the parser natively.
        // We don't formally assert their extracted values against failure conditions 
        // to maintain parity with the dart integration_test architecture.
        const result = await parseUrlMetadata(tc.url);
        
        // Optionally log result in a CI environment
        if (result === null) {
            // Documenting known unreliable behavior
            assert.ok(true, "Returned null as expected.");
        } else {
            assert.ok(true, `Returned payload gracefully: ${result.title}`);
        }
      });
    }
  });

});
