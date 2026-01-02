import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';

class ContentPipeline {
  final StatementSource<ContentStatement> contentSource;

  ContentPipeline({required this.contentSource});

  /// Fetches content based on the TrustGraph and DelegateResolver.
  /// Returns a map of Token -> List of ContentStatements.
  Future<Map<String, List<ContentStatement>>> fetchContentMap(
    TrustGraph graph,
    DelegateResolver delegateResolver, {
    List<String>? additionalKeys,
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
    final Map<String, String?> fetchMap = {};

    for (final String identity in trustedIdentities) {
      // Identity Keys
      final List<String> identityKeys = graph.getEquivalenceGroup(identity);
      for (final String key in identityKeys) {
        fetchMap[key] = graph.replacementConstraints[key];
      }

      // Delegate Keys
      final List<String> delegateKeys =
          delegateResolver.getDelegatesForIdentity(identity);
      for (final String key in delegateKeys) {
        fetchMap[key] = delegateResolver.getConstraintForDelegate(key);
      }
    }

    // Add additional keys (e.g. "me" and my delegate)
    if (additionalKeys != null) {
      for (final key in additionalKeys) {
        fetchMap[key] = null;
      }
    }

    // 3. Fetch Content
    final Map<String, List<ContentStatement>> contentMap =
        await contentSource.fetch(fetchMap);

    // 4. Verify Content
    // The source should only return content for the requested keys.
    for (final String key in contentMap.keys) {
      final bool isTrustedIdentity = graph.isTrusted(key);
      final bool isAuthorizedDelegate =
          delegateResolver.getIdentityForDelegate(key) != null;
      final bool isAdditional = additionalKeys?.contains(key) ?? false;

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
    
    return contentMap;
  }
}
