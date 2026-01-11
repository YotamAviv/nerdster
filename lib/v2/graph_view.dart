import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:graphview/GraphView.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/fan_algorithm.dart';
import 'package:nerdster/v2/feed_controller.dart';

import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/trust_settings_bar.dart';
import 'package:nerdster/v2/node_details.dart';
import 'package:nerdster/v2/labeler.dart';

class NerdyGraphView extends StatefulWidget {
  final V2FeedController controller;
  final String? initialFocus;

  const NerdyGraphView({
    super.key,
    required this.controller,
    this.initialFocus,
  });

  @override
  State<NerdyGraphView> createState() => _NerdyGraphViewState();
}

class _NerdyGraphViewState extends State<NerdyGraphView> {
  GraphController? _graphController;
  Graph _graph = Graph();
  final TransformationController _transformationController = TransformationController();
  late Algorithm _algorithm;

  GraphData? _data;
  Set<GraphEdgeData> _pathEdges = {};

  @override
  void initState() {
    super.initState();
    if (widget.controller.value != null) {
      _graphController = GraphController(widget.controller.value!);
      if (widget.initialFocus != null) {
        _graphController!.focusedIdentity = IdentityKey(widget.initialFocus!);
      }

      final String fcontext = widget.controller.value!.fcontext;
      _graphController!.mode =
          (fcontext == kFollowContextIdentity) ? GraphViewMode.identity : GraphViewMode.follow;
    }

    widget.controller.addListener(_onModelChanged);

    _updateAlgorithm();
    _refreshGraph();

    // Center on root after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transformationController.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onModelChanged);
    super.dispose();
  }

  void _onModelChanged() {
    if (widget.controller.value != null) {
      final IdentityKey? oldFocus = _graphController?.focusedIdentity;
      _graphController = GraphController(widget.controller.value!);
      _graphController!.focusedIdentity = oldFocus;

      final String fcontext = widget.controller.value!.fcontext;
      _graphController!.mode =
          (fcontext == kFollowContextIdentity) ? GraphViewMode.identity : GraphViewMode.follow;

      _refreshGraph();
    } else {
      _graphController = null;
      _refreshGraph();
    }
  }

  void _updateAlgorithm() {
    if (_graphController == null) return;

    // Use the canonical root from the data if available, otherwise the POV
    final rootId = _data?.root ?? _graphController!.povIdentity.value;

    // FanAlgorithm expects the key of the root node.
    _algorithm = FanAlgorithm(
      rootId: rootId,
      levelSeparation: 200,
    );
  }

