/**
 * seedNerdster — returns a pre-fetched seed bag for startup channel seeding.
 *
 * The bag is a flat map { fetchUrl: statements[] } where each key is the
 * canonical fetch URL that _CloudFunctionsSource would construct for that
 * token.  The client passes the bag to ChannelFactory.loadSeedBag() and then
 * proceeds as normal — all startup fetches hit the bag instead of the network.
 *
 * Three buckets (all using the same URL key format as the Dart client):
 *   1. OOU trust statements   — keyed under export.one-of-us.net, no excludeTypes
 *   2. Delegate content (all) — keyed under export.nerdster.org, no excludeTypes
 *   3. Delegate content (no dismiss) — keyed under export.nerdster.org, excludeTypes=org.nerdster.dis
 *
 * No auth required — all data is public.
 */

const { TrustPipeline } = require('./trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');
const { permissivePathRequirement, defaultPathRequirement, strictPathRequirement } = require('./trust_logic');
const { fetchStatements, makedistinct } = require('./statement_fetcher');
const { getToken } = require('./jsonish_util');

const OOU_EXPORT_URL = 'https://export.one-of-us.net';
const NERDSTER_EXPORT_URL = 'https://export.nerdster.org';
const NERDSTER_DOMAIN = 'nerdster.org';
const DISMISS_TYPE = 'org.nerdster.dis';

const pathRequirements = {
  permissive: permissivePathRequirement,
  standard: defaultPathRequirement,
  strict: strictPathRequirement,
};

/**
 * Canonical fetch URL for a single token — matches what _CloudFunctionsSource._bagKey() produces.
 * Params must stay in sync with _paramsProto + paramsOverride in channel_factory.dart.
 */
function bagKey(baseUrl, token, excludeTypes = []) {
  const sorted = [...excludeTypes].sort();
  const parts = [
    'distinct=true',
    'orderStatements=false',
    'includeId=true',
    'checkPrevious=true',
  ];
  for (const t of sorted) parts.push(`excludeTypes=${encodeURIComponent(t)}`);
  parts.push(`spec=${encodeURIComponent(JSON.stringify([token]))}`);
  return `${baseUrl}?${parts.join('&')}`;
}

/**
 * Extracts all delegate tokens referenced in the OOU trust statements.
 */
function collectDelegateTokens(oouCache) {
  const tokens = new Set();
  for (const statements of oouCache.values()) {
    for (const s of statements) {
      if (s.delegate != null && s.with?.domain === NERDSTER_DOMAIN) {
        const t = getToken(s.delegate);
        if (t) tokens.add(t);
      }
    }
  }
  return tokens;
}

async function handleSeedNerdster(req, res) {
  res.setHeader('Content-Type', 'application/json');

  const { povToken, pathRequirement: pathReqName = 'standard' } = req.query;
  if (!povToken || typeof povToken !== 'string') {
    res.status(400).send('Missing or invalid povToken');
    return;
  }

  const pathRequirement = pathRequirements[pathReqName] ?? defaultPathRequirement;

  try {
    // 1. Build OOU trust graph (same as getOouCache)
    const fedRegistry = new Map();
    const oouCache = new Map();
    const pipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor, pathRequirement });
    await pipeline.build(povToken, { fedRegistry, oouCache });

    const bag = {};

    // 2. OOU trust statements — apply makedistinct to match what export?distinct=true returns
    for (const [token, statements] of oouCache) {
      bag[bagKey(OOU_EXPORT_URL, token)] = await makedistinct(statements);
    }

    // 3. Delegate content — fetch from Nerdster Firestore
    const delegateTokens = collectDelegateTokens(oouCache);
    const fetchParams = { distinct: true, includeId: true, orderStatements: false, checkPrevious: true };
    const fetchParamsNoDismiss = { ...fetchParams, excludeTypes: [DISMISS_TYPE] };

    await Promise.all([...delegateTokens].map(async (token) => {
      const [allStatements, noDismiss] = await Promise.all([
        fetchStatements({ [token]: null }, fetchParams),
        fetchStatements({ [token]: null }, fetchParamsNoDismiss),
      ]);
      bag[bagKey(NERDSTER_EXPORT_URL, token)] = allStatements;
      bag[bagKey(NERDSTER_EXPORT_URL, token, [DISMISS_TYPE])] = noDismiss;
    }));

    res.json(bag);
  } catch (e) {
    console.error('handleSeedNerdster error:', e);
    res.status(500).send('Internal error');
  }
}

module.exports = { handleSeedNerdster };
