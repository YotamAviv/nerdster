/**
 * seedNerdster — returns a pre-fetched seed bag for startup channel seeding.
 *
 * The bag is a flat map { fetchUrl: statements[] } where each key is the
 * canonical fetch URL that _CloudFunctionsSource would construct for that
 * token.  The client passes the bag to ChannelFactory.loadSeedBag() and then
 * proceeds as normal — all startup fetches hit the bag instead of the network.
 *
 * Two buckets (all using the same URL key format as the Dart client):
 *   1. OOU trust statements — keyed under each token's source URL (export.one-of-us.net or federated), no excludeTypes
 *   2. Delegate content — keyed under export.nerdster.org:
 *        own delegate(s): all statements including dismiss, no excludeTypes
 *        peer delegates:  excludeTypes=org.nerdster.dis
 *
 * No auth required — all data is public.
 */

const { TrustPipeline } = require('./trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');
const { permissivePathRequirement, defaultPathRequirement, strictPathRequirement } = require('./trust_logic');
const { fetchStatementsBatch, makedistinct } = require('./statement_fetcher');
const { DelegateResolver } = require('./delegate_resolver');

const OOU_EXPORT_URL = 'https://export.one-of-us.net';
const NERDSTER_EXPORT_URL = 'https://export.nerdster.org';
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
    const graph = await pipeline.build(povToken, { fedRegistry, oouCache });

    const bag = {};

    // 2. OOU trust statements — apply makedistinct to match what export?distinct=true returns
    for (const [token, statements] of oouCache) {
      const url = fedRegistry.get(token) ?? OOU_EXPORT_URL;
      bag[bagKey(url, token)] = await makedistinct(statements);
    }

    // 3. Delegate content — fetch from Nerdster Firestore
    const resolver = new DelegateResolver(graph, oouCache, { maxStatements: Infinity });
    resolver.resolveAll();
    const delegateTokens = resolver.getAllDelegateTokens();
    const fetchParams = { distinct: true, includeId: true, orderStatements: false, checkPrevious: true };
    const fetchParamsNoDismiss = { ...fetchParams, excludeTypes: [DISMISS_TYPE] };

    const ownTokens = {};
    const peerTokens = {};
    for (const token of delegateTokens) {
      if (resolver.getIdentityForDelegate(token) === povToken) {
        ownTokens[token] = null;
      } else {
        peerTokens[token] = null;
      }
    }

    const [ownResults, peerResults] = await Promise.all([
      fetchStatementsBatch(ownTokens, fetchParams),
      fetchStatementsBatch(peerTokens, fetchParamsNoDismiss),
    ]);
    for (const [token, statements] of Object.entries(ownResults)) {
      if (!Array.isArray(statements)) throw new Error(`Failed to fetch delegate ${token}: ${statements.error}`);
      bag[bagKey(NERDSTER_EXPORT_URL, token)] = statements;
    }
    for (const [token, statements] of Object.entries(peerResults)) {
      if (!Array.isArray(statements)) throw new Error(`Failed to fetch delegate ${token}: ${statements.error}`);
      bag[bagKey(NERDSTER_EXPORT_URL, token, [DISMISS_TYPE])] = statements;
    }

    res.json(bag);
  } catch (e) {
    console.error('handleSeedNerdster error:', e);
    res.status(500).send('Internal error');
  }
}

module.exports = { handleSeedNerdster };
