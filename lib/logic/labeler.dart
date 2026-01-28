import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:oneofus_common/jsonish.dart';

/// A utility to resolve monikers for keys in a [TrustGraph] using a greedy,
/// distance-authoritative approach.
///
/// ### Key Concepts:
/// - **Key (Token)**: A single cryptographic public key.
/// - **Identity**: A logical entity (a person) that can own multiple keys over time.
/// - **Equivalence Set**: The set of all keys (current and historical) that belong
///   to the same identity, linked together by `replace` statements.
/// - **Canonical Key**: The "active" or "latest" key for an identity. In the
///   [TrustGraph], this is the key that `resolveIdentity(token)` returns.
///
/// ### Labeling Strategy:
/// 1. **Identity Naming**: A unique "base name" (e.g., "Bob") is assigned to the
///    entire identity based on the most authoritative moniker discovered in the graph.
///    If multiple distinct identities share the same name (e.g., two people named "Mom"),
///    a numeric suffix is appended to ensure uniqueness (e.g., "Mom", "Mom (2)").
/// 2. **Key Naming**:
///    - The **Canonical Key** receives the base name ("Bob").
///    - **Historical Keys** (old keys in the equivalence set) receive the base name
///      with prime notation (e.g., "Bob'", "Bob''") to indicate their status.
class Labeler {
  final TrustGraph graph;
  final DelegateResolver? delegateResolver;
  final IdentityKey? meIdentity;

  // Maps IdentityKeys (canonical or historical) to their display name
  final Map<IdentityKey, String> _identityToName = {};

  // Maps Canonical IdentityKeys to all proposed names (for debugging/details)
  final Map<IdentityKey, Set<String>> _identityToAllNames = {};

  final Set<String> _usedNames = {};

  Labeler(this.graph, {this.delegateResolver, this.meIdentity}) {
    _computeLabels();
  }

  void _computeLabels() {
    // 1. Pre-index incoming trust statements by the subject's identity.
    // This allows us to quickly find all monikers proposed for a person.
    final Map<IdentityKey, List<TrustStatement>> incomingByIdentity = {};
    for (final IdentityKey issuer in graph.edges.keys) {
      for (final TrustStatement statement in graph.edges[issuer]!) {
        // We need an IdentityKey for the subject.
        // Assuming statement.subjectToken works here, resolve it.
        final IdentityKey subjectIdentity =
            graph.resolveIdentity(IdentityKey(statement.subjectToken));
        incomingByIdentity.putIfAbsent(subjectIdentity, () => []).add(statement);

        if (statement.moniker != null) {
          _identityToAllNames.putIfAbsent(subjectIdentity, () => {}).add(statement.moniker!);
        }
      }
    }

    // 2. Assign names to identities and tokens in discovery order (BFS).
    // This ensures that names are assigned based on the shortest path from the pov.
    for (final IdentityKey token in graph.orderedKeys) {
      if (_identityToName.containsKey(token)) continue;

      final IdentityKey identity = graph.resolveIdentity(token);

      String baseName;

      if (_identityToName.containsKey(identity)) {
        // This identity already has a base name assigned (e.g., from a previous key).
        baseName = _identityToName[identity]!;
      } else {
        // Determine the best base name for this identity from the context of its issuers.
        final List<TrustStatement> statements = incomingByIdentity[identity] ?? [];

        // Sort statements by issuer distance to prioritize monikers from closer (more trusted) peers.
        statements.sort((a, b) {
          // distances key is IdentityKey
          final int distA = graph.distances[IdentityKey(a.iToken)] ?? 999;
          final int distB = graph.distances[IdentityKey(b.iToken)] ?? 999;
          return distA.compareTo(distB);
        });

        String? bestMoniker;
        for (final TrustStatement s in statements) {
          if (s.moniker != null) {
            bestMoniker = s.moniker;
            break;
          }
        }

        // Fallback for the pov identity if no one has vouched for it yet.
        if (bestMoniker == null) {
          if (token == graph.pov) {
            if (meIdentity != null &&
                graph.resolveIdentity(token) == graph.resolveIdentity(meIdentity!)) {
              bestMoniker = "Me";
            } else {
              // Use their moniker from Jsonish or the token itself
              final jsonish = Jsonish.find(token.value);
              bestMoniker = jsonish?['moniker'] ??
                  (token.value.length > 8 ? token.value.substring(0, 8) : token.value);
            }
          } else {
            // Skip tokens that have no moniker and aren't the pov.
            continue;
          }
        }

        baseName = _makeUnique(bestMoniker!, isOld: false);
        _identityToName[identity] = baseName;
        _usedNames.add(baseName);
      }

      // 3. Name the specific token.
      // If this is an old/replaced key, append prime notation (e.g., Bob').
      if (token != identity) {
        final label = _makeUnique(baseName, isOld: true);
        _identityToName[token] = label;
        _usedNames.add(label);
      }
    }
  }

