import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';

class ContentPipeline {
  final StatementSource<ContentStatement> identitySource;
  final StatementSource<ContentStatement> appSource;

  ContentPipeline({required this.identitySource, required this.appSource});

  /// Fetches content based on the TrustGraph and DelegateResolver.
  /// Returns a map of Token -> List of ContentStatements.
  Future<Map<String, List<ContentStatement>>> fetchContentMap(
    TrustGraph graph,
    DelegateResolver delegateResolver, {
    List<String>? additionalIdentityKeys,
    List<String>? additionalAppKeys,
  }) async {
    // 1. Identify Trusted Users
    // We only care about users who are trusted (distance < maxDegrees, which is implicit in the graph)
    // and NOT blocked.
    // ORDERING: Must be ordered by Trust Distance (ascending).
    final List<String> trustedIdentities =
        graph.getEquivalenceGroups().keys.toList();

    trustedIdentities.sort((a, b) {
      final int distA = graph.distances[a]!;
      final int distB = graph.distances[b]!;
      if (distA != distB) return distA.compareTo(distB);
      return a.compareTo(b); // Stable tie-break
    });

    // 2. Map Identities to all their authorized keys (Identity Keys + Delegate Keys)
    // We split these because they are hosted on different domains.
    final Map<String, String?> identityFetchMap = {};
    final Map<String, String?> appFetchMap = {};

    for (final String identity in trustedIdentities) {
      // Identity Keys -> Hosted on one-of-us.net
      final List<String> identityKeys = graph.getEquivalenceGroup(identity);
      for (final String key in identityKeys) {
        identityFetchMap[key] = graph.replacementConstraints[key];
      }

      // Delegate Keys -> Hosted on nerdster.org
      final List<String> delegateKeys =
          delegateResolver.getDelegatesForIdentity(identity);
      for (final String key in delegateKeys) {
        appFetchMap[key] = delegateResolver.getConstraintForDelegate(key);
      }
    }

    // Add additional keys (e.g. "me" and my delegate)
    if (additionalIdentityKeys != null) {
      for (final key in additionalIdentityKeys) {
        identityFetchMap[key] = null;
      }
    }
    if (additionalAppKeys != null) {
      for (final key in additionalAppKeys) {
        appFetchMap[key] = null;
      }
    }

    // 3. Fetch Content from both sources in parallel
    final List<Map<String, List<ContentStatement>>> results =
        await Future.wait([
      identitySource.fetch(identityFetchMap),
      appSource.fetch(appFetchMap),
    ]);

    final Map<String, List<ContentStatement>> identityMap = results[0];
    final Map<String, List<ContentStatement>> appMap = results[1];

    final Map<String, List<ContentStatement>> combinedMap = {};
    combinedMap.addAll(identityMap);
    combinedMap.addAll(appMap);

    // 4. Verify Content
    // The source should only return content for the requested keys.
    for (final String key in combinedMap.keys) {
      final bool isTrustedIdentity = graph.isTrusted(key);
      final bool isAuthorizedDelegate =
          delegateResolver.getIdentityForDelegate(key) != null;
      final bool isAdditional = (additionalIdentityKeys?.contains(key) ?? false) ||
          (additionalAppKeys?.contains(key) ?? false);

      if (!isTrustedIdentity && !isAuthorizedDelegate && !isAdditional) {
        throw 'Pipeline Error: Source returned content from unauthorized key: $key';
      }

      final String? identity = isTrustedIdentity
          ? graph.resolveIdentity(key)
          : delegateResolver.getIdentityForDelegate(key);

      if (identity != null && graph.blocked.contains(identity)) {
        throw 'Pipeline Error: Source returned content from blocked identity: $identity';
      }
    }

    return combinedMap;
  }
}
