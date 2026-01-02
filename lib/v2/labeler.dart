import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/delegates.dart';

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
class V2Labeler {
  final TrustGraph graph;
  final DelegateResolver? delegateResolver;
  final String? meIdentityToken;
  final Map<String, String> _tokenToName = {};
  final Map<String, Set<String>> _tokenToAllNames = {};
  final Set<String> _usedNames = {};

  V2Labeler(this.graph, {this.delegateResolver, this.meIdentityToken}) {
    _computeLabels();
  }

  void _computeLabels() {
    // 1. Pre-index incoming trust statements by the subject's identity.
    // This allows us to quickly find all monikers proposed for a person.
    final Map<String, List<TrustStatement>> incomingByIdentity = {};
    for (final issuer in graph.edges.keys) {
      for (final statement in graph.edges[issuer]!) {
        final subjectIdentity = graph.resolveIdentity(statement.subjectToken);
        incomingByIdentity
            .putIfAbsent(subjectIdentity, () => [])
            .add(statement);

        if (statement.moniker != null) {
          _tokenToAllNames
              .putIfAbsent(subjectIdentity, () => {})
              .add(statement.moniker!);
        }
      }
    }

    // 2. Assign names to identities and tokens in discovery order (BFS).
    // This ensures that names are assigned based on the shortest path from the pov.
    for (final token in graph.orderedKeys) {
      if (_tokenToName.containsKey(token)) continue;

      final identity = graph.resolveIdentity(token);
      
      String baseName;
      
      if (_tokenToName.containsKey(identity)) {
        // This identity already has a base name assigned (e.g., from a previous key).
        baseName = _tokenToName[identity]!;
      } else {
        // Determine the best base name for this identity from the context of its issuers.
        final statements = incomingByIdentity[identity] ?? [];
        
        // Sort statements by issuer distance to prioritize monikers from closer (more trusted) peers.
        statements.sort((a, b) {
          final distA = graph.distances[a.iToken] ?? 999;
          final distB = graph.distances[b.iToken] ?? 999;
          return distA.compareTo(distB);
        });

        String? bestMoniker;
        for (final s in statements) {
          if (s.moniker != null) {
            bestMoniker = s.moniker;
            break;
          }
        }
        
        // Fallback for the pov identity if no one has vouched for it yet.
        if (bestMoniker == null) {
          if (token == graph.pov) {
            if (meIdentityToken != null &&
                graph.resolveIdentity(token) ==
                    graph.resolveIdentity(meIdentityToken!)) {
              bestMoniker = "Me";
            } else {
              // Use their moniker from Jsonish or the token itself
              final jsonish = Jsonish.find(token);
              bestMoniker = jsonish?['moniker'] ??
                  (token.length > 8 ? token.substring(0, 8) : token);
            }
          } else {
            // Skip tokens that have no moniker and aren't the pov.
            continue;
          }
        }

        baseName = _makeUnique(bestMoniker!, isOld: false);
        _tokenToName[identity] = baseName;
        _usedNames.add(baseName);
      }
      
      // 3. Name the specific token.
      // If this is an old/replaced key, append prime notation (e.g., Bob').
      if (token != identity) {
        final label = _makeUnique(baseName, isOld: true);
        _tokenToName[token] = label;
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

  /// Returns the best human-readable label for a token.
  ///
  /// If no moniker was discovered, returns a truncated version of the token.
  String getLabel(String token) {
    if (_tokenToName.containsKey(token)) {
      return _tokenToName[token]!;
    }

    // Check if it's a delegate key
    if (delegateResolver != null) {
      final identity = delegateResolver!.getIdentityForDelegate(token);
      if (identity != null) {
        final identityLabel = getLabel(identity);
        final domain = delegateResolver!.getDomainForDelegate(token);
        return "$identityLabel@$domain";
      }
    }

    return token.length > 8 ? token.substring(0, 8) : token;
  }

  /// Returns the canonical identity for a given token (key or delegate).
  String getIdentityForToken(String token) {
    if (delegateResolver != null) {
      final identity = delegateResolver!.getIdentityForDelegate(token);
      if (identity != null) return identity;
    }
    return graph.resolveIdentity(token);
  }

  /// Returns all monikers associated with the identity of this token.
  List<String> getAllLabels(String token) {
    final identity = graph.resolveIdentity(token);
    return _tokenToAllNames[identity]?.toList() ?? [];
  }

  /// Returns true if the token has been assigned a human-readable label.
  bool hasLabel(String token) {
    return _tokenToName.containsKey(token);
  }

  /// Returns all shortest paths from the pov to [token] as human-readable strings.
  List<String> getLabeledPaths(String token) {
    final paths = graph.getPathsTo(token);
    return paths
        .map((path) => path.map((t) => getLabel(t)).join(' -> '))
        .toList();
  }
}
