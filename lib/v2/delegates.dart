import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

/// Maps identities keys to delegate keys and vice versa.
/// This resolver is lazy: it only resolves delegates for identities when requested.
class DelegateResolver {
  final TrustGraph graph;
  final Map<String, String> _delegateToIdentity = {};
  final Map<String, String> _delegateToDomain = {};
  final Map<String, List<String>> _identityToDelegates = {};
  final Set<String> _resolvedIdentities = {};

  DelegateResolver(this.graph);

  /// Ensures delegates are resolved for the given canonical identity.
  /// Note: In this lazy implementation, the first identity to request a delegate key wins it.
  /// This follows "follow proximity" if called during follow network construction.
  void resolveForIdentity(String identity) {
    if (_resolvedIdentities.contains(identity)) return;

    final List<String> keys = graph.getEquivalenceGroup(identity);
    for (final String key in keys) {
      final List<TrustStatement> statements = graph.edges[key] ?? [];
      for (final TrustStatement s in statements.where((s) => s.verb == TrustVerb.delegate)) {
        final String delegateKey = s.subjectToken;
        
        // A key cannot be a delegate if it is already a trusted identity key
        if (graph.isTrusted(delegateKey)) continue;
        
        // A key cannot be a delegate if it is blocked
        if (graph.blocked.contains(delegateKey)) continue;

        // First one to claim it wins.
        if (!_delegateToIdentity.containsKey(delegateKey)) {
          _delegateToIdentity[delegateKey] = identity;
          _delegateToDomain[delegateKey] = s.domain ?? 'unknown';
          _identityToDelegates.putIfAbsent(identity, () => []).add(delegateKey);
        }
      }
    }
    _resolvedIdentities.add(identity);
  }

  /// Returns the canonical identity for a given delegate key.
  /// Returns null if the token is not a recognized delegate.
  String? getIdentityForDelegate(String token) {
    return _delegateToIdentity[token];
  }

  /// Returns the domain for a given delegate key.
  String? getDomainForDelegate(String token) {
    return _delegateToDomain[token];
  }

  /// Returns all delegate keys authorized by the given canonical identity.
  List<String> getDelegatesForIdentity(String canonical) {
    resolveForIdentity(canonical);
    return _identityToDelegates[canonical] ?? [];
  }
}
