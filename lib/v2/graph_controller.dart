import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

enum GraphViewMode {
  identity, // Pure Identity Network
  follow,   // Pure Follow Network for current context
}

class GraphEdgeData {
  final String fromIdentity;
  final String toIdentity;
  final List<dynamic> statements; // TrustStatement or ContentStatement
  final bool isIdentity;
  final bool isFollow;
  final bool isConflict;
  final bool isNonCanonical;

  GraphEdgeData({
    required this.fromIdentity,
    required this.toIdentity,
    this.statements = const [],
    this.isIdentity = false,
    this.isFollow = false,
    this.isConflict = false,
    this.isNonCanonical = false,
  });
}

class GraphData {
  final List<String> nodes; // Identity tokens
  final List<GraphEdgeData> edges;
  final String root;

  GraphData({
    required this.nodes,
    required this.edges,
    required this.root,
  });
}

class GraphController {
  final V2FeedModel feedModel;
  GraphViewMode mode = GraphViewMode.follow;
  String? focusedIdentity;
  
  GraphController(this.feedModel);

  String get povIdentity => feedModel.povToken;

  GraphData buildGraphData() {
    final Set<String> nodes = {};
    final Set<GraphEdgeData> edges = {};
    final String root = feedModel.labeler.getIdentityForToken(povIdentity);

    // If no focus, the graph is empty
    if (focusedIdentity == null) {
      return GraphData(
        nodes: [],
        edges: [],
        root: root,
      );
    }

    final List<GraphEdgeData> allEdges = [];
    if (mode == GraphViewMode.identity) {
      _addIdentityEdges(nodes, allEdges);
    } else if (mode == GraphViewMode.follow) {
      _addFollowEdges(nodes, allEdges);
    }

    final String target = feedModel.labeler.getIdentityForToken(focusedIdentity!);

    // Reset nodes and edges to only what's needed for the paths
    nodes.clear();
    nodes.add(root);
    nodes.add(target);

    if (mode == GraphViewMode.identity) {
      final paths = feedModel.trustGraph.paths[target];
      if (paths != null) {
        for (final path in paths) {
          _addPathToGraph(path, allEdges, nodes, edges);
        }
      }
    } else {
      final path = feedModel.followNetwork.paths[target];
      if (path != null) {
        _addPathToGraph(path, allEdges, nodes, edges);
      }
    }

    // Phase 2: Add Cross-Path Edges and Conflicts
    // Add any edge from allEdges where both start and end nodes are in the graph
    for (final edge in allEdges) {
      if (nodes.contains(edge.fromIdentity) && nodes.contains(edge.toIdentity)) {
        edges.add(edge);
      }
    }

    // Add Conflicts
    _addConflictEdges(nodes, edges);

    // Ensure root is first for algorithms that pick the first node as root
    final orderedNodes = [root, ...nodes.where((n) => n != root)];

    return GraphData(
      nodes: orderedNodes,
      edges: edges.toList(),
      root: root,
    );
  }

  void _addPathToGraph(List<String> path, List<GraphEdgeData> allEdges, Set<String> nodes, Set<GraphEdgeData> edges) {
    for (int i = 0; i < path.length - 1; i++) {
      final from = path[i];
      final to = path[i + 1];
      
      final fromId = feedModel.labeler.getIdentityForToken(from);
      final toId = feedModel.labeler.getIdentityForToken(to);
      
      if (fromId == toId) continue; // Skip self-loops (replacements)

      nodes.add(fromId);
      nodes.add(toId);
      
      // Find the edge in allEdges
      try {
        final edge = allEdges.firstWhere((e) => e.fromIdentity == fromId && e.toIdentity == toId);
        edges.add(edge);
      } catch (e) {
        // This shouldn't happen if logic and UI are in sync
      }
    }
  }

  Set<GraphEdgeData> getPathToFocused(GraphData data) {
    if (focusedIdentity == null) return {};
    final Set<String> keepNodes = {};
    final Set<GraphEdgeData> pathEdges = {};
    final String target = feedModel.labeler.getIdentityForToken(focusedIdentity!);
    
    if (mode == GraphViewMode.identity) {
      final paths = feedModel.trustGraph.paths[target];
      if (paths != null) {
        for (final path in paths) {
          _addPathToGraph(path, data.edges, keepNodes, pathEdges);
        }
      }
    } else {
      final path = feedModel.followNetwork.paths[target];
      if (path != null) {
        _addPathToGraph(path, data.edges, keepNodes, pathEdges);
      }
    }
    return pathEdges;
  }