  @override
  void didUpdateWidget(NerdyGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onModelChanged);
      widget.controller.addListener(_onModelChanged);
      _onModelChanged();
    }
  }

  void _refreshGraph() {
    if (_graphController == null) {
      setState(() {
        _data = null;
        _pathEdges = {};
        _buildGraphView();
      });
      return;
    }
    final GraphData newData = _graphController!.buildGraphData();
    final Set<GraphEdgeData> newPathEdges = _graphController!.getPathToFocused(newData);

    setState(() {
      _data = newData;
      _pathEdges = newPathEdges;
      _updateAlgorithm();
      _buildGraphView();
    });
  }

  void _buildGraphView() {
    final Graph newGraph = Graph();

    if (_data == null || _data!.nodes.isEmpty) {
      _graph = newGraph;
      return;
    }

    final Map<String, Node> nodes = {};
    for (final identity in _data!.nodes) {
      // Identity is now String
      final Node node = Node.Id(identity);
      nodes[identity] = node;
      newGraph.addNode(node);
    }

    for (final e in _data!.edges) {
      final Node? fromNode = nodes[e.from];
      final Node? toNode = nodes[e.to];
      if (fromNode == null || toNode == null) continue;

      final bool isPath = _pathEdges.contains(e);
      final Paint paint = _getEdgePaint(e, isPath);

      newGraph.addEdge(fromNode, toNode, paint: paint);
    }

    _graph = newGraph;
  }

  Paint _getEdgePaint(GraphEdgeData e, bool isPath) {
    Color color = Colors.grey;
    double strokeWidth = isPath ? 3.0 : 1.5;

    if (e.isConflict) {
      color = Colors.orange;
    } else if (e.isNonCanonical) {
      color = Colors.green;
    } else if (e.isIdentity) {
      color = Colors.green;
    } else if (e.isFollow) {
      color = Colors.blue;
    }

    return Paint()
      ..color = color.withOpacity(isPath ? 1.0 : 0.6)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
  }

  @override
  Widget build(BuildContext context) {
    final V2FeedModel? model = widget.controller.value;
    if (model == null || _data == null || _data!.nodes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Network Graph')),
        body: Column(
          children: [
            _buildControls(model),
            const Expanded(
              child: Center(child: Text('No nodes to display in this context.')),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildControls(model),
            Expanded(
              child: InteractiveViewer(
                key: ValueKey(_graphController!.povIdentity.value),
                transformationController: _transformationController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.01,
                maxScale: 5.6,
                child: GraphView(
                  key: ValueKey(
                      '${_graphController!.povIdentity.value}_${_data?.nodes.length}_${_data?.edges.length}'),
                  graph: _graph,
                  algorithm: _algorithm,
                  paint: Paint()
                    ..color = Colors.black
                    ..strokeWidth = 1
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final key = node.key!.value;
                    if (key is IdentityKey) {
                      return _buildNodeWidget(key);
                    }
                    // Should not happen if we only add IdentityKeys
                    return _buildNodeWidget(IdentityKey(key.toString()));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.center_focus_strong),
        onPressed: () {
          setState(() {
            _transformationController.value = Matrix4.identity();
            _refreshGraph();
          });
        },
      ),
    );
  }

  Widget _buildControls(V2FeedModel? model) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          FloatingActionButton.small(
            heroTag: 'graph_back',
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TrustSettingsBar(
              availableIdentities: model?.trustGraph.orderedKeys ?? [],
              availableContexts: model?.availableContexts ?? [],
              activeContexts: model?.activeContexts ?? {},
              // labeler: model?.labeler ?? V2Labeler(TrustGraph(pov: IdentityKey(''))),
              // TrustSettingsBar might also need update if it takes old labeler or mismatch types
              // Assuming TrustSettingsBar is somewhat compatible or we fix it next.
              labeler: model?.labeler ?? V2Labeler(TrustGraph(pov: IdentityKey(''))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(IdentityKey identity) {
    if (identity.value.startsWith('...')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey),
        ),
        child: const Text('...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
      );
    }

    final model = widget.controller.value!;
    final label = model.labeler.getLabel(identity.value);

    final IdentityKey resolvedRoot =
        model.trustGraph.resolveIdentity(_graphController!.povIdentity);

    IdentityKey? resolvedFocused;
    if (_graphController!.focusedIdentity != null) {
      IdentityKey f = _graphController!.focusedIdentity!;

      // Handle delegate resolution for focus highlighting
      final delegateMatch = model.delegateResolver.getIdentityForDelegate(DelegateKey(f.value));
      if (delegateMatch != null) {
        f = delegateMatch;
      }

      if (model.trustGraph.isTrusted(f)) {
        resolvedFocused = model.trustGraph.resolveIdentity(f);
      } else {
        resolvedFocused = f;
      }
    }

    final isRoot = identity == resolvedRoot;
    final isFocused = identity == resolvedFocused;

    return GestureDetector(
      onTap: () {
        if (identity.value.startsWith('...')) return;
        _showNodeDetails(identity);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isRoot ? Colors.blue[50] : (isFocused ? Colors.orange[50] : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? Colors.orange : (isRoot ? Colors.blue : Colors.grey[300]!),
            width: isFocused || isRoot ? 2 : 1,
          ),
          boxShadow: [
            if (isFocused || isRoot)
              BoxShadow(
                color: (isFocused ? Colors.orange : Colors.blue).withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isRoot ? 13 : 11,
            fontWeight: isRoot || isFocused ? FontWeight.bold : FontWeight.normal,
            color: isRoot ? Colors.blue[900] : (isFocused ? Colors.orange[900] : Colors.black87),
          ),
        ),
      ),
    );
  }

  void _showNodeDetails(IdentityKey identity) {
    NodeDetails.show(context, identity, widget.controller);
  }
}
