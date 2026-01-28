import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:oneofus_common/keys.dart';

enum GraphViewMode {
  identity, // Pure Identity Network
  follow, // Pure Follow Network for current context
}

class GraphEdgeData {
  final String from;
  final String to;
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
  final List<String> nodes;
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
  IdentityKey? focusedIdentity;

  GraphController(this.feedModel);

  IdentityKey get povIdentity => feedModel.povIdentity;

  GraphData buildGraphData() {
    final Set<String> nodes = {};
    final String root = feedModel.trustGraph.resolveIdentity(povIdentity).value;

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

    final String target = feedModel.labeler.getIdentityForToken(focusedIdentity!).value;

    // Reset nodes and edges to only what's needed for the paths
    nodes.clear();
    nodes.add(root);
    nodes.add(target);

    final Set<GraphEdgeData> edges = {};

    if (mode == GraphViewMode.identity) {
      // Identity graph paths are always key-based
      final List<List<IdentityKey>>? paths = feedModel.trustGraph.paths[IdentityKey(target)];
      if (paths != null) {
        for (final List<IdentityKey> path in paths) {
          _addPathToGraph(path, allEdges, nodes, edges);
        }
      }
    } else {
      // Follow network paths are always key-based
      final List<IdentityKey>? path = feedModel.followNetwork.paths[IdentityKey(target)];
      if (path != null) {
        _addPathToGraph(path, allEdges, nodes, edges);
      }
    }

    // Phase 2: Add Cross-Path Edges and Conflicts
    for (final GraphEdgeData edge in allEdges) {
      if (nodes.contains(edge.from) && nodes.contains(edge.to)) {
        edges.add(edge);
      }
    }

    // Add Conflicts
    _addConflictEdges(nodes, edges);

    // Ensure root is first
    final List<String> orderedNodes = [root, ...nodes.where((n) => n != root)];

    return GraphData(
      nodes: orderedNodes,
      edges: edges.toList(),
      root: root,
    );
  }

  void _addPathToGraph(List<IdentityKey> path, List<GraphEdgeData> allEdges, Set<String> nodes,
      Set<GraphEdgeData> edges) {
    for (int i = 0; i < path.length - 1; i++) {
      final String fromId = feedModel.trustGraph.resolveIdentity(path[i]).value;
      final String toId = feedModel.trustGraph.resolveIdentity(path[i + 1]).value;

      if (fromId == toId) continue;

      nodes.add(fromId);
      nodes.add(toId);

      try {
        final GraphEdgeData edge = allEdges.firstWhere((e) => e.from == fromId && e.to == toId);
        edges.add(edge);
      } catch (e) {
        // Edge missing
      }
    }
  }

  Set<GraphEdgeData> getPathToFocused(GraphData data) {
    if (focusedIdentity == null) return {};
    final Set<String> keepNodes = {};
    final Set<GraphEdgeData> pathEdges = {};

    final String target = feedModel.labeler.getIdentityForToken(focusedIdentity!).value;

    if (mode == GraphViewMode.identity) {
      final List<List<IdentityKey>>? paths = feedModel.trustGraph.paths[IdentityKey(target)];
      if (paths != null) {
        for (final List<IdentityKey> path in paths) {
          _addPathToGraph(path, data.edges, keepNodes, pathEdges);
        }
      }
    } else {
      final List<IdentityKey>? path = feedModel.followNetwork.paths[IdentityKey(target)];
      if (path != null) {
        _addPathToGraph(path, data.edges, keepNodes, pathEdges);
      }
    }
    return pathEdges;
  }

  void _addIdentityEdges(Set<String> nodes, List<GraphEdgeData> edges) {
    final tg = feedModel.trustGraph;

    for (final IdentityKey issuer in tg.edges.keys) {
      final String issuerIdentity = feedModel.trustGraph.resolveIdentity(issuer).value;
      for (final TrustStatement s in tg.edges[issuer]!) {
        if (s.verb == TrustVerb.trust ||
            s.verb == TrustVerb.block ||
            s.verb == TrustVerb.replace ||
            s.verb == TrustVerb.delegate) {
          final String subjectIdentity =
              feedModel.trustGraph.resolveIdentity(IdentityKey(s.subjectToken)).value;
          final bool isNonCanonical = tg.replacements.containsKey(IdentityKey(s.subjectToken));

          final bool isConflict =
              tg.notifications.any((n) => n.isConflict && n.rejectedStatement.token == s.token);

          _mergeOrAddEdge(
              edges,
              GraphEdgeData(
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

  void _addFollowEdges(Set<String> nodes, List<GraphEdgeData> edges) {
    final fn = feedModel.followNetwork;

    for (final IdentityKey issuerIdentity in fn.edges.keys) {
      final String resolvedIssuer = feedModel.trustGraph.resolveIdentity(issuerIdentity).value;
      for (final ContentStatement s in fn.edges[issuerIdentity]!) {
        // Subjects in follow network can be delegates. Resolve them.
        IdentityKey subjectKey = IdentityKey(s.subjectToken);
        final IdentityKey? delegateMatch =
            feedModel.delegateResolver.getIdentityForDelegate(DelegateKey(s.subjectToken));
        if (delegateMatch != null) {
          subjectKey = delegateMatch;
        }
        final String subjectIdentity = feedModel.trustGraph.resolveIdentity(subjectKey).value;

        _mergeOrAddEdge(
            edges,
            GraphEdgeData(
              from: resolvedIssuer,
              to: subjectIdentity,
              statements: [s],
              isFollow: true,
            ));
      }
    }

    if (fn.fcontext == '<nerdster>') {
      final tg = feedModel.trustGraph;
      for (final IdentityKey issuer in tg.edges.keys) {
        final IdentityKey issuerIdentityKey = feedModel.trustGraph.resolveIdentity(issuer);
        if (!fn.contains(issuerIdentityKey)) continue;

        final String issuerIdentity = issuerIdentityKey.value;

        for (final TrustStatement s in tg.edges[issuer]!) {
          if (s.verb != TrustVerb.trust) continue;
          final IdentityKey subjectKey = IdentityKey(s.subjectToken);
          final IdentityKey subjectIdentityKey = feedModel.trustGraph.resolveIdentity(subjectKey);

          if (!fn.contains(subjectIdentityKey)) continue;

          final String subjectIdentity = subjectIdentityKey.value;

          _mergeOrAddEdge(
              edges,
              GraphEdgeData(
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
      final GraphEdgeData e = edges[i];
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

  void _addConflictEdges(Set<String> nodes, Set<GraphEdgeData> edges) {
    final List<TrustNotification> conflicts = [...feedModel.trustGraph.conflicts];

    if (mode == GraphViewMode.follow) {
      conflicts.addAll(feedModel.followNetwork.notifications.where((n) => n.isConflict));
    }

    for (final TrustNotification conflict in conflicts) {
      final IdentityKey issuerKey = IdentityKey(getToken(conflict.rejectedStatement.i));
      final IdentityKey subjectKey = IdentityKey(conflict.rejectedStatement.subjectToken);

      final String fromId = feedModel.trustGraph.resolveIdentity(issuerKey).value;

      final String toId = feedModel.trustGraph.resolveIdentity(subjectKey).value;

      if (nodes.contains(fromId) && nodes.contains(toId)) {
        GraphEdgeData? match;
        for (final GraphEdgeData e in edges) {
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
