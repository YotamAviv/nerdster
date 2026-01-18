import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/statement.dart';
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
  final List<TrustNotification> notifications = [];

  DelegateResolver(this.graph);

  /// Ensures delegates are resolved for the given canonical identity.
  /// Note: In this lazy implementation, the first identity to request a delegate key wins it.
  /// This follows "follow proximity" if called during follow network construction.
  void resolveForIdentity(IdentityKey identity) {
    if (_resolvedIdentities.contains(identity)) return;

    List<IdentityKey> keys = graph.getEquivalenceGroup(identity);

    // Fallback: If identity is not in the trust graph (no distance) but we have edges for it
    // (e.g. "Me" identity injected for local user), use the identity itself if it's canonical.
    if (keys.isEmpty &&
        graph.edges.containsKey(identity) &&
        graph.resolveIdentity(identity) == identity) {
      keys = [identity];
    }

    final Iterable<TrustStatement> allStatements =
        Merger.merge(keys.map((IdentityKey k) => graph.edges[k] ?? <TrustStatement>[]));
    Statement.validateOrderTypes(allStatements);
    final Set<DelegateKey> decidedDelegates = {};

    for (final TrustStatement s in allStatements.where((s) => s.verb == TrustVerb.delegate)) {
      final DelegateKey delegateKey = DelegateKey(s.subjectToken);

      if (decidedDelegates.contains(delegateKey)) continue;
      decidedDelegates.add(delegateKey);

      // A delegate statement with a revokeAt timestamp is a revocation.
      if (s.revokeAt != null) {
        _delegateConstraints[delegateKey] = s.revokeAt!;
      }

      // First one to claim it wins.
      if (!_delegateToIdentity.containsKey(delegateKey)) {
        _delegateToIdentity[delegateKey] = identity;
        _delegateToDomain[delegateKey] = s.domain ?? 'unknown';
        _identityToDelegates.putIfAbsent(identity, () => []).add(delegateKey);
      } else if (_delegateToIdentity[delegateKey] != identity) {
        notifications.add(TrustNotification(
          reason:
              "Delegate key ${delegateKey.value} already claimed by ${_delegateToIdentity[delegateKey]!.value}",
          rejectedStatement: s,
          isConflict: true,
        ));
      }
    }
    _resolvedIdentities.add(identity);
  }

  /// Returns the canonical identity for a given delegate key.
  /// Returns null if the token is not a recognized delegate.
  IdentityKey? getIdentityForDelegate(DelegateKey token) {
    return _delegateToIdentity[token];
  }

  /// Returns the domain for a given delegate key.
  String? getDomainForDelegate(DelegateKey token) {
    return _delegateToDomain[token];
  }

  /// Returns the revocation constraint (revokeAt token) for a given delegate key.
  String? getConstraintForDelegate(DelegateKey token) {
    return _delegateConstraints[token];
  }

  /// Returns all delegate keys authorized by the given canonical identity.
  /// This implementation is lazy: the first call for a specific identity triggers
  /// resolution from the [TrustGraph], and the result is cached for subsequent calls.
  List<DelegateKey> getDelegatesForIdentity(IdentityKey canonical) {
    resolveForIdentity(canonical);
    return _identityToDelegates[canonical] ?? [];
  }
}
