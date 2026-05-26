/**
 * GET /getOouCache
 *
 * Builds the trust graph for povToken and returns the accumulated OOU statement
 * cache so the Nerdster client can seed its channels without doing its own BFS.
 *
 * No auth required — OOU statements are public data.
 *
 * Query params:
 *   povToken        — identity token to build from (required)
 *   pathRequirement — 'permissive' | 'standard' | 'strict'  (default: 'standard')
 *
 * Response: { oouCache: { [token]: statement[] } }
 */

const { TrustPipeline } = require('./trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');
const { permissivePathRequirement, defaultPathRequirement, strictPathRequirement } = require('./trust_logic');

const pathRequirements = {
  permissive: permissivePathRequirement,
  standard: defaultPathRequirement,
  strict: strictPathRequirement,
};

async function handleGetOouCache(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const { povToken, pathRequirement: pathReqName = 'standard' } = req.query;
  if (!povToken || typeof povToken !== 'string') {
    res.status(400).send('Missing or invalid povToken');
    return;
  }

  const pathRequirement = pathRequirements[pathReqName] ?? defaultPathRequirement;

  try {
    const fedRegistry = new Map();
    const oouCache = new Map();
    const pipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor, pathRequirement });
    await pipeline.build(povToken, { fedRegistry, oouCache });

    const result = {};
    for (const [token, statements] of oouCache) {
      result[token] = statements;
    }
    res.json({ oouCache: result });
  } catch (e) {
    console.error('handleGetOouCache error:', e);
    res.status(500).send('Internal error');
  }
}

module.exports = { handleGetOouCache };
