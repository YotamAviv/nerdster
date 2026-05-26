const ONEOFUS_EXPORT_URL = process.env.FUNCTIONS_EMULATOR === 'true'
  ? 'http://127.0.0.1:5002/one-of-us-net/us-central1/export'
  : 'https://export.one-of-us.net';

async function _fetchSpec(tokens, extraParams = '', exportUrl = ONEOFUS_EXPORT_URL) {
  const results = {};
  if (tokens.length === 0) return results;

  const spec = JSON.stringify(tokens.map(t => ({ [t]: null })));
  const url = `${exportUrl}?spec=${encodeURIComponent(spec)}${extraParams}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`oneofus export failed: ${res.status}`);

  const text = await res.text();
  for (const line of text.trim().split('\n')) {
    if (!line) continue;
    const obj = JSON.parse(line);
    for (const [token, statements] of Object.entries(obj)) {
      results[token] = Array.isArray(statements) ? statements : [];
    }
  }
  for (const t of tokens) {
    if (!results[t]) results[t] = [];
  }
  return results;
}

const oneofusSource = {
  async fetch(fetchMap) {
    return _fetchSpec(Object.keys(fetchMap));
  },

  // Like fetch but each statement includes an `id` field (the statement token).
  // Used to resolve revokeAt tokens to timestamps.
  async fetchWithIds(fetchMap) {
    return _fetchSpec(Object.keys(fetchMap), '&includeId=true');
  },
};

function makeOneofusSource(exportUrl) {
  return {
    async fetch(fetchMap) {
      return _fetchSpec(Object.keys(fetchMap), '', exportUrl);
    },
  };
}

// Maps production export URLs to emulator equivalents when running locally.
const _emulatorRedirects = new Map([
  ['https://export.one-of-us.net', 'http://127.0.0.1:5002/one-of-us-net/us-central1/export'],
  ['https://export.karennet.net',  'http://127.0.0.1:5004/karennet/us-central1/export'],
]);

function federatedSourceFor(url) {
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    url = _emulatorRedirects.get(url) ?? url;
  }
  return makeOneofusSource(url);
}

module.exports = { oneofusSource, makeOneofusSource, federatedSourceFor };
