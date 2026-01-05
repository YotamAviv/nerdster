import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/fan_algorithm.dart';
import 'package:nerdster/v2/feed_controller.dart';

import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/trust_settings_bar.dart';
import 'package:nerdster/v2/node_details.dart';

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
  late GraphController _graphController;
  Graph _graph = Graph();
  final TransformationController _transformationController = TransformationController();
  late Algorithm _algorithm;
  
  GraphData? _data;
  Set<GraphEdgeData> _pathEdges = {};

  @override
  void initState() {
    super.initState();
    _graphController = GraphController(widget.controller.value!);
    _graphController.focusedIdentity = widget.initialFocus;
    
    final fcontext = widget.controller.value!.fcontext;
    _graphController.mode = (fcontext == kFollowContextIdentity) 
        ? GraphViewMode.identity 
        : GraphViewMode.follow;

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
      final oldFocus = _graphController.focusedIdentity;
      _graphController = GraphController(widget.controller.value!);
      _graphController.focusedIdentity = oldFocus;
      
      final fcontext = widget.controller.value!.fcontext;
      _graphController.mode = (fcontext == kFollowContextIdentity) 
          ? GraphViewMode.identity 
          : GraphViewMode.follow;
          
      _refreshGraph();
    }
  }

  void _updateAlgorithm() {
    _algorithm = FanAlgorithm(
      rootId: _graphController.povIdentity,
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
    final newData = _graphController.buildGraphData();
    final newPathEdges = _graphController.getPathToFocused(newData);
    
    setState(() {
      _data = newData;
      _pathEdges = newPathEdges;
      _updateAlgorithm();
      _buildGraphView();
    });

    // Reset view when root changes
    // _transformationController.value = Matrix4.identity();
  }

  void _buildGraphView() {
    final newGraph = Graph();

    if (_data == null || _data!.nodes.isEmpty) {
      _graph = newGraph;
      return;
    }

    final Map<String, Node> nodes = {};
    for (final identity in _data!.nodes) {
      final node = Node.Id(identity);
      nodes[identity] = node;
      newGraph.addNode(node);
    }

    for (final e in _data!.edges) {
      final fromNode = nodes[e.fromIdentity];
      final toNode = nodes[e.toIdentity];
      if (fromNode == null || toNode == null) continue;

      final isPath = _pathEdges.contains(e);
      final paint = _getEdgePaint(e, isPath);

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
    final model = widget.controller.value;
    if (model == null || _data == null || _data!.nodes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Network Graph')),
        body: const Center(child: Text('No nodes to display in this context.')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildControls(model),
            Expanded(
              child: InteractiveViewer(
                key: ValueKey(_graphController.povIdentity),
                transformationController: _transformationController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.01,
                maxScale: 5.6,
                child: GraphView(
                  key: ValueKey('${_graphController.povIdentity}_${_data?.nodes.length}_${_data?.edges.length}'),
                  graph: _graph,
                  algorithm: _algorithm,
                  paint: Paint()
                    ..color = Colors.black
                    ..strokeWidth = 1
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final identity = node.key!.value as String;
                    return _buildNodeWidget(identity);
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

  Widget _buildControls(V2FeedModel model) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          Expanded(
            child: TrustSettingsBar(
              availableIdentities: model.trustGraph.orderedKeys,
              availableContexts: model.availableContexts,
              activeContexts: model.activeContexts,
              labeler: model.labeler,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(String identity) {
    if (identity.startsWith('...')) {
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
    final label = model.labeler.getLabel(identity);
    final resolvedRoot = model.labeler.getIdentityForToken(_graphController.povIdentity);
    final resolvedFocused = _graphController.focusedIdentity != null 
        ? model.labeler.getIdentityForToken(_graphController.focusedIdentity!)
        : null;

    final isRoot = identity == resolvedRoot;
    final isFocused = identity == resolvedFocused;

    return GestureDetector(
      onTap: () {
        if (identity.startsWith('...')) return;
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

  void _showNodeDetails(String identity) {
    NodeDetails.show(context, identity, widget.controller);
  }
}
