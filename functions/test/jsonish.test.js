const { test, describe } = require('node:test');
const assert = require('node:assert');
const { getToken, order, parseIrevoke } = require('../jsonish_util');

// Load parity data from the root test directory
const yotam_oneofus = require('../../test/yotam-oneofus.json');
const yotam_nerdster = require('../../test/yotam-nerdster.json');
const other = require('../../test/other.json');

describe('Jsonish Parity Tests', () => {
  
  test('parseIrevoke handles simple tokens and JSON strings', () => {
    assert.deepStrictEqual(parseIrevoke('token123'), { 'token123': null });
    assert.deepStrictEqual(parseIrevoke('{"token123": null}'), { 'token123': null });
    assert.deepStrictEqual(parseIrevoke('{"token123": "revoker"}'), { 'token123': 'revoker' });
    assert.deepStrictEqual(parseIrevoke({ 'token123': 'revoker' }), { 'token123': 'revoker' });
  });

  test('getToken matches Dart-generated IDs (Parity)', async () => {
    const datasets = [
      { name: 'yotam-oneofus', data: yotam_oneofus },
      { name: 'yotam-nerdster', data: yotam_nerdster },
      { name: 'other', data: other }
    ];

    for (const { name, data } of datasets) {
      for (const statement of data.statements) {
        const expectedId = statement.id;
        
        // Clone and remove ID to recalculate
        const { id, ...statementWithoutId } = statement;
        const actualId = await getToken(statementWithoutId);
        
        assert.strictEqual(actualId, expectedId, 
          `ID mismatch in ${name} for statement: ${JSON.stringify(statementWithoutId)}`);
      }
    }
  });

  test('order function is deterministic', () => {
    const obj1 = { b: 2, a: 1, signature: 'sig' };
    const obj2 = { a: 1, b: 2, signature: 'sig' };
    
    const ordered1 = order(obj1);
    const ordered2 = order(obj2);
    
    assert.deepStrictEqual(ordered1, ordered2);
    assert.strictEqual(Object.keys(ordered1)[0], 'a');
    assert.strictEqual(Object.keys(ordered1)[2], 'signature');
  });
});