  /// Ensures a name is unique within the current labeler context.
  ///
  /// If [isOld] is true, it appends prime notation (e.g., Bob') to indicate
  /// a replaced or historical key.
  /// If [isOld] is false, it handles name collisions by appending a numeric
  /// suffix (e.g., Bob (2)).
  String _makeUnique(String name, {bool isOld = false}) {
    if (!isOld) {
      if (!_usedNames.contains(name)) return name;
      for (int i = 2;; i++) {
        final altName = '$name ($i)';
        if (!_usedNames.contains(altName)) return altName;
      }
    } else {
      // For historical keys, we append primes to the base name.
      String candidate = name;
      while (true) {
        candidate = "$candidate'";
        if (!_usedNames.contains(candidate)) return candidate;
      }
    }
  }

  /// Returns the best human-readable label for an identity key.
  String getIdentityLabel(IdentityKey key) {
    if (_identityToName.containsKey(key)) {
      return _identityToName[key]!;
    }
    return key.value.length > 8 ? key.value.substring(0, 8) : key.value;
  }

  /// Returns the best human-readable label for a delegate key.
  String getDelegateLabel(DelegateKey key) {
    if (delegateResolver != null) {
      final IdentityKey? identity = delegateResolver!.getIdentityForDelegate(key);
      if (identity != null) {
        final String identityLabel = getIdentityLabel(identity);
        final String? domain = delegateResolver!.getDomainForDelegate(key);

        // Handle multiple delegates for the same identity and domain
        final List<DelegateKey> allDelegates = delegateResolver!.getDelegatesForIdentity(identity);
        final List<DelegateKey> domainDelegates = allDelegates
            .where((DelegateKey d) => delegateResolver!.getDomainForDelegate(d) == domain)
            .toList();

        final int index = domainDelegates.indexOf(key);
        if (index > 0) {
          return "$identityLabel@$domain (${index + 1})";
        }
        return "$identityLabel@$domain";
      }
    }
    return key.value.length > 8 ? key.value.substring(0, 8) : key.value;
  }

  /// Returns the best human-readable label for a token (deprecated untyped wrapper).
  ///
  /// If no moniker was discovered, returns a truncated version of the token.
  String getLabel(String token) {
    // Try as identity first
    final identityKey = IdentityKey(token);
    if (_identityToName.containsKey(identityKey)) {
      return getIdentityLabel(identityKey);
    }

    // Try as delegate
    final delegateKey = DelegateKey(token);
    if (delegateResolver != null && delegateResolver!.getIdentityForDelegate(delegateKey) != null) {
      return getDelegateLabel(delegateKey);
    }

    return token.length > 8 ? token.substring(0, 8) : token;
  }

  /// Returns the canonical identity for a given token (key or delegate).
  IdentityKey getIdentityForToken(IdentityKey token) {
    if (delegateResolver != null) {
      final identity = delegateResolver!.getIdentityForDelegate(DelegateKey(token.value));
      if (identity != null) return identity;
    }
    return graph.resolveIdentity(token);
  }

  /// Returns all monikers associated with the identity of this token.
  List<String> getAllLabels(IdentityKey token) {
    final identity = graph.resolveIdentity(token);
    return _identityToAllNames[identity]?.toList() ?? [];
  }

  /// Returns true if the token has been assigned a human-readable label.
  bool hasLabel(String token) {
    if (_identityToName.containsKey(IdentityKey(token))) return true;
    if (delegateResolver != null &&
        delegateResolver!.getIdentityForDelegate(DelegateKey(token)) != null) return true;
    return false;
  }

  /// Returns all shortest paths from the pov to [token] as human-readable strings.
  List<String> getLabeledPaths(IdentityKey token) {
    final paths = graph.getPathsTo(token);
    return paths.map((path) => path.map((t) => getIdentityLabel(t)).join(' -> ')).toList();
  }
}
