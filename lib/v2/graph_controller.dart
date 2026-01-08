import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/util.dart';

enum GraphViewMode {
  identity, // Pure Identity Network
  follow,   // Pure Follow Network for current context
}

class GraphEdgeData {
  final IdentityKey from;
  final IdentityKey to;
  final List<dynamic> statements; // TrustStatement or ContentStatement or TrustNotification
  final bool isIdentity;
  final bool isFollow;
  final bool isConflict;
  final bool isNonCanonical;

  GraphEdgeData({
    required this.from,
    required this.to,
    this.statements = const [],
    this.isIdentity = false,
    this.isFollow = false,
    this.isConflict = false,
    this.isNonCanonical = false,
  });
}

class GraphData {
  final List<IdentityKey> nodes;
  final List<GraphEdgeData> edges;
  final IdentityKey root;

  GraphData({
    required this.nodes,
    required this.edges,
    required this.root,
  });
}

class GraphController {
  final V2FeedModel feedModel;
  GraphViewMode mode = GraphViewMode.follow;
  IdentityKey? focusedIdentity;
  
  GraphController(this.feedModel);

  IdentityKey get povIdentity => feedModel.povToken;

  /// Resolves any token to its canonical Identity Key.
  /// This handles Identity Merge/Replacement (aliasing) via the TrustGraph.
  IdentityKey _resolve(IdentityKey token) {
    if (feedModel.trustGraph.isTrusted(token)) {
      return feedModel.trustGraph.resolveIdentity(token);
    }
    return token;
  }
  
  GraphData buildGraphData() {
    final Set<IdentityKey> nodes = {};
    final IdentityKey root = _resolve(povIdentity);

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

    final IdentityKey target = _resolve(focusedIdentity!);

    // Reset nodes and edges to only what's needed for the paths
    nodes.clear();
    nodes.add(root);
    nodes.add(target);

    final Set<GraphEdgeData> edges = {};

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
    for (final edge in allEdges) {
      if (nodes.contains(edge.from) && nodes.contains(edge.to)) {
        edges.add(edge);
      }
    }

    // Add Conflicts
    _addConflictEdges(nodes, edges);

    // Ensure root is first
    final orderedNodes = [root, ...nodes.where((n) => n != root)];

    return GraphData(
      nodes: orderedNodes,
      edges: edges.toList(),
      root: root,
    );
  }

  void _addPathToGraph(List<IdentityKey> path, List<GraphEdgeData> allEdges, Set<IdentityKey> nodes, Set<GraphEdgeData> edges) {
    for (int i = 0; i < path.length - 1; i++) {
      final fromId = _resolve(path[i]);
      final toId = _resolve(path[i + 1]);
      
      if (fromId == toId) continue;

      nodes.add(fromId);
      nodes.add(toId);
      
      try {
        final edge = allEdges.firstWhere((e) => e.from == fromId && e.to == toId);
        edges.add(edge);
      } catch (e) {
        // Edge missing
      }
    }
  }

