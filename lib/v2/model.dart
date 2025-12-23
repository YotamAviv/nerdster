import 'package:nerdster/oneofus/trust_statement.dart';

/// Represents a notification or conflict discovered during graph construction.
class TrustNotification {
  final String subject;
  final String reason;
  final List<String> relatedStatements;
  final bool isConflict;

  TrustNotification({
    required this.subject,
    required this.reason,
    this.relatedStatements = const [],
    this.isConflict = false,
  });

  @override
  String toString() => '${isConflict ? "Conflict" : "Notification"}($subject): $reason';
}

/// The immutable result of the Trust Algorithm.
class TrustGraph {
  final String root;
  final Map<String, int> distances; // Token -> Distance
  final Map<String, String> replacements; // OldToken -> NewToken
  final Map<String, String> revokeAtConstraints; // Token -> RevokeAtToken (Time constraint)
  final Set<String> blocked; // Tokens blocked by the graph
  final List<TrustNotification> notifications; // Structured notifications and conflicts
  final Map<String, List<TrustStatement>> edges; // Adjacency list: Issuer -> List<TrustStatement> (Valid statements)

  TrustGraph({
    required this.root,
    this.distances = const {},
    this.replacements = const {},
    this.revokeAtConstraints = const {},
    this.blocked = const {},
    this.notifications = const [],
    this.edges = const {},
  });

  bool isTrusted(String token) => distances.containsKey(token);
  
  List<TrustNotification> get conflicts => notifications.where((n) => n.isConflict).toList();

  /// Returns the active identity token for a given key.
  /// If the key is replaced, returns the replacement (recursively).
  String resolveIdentity(String token) {
    if (replacements.containsKey(token)) {
      return resolveIdentity(replacements[token]!);
    }
    return token;
  }
}

