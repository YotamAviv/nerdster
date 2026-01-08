import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

/// Maps identities keys to delegate keys and vice versa.
/// This resolver is lazy: it only resolves delegates for identities when requested.
class DelegateResolver {
  final TrustGraph graph;
  final Map<DelegateKey, IdentityKey> _delegateToIdentity = {};
  final Map<DelegateKey, String> _delegateToDomain = {};
  final Map<IdentityKey, List<DelegateKey>> _identityToDelegates = {};
  final Map<DelegateKey, String> _delegateConstraints = {}; // delegateKey -> revokeAtToken
  /// Tracks which identities have had their delegates resolved from the TrustGraph.
  /// Note that _identityToDelegates contains only those identities that actually have delegates.
  /// If an identity has no delegates, it will be in this set but not in _identityToDelegates.
  final Set<IdentityKey> _resolvedIdentities = {};

  DelegateResolver(this.graph);

  /// Ensures delegates are resolved for the given canonical identity.
  /// Note: In this lazy implementation, the first identity to request a delegate key wins it.
  /// This follows "follow proximity" if called during follow network construction.
  void resolveForIdentity(String identityStr) {
    final IdentityKey identity = IdentityKey(identityStr);
    if (_resolvedIdentities.contains(identity)) return;

    final List<String> keys = graph.getEquivalenceGroup(identity.value);
    List<TrustStatement> allStatements = [];
    for (final String key in keys) {
      final statements = graph.edges[key] ?? [];
      if (allStatements.isEmpty) {
        allStatements = statements;
      } else {
        allStatements = _mergeSorted(allStatements, statements);
      }
    }

    final Set<DelegateKey> decidedDelegates = {};

    for (final TrustStatement s in allStatements.where((s) => s.verb == TrustVerb.delegate)) {
      final DelegateKey delegateKey = DelegateKey(s.subjectToken);

      if (decidedDelegates.contains(delegateKey)) continue;
      decidedDelegates.add(delegateKey);

      // A delegate statement with a revokeAt timestamp is a revocation.
      if (s.revokeAt != null) {
        _delegateConstraints[delegateKey] = s.revokeAt!;
      }
      
      // A key cannot be a delegate if it is already a trusted identity key
      if (graph.isTrusted(delegateKey.value)) continue;
      
      // A key cannot be a delegate if it is blocked
      if (graph.blocked.contains(delegateKey.value)) continue;

      // First one to claim it wins.
      if (!_delegateToIdentity.containsKey(delegateKey)) {
        _delegateToIdentity[delegateKey] = identity;
        _delegateToDomain[delegateKey] = s.domain ?? 'unknown';
        _identityToDelegates.putIfAbsent(identity, () => []).add(delegateKey);
      } else if (_delegateToIdentity[delegateKey] != identity) {
        graph.notifications.add(TrustNotification(
          reason: "Delegate key $delegateKey already claimed by ${_delegateToIdentity[delegateKey]}",
          rejectedStatement: s,
          isConflict: true,
        ));
      }
    }
    _resolvedIdentities.add(identity);
  }

  List<TrustStatement> _mergeSorted(List<TrustStatement> a, List<TrustStatement> b) {
    final List<TrustStatement> result = [];
    int i = 0, j = 0;
    while (i < a.length && j < b.length) {
      if (a[i].time.isAfter(b[j].time)) {
        result.add(a[i++]);
      } else {
        result.add(b[j++]);
      }
    }
    while (i < a.length) {
      result.add(a[i++]);
    }
    while (j < b.length) {
      result.add(b[j++]);
    }
    return result;
  }

  /// Returns the canonical identity for a given delegate key.
  /// Returns null if the token is not a recognized delegate.
  IdentityKey? getIdentityForDelegate(DelegateKey token) {
    assert(!_identityToDelegates.containsKey(token));
    return _delegateToIdentity[token];
  }

  /// Returns the domain for a given delegate key.
  String? getDomainForDelegate(DelegateKey token) {
    assert(!_identityToDelegates.containsKey(token));
    return _delegateToDomain[token];
  }

  /// Returns the revocation constraint (revokeAt token) for a given delegate key.
  String? getConstraintForDelegate(DelegateKey token) {
    assert(!_identityToDelegates.containsKey(token));
    return _delegateConstraints[token];
  }

  /// Returns all delegate keys authorized by the given canonical identity.
  /// TODO: Cache the result or just make it earlier.
  List<DelegateKey> getDelegatesForIdentity(IdentityKey canonical) {
    assert(!_delegateToIdentity.containsKey(canonical));
    resolveForIdentity(canonical.value);
    return _identityToDelegates[canonical] ?? [];
  }
}