  void _addIdentityEdges(Set<String> nodes, List<GraphEdgeData> edges) {
    final tg = feedModel.trustGraph;
    for (final token in tg.getEquivalenceGroups().keys) {
      nodes.add(feedModel.labeler.getIdentityForToken(token));
    }

    for (final issuer in tg.edges.keys) {
      final issuerIdentity = feedModel.labeler.getIdentityForToken(issuer);
      for (final s in tg.edges[issuer]!) {
        if (s.verb == TrustVerb.trust || s.verb == TrustVerb.block || s.verb == TrustVerb.replace) {
          final subjectIdentity = feedModel.labeler.getIdentityForToken(s.subjectToken);
          final isNonCanonical = tg.replacements.containsKey(s.subjectToken);
          
          // Check if this statement is a conflict
          final isConflict = tg.notifications.any((n) => n.isConflict && n.relatedStatement.token == s.token);

          _mergeOrAddEdge(edges, GraphEdgeData(
            fromIdentity: issuerIdentity,
            toIdentity: subjectIdentity,
            statements: [s],
            isIdentity: true,
            isConflict: isConflict,
            isNonCanonical: isNonCanonical,
          ));
        }
      }
    }
  }

  void _addFollowEdges(Set<String> nodes, List<GraphEdgeData> edges) {
    final fn = feedModel.followNetwork;
    for (final identity in fn.identities) {
      nodes.add(feedModel.labeler.getIdentityForToken(identity));
    }

    for (final issuerIdentity in fn.edges.keys) {
      final resolvedIssuer = feedModel.labeler.getIdentityForToken(issuerIdentity);
      for (final s in fn.edges[issuerIdentity]!) {
        final subjectIdentity = feedModel.labeler.getIdentityForToken(s.subjectToken);
        
        // Check if this statement is a conflict
        final isConflict = fn.notifications.any((n) => n.isConflict && n.relatedStatement.token == s.token);

        _mergeOrAddEdge(edges, GraphEdgeData(
          fromIdentity: resolvedIssuer,
          toIdentity: subjectIdentity,
          statements: [s],
          isFollow: true,
          isConflict: isConflict,
        ));
      }
    }

    // Special case: In <nerdster> context, the follow network also includes WoT trusts.
    if (fn.fcontext == '<nerdster>') {
      final tg = feedModel.trustGraph;
      for (final issuer in tg.edges.keys) {
        final issuerIdentity = feedModel.labeler.getIdentityForToken(issuer);
        // Only include if the issuer is actually in the follow network
        if (!fn.identities.contains(issuerIdentity)) continue;

        for (final s in tg.edges[issuer]!) {
          if (s.verb != TrustVerb.trust) continue;
          final subjectIdentity = feedModel.labeler.getIdentityForToken(s.subjectToken);
          // Only include if the subject is also in the follow network
          if (!fn.identities.contains(subjectIdentity)) continue;

          _mergeOrAddEdge(edges, GraphEdgeData(
            fromIdentity: issuerIdentity,
            toIdentity: subjectIdentity,
            statements: [s],
            isIdentity: true,
          ));
        }
      }
    }
  }

  void _mergeOrAddEdge(List<GraphEdgeData> edges, GraphEdgeData newEdge) {
    for (int i = 0; i < edges.length; i++) {
      final e = edges[i];
      if (e.fromIdentity == newEdge.fromIdentity && e.toIdentity == newEdge.toIdentity) {
        edges[i] = GraphEdgeData(
          fromIdentity: e.fromIdentity,
          toIdentity: e.toIdentity,
          statements: [...e.statements, ...newEdge.statements],
          isIdentity: e.isIdentity || newEdge.isIdentity,
          isFollow: e.isFollow || newEdge.isFollow,
          isConflict: e.isConflict || newEdge.isConflict,
          isNonCanonical: e.isNonCanonical || newEdge.isNonCanonical,
        );
        return;
      }
    }
    edges.add(newEdge);
  }

  void _addConflictEdges(Set<String> nodes, Set<GraphEdgeData> edges) {
    final List<TrustNotification> conflicts = [...feedModel.trustGraph.conflicts];

    if (mode == GraphViewMode.follow) {
      conflicts.addAll(feedModel.followNetwork.notifications.where((n) => n.isConflict));
    }

    for (final conflict in conflicts) {
      final fromId = feedModel.labeler.getIdentityForToken(conflict.issuer);
      final toId = feedModel.labeler.getIdentityForToken(conflict.subject);

      if (nodes.contains(fromId) && nodes.contains(toId)) {
        GraphEdgeData? match;
        for (final e in edges) {
          if (e.fromIdentity == fromId && e.toIdentity == toId) {
            match = e;
            break;
          }
        }

        if (match != null) {
          edges.remove(match);
          edges.add(GraphEdgeData(
            fromIdentity: fromId,
            toIdentity: toId,
            statements: [...match.statements, conflict],
            isIdentity: match.isIdentity,
            isFollow: match.isFollow,
            isConflict: true,
            isNonCanonical: match.isNonCanonical,
          ));
        } else {
          edges.add(GraphEdgeData(
            fromIdentity: fromId,
            toIdentity: toId,
            statements: [conflict],
            isConflict: true,
          ));
        }
      }
    }
  }
}
