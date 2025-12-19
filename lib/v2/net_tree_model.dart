import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

class V2NetTreeModel extends NetTreeModel {
  final TrustGraph graph;
  final TrustStatement? stmt;

  V2NetTreeModel(
    List<NetTreeModel> path,
    this.graph, {
    String? token,
    this.stmt,
  }) : super(path, token: token);

  @override
  Iterable<NetTreeModel> get children {
    if (token == null) return [];

    final edges = graph.edges[token] ?? [];
    
    // Filter edges to avoid cycles and respect graph structure
    // In V1, we filter if token is already in path.
    final currentPathTokens = path.map((n) => n.token).toSet();
    currentPathTokens.add(token); // Add self

    return edges.where((e) {
      // Only follow 'trust' and 'delegate' for tree expansion?
      // V1 follows trust/delegate.
      // What about block/replace? They are usually leaf nodes or info nodes.
      // Let's include them for now, but maybe mark them.
      return !currentPathTokens.contains(e.subjectToken);
    }).map((e) {
      return V2NetTreeModel(
        [...path, this],
        graph,
        token: e.subjectToken,
        stmt: e,
      );
    });
  }

  // --- Overrides to handle missing 'statement' ---

  @override
  String get moniker {
    if (stmt != null) {
       // If this node represents a target of a statement
       return keyLabels.labelKey(stmt!.subjectToken) ?? kUnknown;
    } else {
       // Root node
       return keyLabels.labelKey(token!) ?? kUnknown;
    }
  }

  @override
  String get displayStatementAtTime => stmt != null ? '@${formatUiDatetime(stmt!.time)}' : '';

  @override
  String get displayVerbPastTense {
    if (stmt == null) return '';
    // Simple mapping for now
    switch (stmt!.verb) {
      case TrustVerb.trust: return 'trusted';
      case TrustVerb.block: return 'blocked';
      case TrustVerb.replace: return 'replaced';
      case TrustVerb.delegate: return 'delegated';
      default: return stmt!.verb.name;
    }
  }

  @override
  bool get isCanonicalStatement => true; // Assume V2 handles canonicalization

  @override
  bool get trustsNonCanonical => false; // Simplified

  @override
  bool get rejected => false; // Simplified

  @override
  bool get canonical => true; // Simplified

  @override
  String? get revokeAt => stmt?.revokeAt;

  @override
  DateTime? get revokeAtTime => null; // TODO: Resolve if needed
}
