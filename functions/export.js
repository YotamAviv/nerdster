/**
 * export — HTTP GET endpoint
 *
 * Exports statements as a newline-delimited JSON stream.
 * Mapped to https://export.nerdster.org (and https://export.one-of-us.net in oneofusv22).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * QUERY PARAMETERS
 * ─────────────────────────────────────────────────────────────────────────────
 * spec (required)       — key token or JSON array/object of tokens
 * distinct              — deduplicate by verb+subject (keep most recent)
 * orderStatements       — default true; set false to skip key ordering
 * includeId             — include the statement token as "id" field on each statement
 * checkPrevious         — verify notarization chain (requires includeId)
 * after=<ISO time>      — only return statements newer than this time
 * omit=<field>          — strip field from each statement (repeatable)
 * excludeTypes=<type>   — exclude statements of this type (repeatable, e.g. excludeTypes=org.nerdster.dis)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * RESPONSE
 * ─────────────────────────────────────────────────────────────────────────────
 * Newline-delimited JSON objects, one per key:
 *   { "<token>": [ ...statements ] }
 *   { "<token>": { "error": "..." } }   // on per-key error
 *
 * If an error occurs for a specific key, the stream continues for remaining keys.
 */

const { logger } = require("firebase-functions");
const { fetchStatementsBatch } = require('./statement_fetcher');
const { parseIrevoke } = require('./jsonish_util');

async function handleExport(req, res, { authHook } = {}) {
  if (req.path === '/openapi.yaml') {
    const fs = require('fs');
    const path = require('path');
    const yaml = fs.readFileSync(path.join(__dirname, 'openapi.yaml'), 'utf8');
    res.setHeader('Content-Type', 'application/yaml');
    res.send(yaml);
    return;
  }

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  try {
    if (authHook) {
      const authOk = await authHook(req, res);
      if (!authOk) return;
    }

    const specParam = req.query.spec;
    if (!specParam) {
      res.status(400).type('text').send(
        'ONE-OF-US.NET Export API\n\n' +
        'Required parameter: spec — key token or JSON array/object of tokens.\n\n' +
        'Optional parameters:\n' +
        '  distinct                    — deduplicate by verb+subject (keep most recent)\n' +
        '  orderStatements             — default true; set false to skip key ordering\n' +
        '  includeId                   — include the statement token as "id" field on each statement\n' +
        '  checkPrevious               — verify notarization chain (requires includeId)\n' +
        '  after=<ISO time>            — only return statements newer than this time\n' +
        '  omit=<field>                — strip field from each statement (repeatable)\n' +
        '  excludeTypes=<type>         — exclude statements of this type (repeatable)\n\n' +
        'Example:\n' +
        '  https://export.one-of-us.net/?spec=<token>&distinct=true&omit=I&omit=signature\n\n' +
        'See /openapi.yaml for full API documentation.\n'
      );
      return;
    }

    const specString = decodeURIComponent(specParam);
    let specs = /^\s*[\[{"]/.test(specString) ? JSON.parse(specString) : specString;
    if (!Array.isArray(specs)) specs = [specs];

    const params = req.query;
    const omit = params.omit;

    const token2revoked = {};
    for (const spec of specs) {
      const parsed = parseIrevoke(spec);
      Object.assign(token2revoked, parsed);
    }

    const results = await fetchStatementsBatch(token2revoked, params, omit);
    for (const [token, result] of Object.entries(results)) {
      if (result?.error) logger.error(`[export] Error fetching ${token}: ${result.error}`);
      res.write(JSON.stringify({ [token]: result }) + '\n');
    }
    res.end();
  } catch (e) {
    logger.error(`[export] Error: ${e.message}`);
    if (!res.headersSent) {
      res.status(500).send(`Error: ${e.message}`);
    } else {
      res.end();
    }
  }
}

module.exports = { handleExport };
