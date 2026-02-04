import 'package:flutter/material.dart';
import 'package:oneofus_common/keys.dart';
import 'package:graphview/GraphView.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/graph_controller.dart';
import 'package:nerdster/logic/fan_algorithm.dart';
import 'package:nerdster/logic/feed_controller.dart';

import 'package:nerdster/logic/follow_logic.dart';
import 'package:nerdster/ui/trust_settings_bar.dart';
import 'package:nerdster/ui/dialogs/node_details.dart';
import 'package:nerdster/logic/labeler.dart';

class NerdyGraphView extends StatefulWidget {
  final FeedController controller;
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
  final Map<String, Offset> _pinnedNodes = {};

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
      pinnedNodes: _pinnedNodes,
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
        _pinnedNodes.clear();
        _buildGraphView();
      });
      return;
    }
    final GraphData newData = _graphController!.buildGraphData();
    final Set<GraphEdgeData> newPathEdges = _graphController!.getPathToFocused(newData);

    setState(() {
      _data = newData;
      _pathEdges = newPathEdges;
      _pinnedNodes.clear();
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
    Color color = Colors.green; // Default to trust/identity
    bool isDashed = e.isConflict;

    if (e.isFollow) {
      color = Colors.blue;
    }

    if (e.isBlock) {
      color = Colors.red;
    }

    return Paint()
      ..color = color.withOpacity(isPath ? 1.0 : 0.6)
      ..strokeWidth = isPath ? 3.0 : 1.5
      ..style = PaintingStyle.stroke
      // Use butt cap as a hacky signal to the renderer to draw dashed lines
      ..strokeCap = isDashed ? StrokeCap.butt : StrokeCap.round;
  }

  @override
  Widget build(BuildContext context) {
    final FeedModel? model = widget.controller.value;
    if (model == null || _data == null || _data!.nodes.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTrustSettingsBar(model),
                  const Expanded(
                    child: Center(child: Text('No nodes to display in this context.')),
                  ),
                ],
              ),
              Positioned(
                top: 54,
                left: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back, color: Colors.blue),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTrustSettingsBar(model),
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
                      builder: (Node node) => _buildNodeWidget(node),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 54,
              left: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back, color: Colors.blue),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
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

  Widget _buildTrustSettingsBar(FeedModel? model) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
      child: TrustSettingsBar(
        availableIdentities: model?.trustGraph.orderedKeys ?? [],
        availableContexts: model?.availableContexts ?? [],
        activeContexts: model?.activeContexts ?? {},
        labeler: model?.labeler ?? Labeler(TrustGraph(pov: IdentityKey(''))),
      ),
    );
  }

  Widget _buildNodeWidget(Node node) {
    final keyVal = node.key!.value;
    final IdentityKey identity = keyVal is IdentityKey ? keyVal : IdentityKey(keyVal.toString());

    if (identity.value.startsWith('...')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey),
        ),
        width: 30,
        height: 30,
        alignment: Alignment.center,
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
      onPanUpdate: (details) {
        if (identity.value.startsWith('...')) return;
        final currentPos = Offset(node.x, node.y);
        final newPos = currentPos + details.delta;

        setState(() {
          _pinnedNodes[identity.value] = newPos;
          _updateAlgorithm();
        });
      },
      onTap: () {
        if (identity.value.startsWith('...')) return;
        _showNodeDetails(identity);
      },
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: (isRoot ? Colors.blue[50] : (isFocused ? Colors.orange[50] : Colors.white))?.withOpacity(0.8),
          shape: BoxShape.circle,
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
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isRoot ? 11 : 9,
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
