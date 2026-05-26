/**
 * trust_pipeline.js — JavaScript port of trust_pipeline.dart
 *
 * Orchestrates fetch + reduce cycles to build a trust graph.
 *
 * If sourceFor(url) is provided, keys discovered with a foreign endpoint
 * (via the 'with.endpoint' field in trust statements) are fetched from
 * the appropriate URL rather than the default source.
 */

const { reduceTrustGraph, defaultPathRequirement, kDefaultMaxDegrees } = require('./trust_logic');

class TrustPipeline {
  constructor(source, { maxDegrees = kDefaultMaxDegrees, pathRequirement, sourceFor } = {}) {
    this.source = source;
    this.maxDegrees = maxDegrees;
    this.pathRequirement = pathRequirement || defaultPathRequirement;
    this.sourceFor = sourceFor || null; // (url: string) => source — optional
  }

  async build(povToken, { fedRegistry = new Map(), oouCache } = {}) {
    if (!oouCache) throw new Error('TrustPipeline.build: oouCache is required');
    const visited = new Set();
    let frontier = new Set([povToken]);
    let graph = { pov: povToken, distances: new Map([[povToken, 0]]), equivalent2canonical: new Map() };

    for (let depth = 0; depth < this.maxDegrees; depth++) {
      if (frontier.size === 0) break;

      const keysToFetch = [...frontier].filter(k => !visited.has(k) && !graph.equivalent2canonical.has(k));
      if (keysToFetch.length === 0) break;

      let newStatementsMap;
      if (this.sourceFor) {
        newStatementsMap = {};
        const byUrl = new Map();
        for (const k of keysToFetch) {
          const url = fedRegistry.get(k) ?? null;
          if (!byUrl.has(url)) byUrl.set(url, []);
          byUrl.get(url).push(k);
        }
        for (const [url, keys] of byUrl) {
          const src = url ? this.sourceFor(url) : this.source;
          const fetched = await src.fetch(Object.fromEntries(keys.map(k => [k, null])));
          Object.assign(newStatementsMap, fetched);
        }
      } else {
        const fetchMap = Object.fromEntries(keysToFetch.map(k => [k, null]));
        newStatementsMap = await this.source.fetch(fetchMap);
      }

      for (const k of keysToFetch) visited.add(k);
      for (const [token, statements] of Object.entries(newStatementsMap)) {
        oouCache.set(token, statements);
      }

      graph = await reduceTrustGraph(povToken, oouCache, {
        pathRequirement: this.pathRequirement,
        maxDegrees: this.maxDegrees,
        fedRegistry,
      });

      frontier = new Set([...graph.distances.keys()].filter(k => !visited.has(k)));
    }

    return graph;
  }
}

module.exports = { TrustPipeline };