  Set<GraphEdgeData> getPathToFocused(GraphData data) {
    if (focusedIdentity == null) return {};
    final Set<IdentityKey> keepNodes = {};
    final Set<GraphEdgeData> pathEdges = {};
    final IdentityKey target = _resolve(focusedIdentity!);
    
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

  void _addIdentityEdges(Set<IdentityKey> nodes, List<GraphEdgeData> edges) {
    final tg = feedModel.trustGraph;

    for (final IdentityKey issuer in tg.edges.keys) {
      final issuerIdentity = _resolve(issuer);
      for (final s in tg.edges[issuer]!) {
        if (s.verb == TrustVerb.trust || s.verb == TrustVerb.block || s.verb == TrustVerb.replace) {
          final subjectIdentity = _resolve(IdentityKey(s.subjectToken));
          final isNonCanonical = tg.replacements.containsKey(IdentityKey(s.subjectToken));
          
          final isConflict = tg.notifications.any((n) => n.isConflict && n.rejectedStatement.token == s.token);

          _mergeOrAddEdge(edges, GraphEdgeData(
            from: issuerIdentity,
            to: subjectIdentity,
            statements: [s],
            isIdentity: true,
            isConflict: isConflict,
            isNonCanonical: isNonCanonical,
          ));
        }
      }
    }
  }

  void _addFollowEdges(Set<IdentityKey> nodes, List<GraphEdgeData> edges) {
    final fn = feedModel.followNetwork;

    for (final IdentityKey issuerIdentity in fn.edges.keys) {
      final resolvedIssuer = _resolve(issuerIdentity);
      for (final s in fn.edges[issuerIdentity]!) {
        final subjectIdentity = _resolve(IdentityKey(s.subjectToken));
        
        final isConflict = fn.notifications.any((n) => n.isConflict && n.rejectedStatement.token == s.token);

        _mergeOrAddEdge(edges, GraphEdgeData(
          from: resolvedIssuer,
          to: subjectIdentity,
          statements: [s],
          isFollow: true,
          isConflict: isConflict,
        ));
      }
    }

    if (fn.fcontext == '<nerdster>') {
      final tg = feedModel.trustGraph;
      for (final IdentityKey issuer in tg.edges.keys) {
        if (!fn.contains(issuer)) continue;
        
        final issuerIdentity = _resolve(issuer);
        
        for (final s in tg.edges[issuer]!) {
          if (s.verb != TrustVerb.trust) continue;
          final subjectKey = IdentityKey(s.subjectToken);
          if (!fn.contains(subjectKey)) continue;

          final subjectIdentity = _resolve(subjectKey);

          _mergeOrAddEdge(edges, GraphEdgeData(
            from: issuerIdentity,
            to: subjectIdentity,
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
      if (e.from == newEdge.from && e.to == newEdge.to) {
        edges[i] = GraphEdgeData(
          from: e.from,
          to: e.to,
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

  void _addConflictEdges(Set<IdentityKey> nodes, Set<GraphEdgeData> edges) {
    final List<TrustNotification> conflicts = [...feedModel.trustGraph.conflicts];

    if (mode == GraphViewMode.follow) {
      // Need to cast or check notifications type from FollowNetwork.
      // FollowNetwork.notifications is List<TrustNotification>.
      conflicts.addAll(feedModel.followNetwork.notifications.where((n) => n.isConflict));
    }

    for (final conflict in conflicts) {
      // Conflict issuer/subject might be IdentityKey or String?
      // TrustStatement (which notifications reference) has subjectToken as String.
      // But TrustNotification has issuer -> IdentityKey (since it's resolved usually?).
      // Let's check TrustNotification in model.dart.
      // `final IdentityKey issuer; final IdentityKey subject;`?
      // No, TrustNotification fields in model.dart:
      // final String reason; final TrustStatement rejectedStatement; final bool isConflict;
      // It doesn't seem to have explicit issuer/subject fields on TrustNotification class itself, 
      // but rejectedStatement has them.
      
      final issuerKey = IdentityKey(getToken(conflict.rejectedStatement.i)); 
      final subjectKey = IdentityKey(conflict.rejectedStatement.subjectToken);

      final fromId = _resolve(issuerKey); 

      final toId = _resolve(subjectKey);

      if (nodes.contains(fromId) && nodes.contains(toId)) {
        GraphEdgeData? match;
        for (final e in edges) {
          if (e.from == fromId && e.to == toId) {
            match = e;
            break;
          }
        }

        if (match != null) {
          edges.remove(match);
          edges.add(GraphEdgeData(
            from: fromId,
            to: toId,
            statements: [...match.statements, conflict],
            isIdentity: match.isIdentity,
            isFollow: match.isFollow,
            isConflict: true,
            isNonCanonical: match.isNonCanonical,
          ));
        } else {
          edges.add(GraphEdgeData(
            from: fromId,
            to: toId,
            statements: [conflict],
            isConflict: true,
          ));
        }
      }
    }
  }
}
