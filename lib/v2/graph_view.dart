import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/fan_algorithm.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';

class NerdyGraphView extends StatefulWidget {
  final V2FeedModel feedModel;
  final ValueChanged<String?>? onPovChanged;
  final String? initialFocus;

  const NerdyGraphView({
    super.key,
    required this.feedModel,
    this.onPovChanged,
    this.initialFocus,
  });

  @override
  State<NerdyGraphView> createState() => _NerdyGraphViewState();
}

class _NerdyGraphViewState extends State<NerdyGraphView> {
  late GraphController _controller;
  Graph _graph = Graph();
  final TransformationController _transformationController = TransformationController();
  late Algorithm _algorithm;
  
  GraphData? _data;
  Set<GraphEdgeData> _pathEdges = {};

  @override
  void initState() {
    super.initState();
    _controller = GraphController(widget.feedModel);
    _controller.focusedIdentity = widget.initialFocus;
    _controller.mode = GraphViewMode.values.firstWhere(
      (m) => m.name == Setting.get<String>(SettingType.graphMode).value,
      orElse: () => GraphViewMode.follow,
    );

    _updateAlgorithm();
    _refreshGraph();

    // Center on root after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _updateAlgorithm() {
    _algorithm = FanAlgorithm(
      rootId: _controller.rootIdentity,
      levelSeparation: 200,
    );
  }

  @override
  void didUpdateWidget(NerdyGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedModel != widget.feedModel) {
      final oldFocus = _controller.focusedIdentity;
      _controller = GraphController(widget.feedModel);
      _controller.focusedIdentity = oldFocus;
      _controller.mode = GraphViewMode.values.firstWhere(
        (m) => m.name == Setting.get<String>(SettingType.graphMode).value,
        orElse: () => GraphViewMode.follow,
      );
      
      _updateAlgorithm();
      _refreshGraph();
    }
  }

  void _refreshGraph() {
    final newData = _controller.buildGraphData();
    final newPathEdges = _controller.getPathToFocused(newData);
    
    setState(() {
      _data = newData;
      _pathEdges = newPathEdges;
      _updateAlgorithm();
      _buildGraphView();
    });

    // Reset view when root changes
    _transformationController.value = Matrix4.identity();
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
    } else if (e.isIdentity) {
      color = Colors.green;
    } else if (e.isFollow) {
      color = Colors.blue;
    }

    return Paint()
      ..color = color.withOpacity(isPath ? 1.0 : 0.6)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null || _data!.nodes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Network Graph')),
        body: const Center(child: Text('No nodes to display in this context.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Graph'),
        actions: [
          _buildModeSelector(),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              setState(() {
                _controller.focusedIdentity = null;
                _transformationController.value = Matrix4.identity();
                _refreshGraph();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_controller.focusedIdentity != null)
            _buildFocusHeader(),
          Expanded(
            child: InteractiveViewer(
              key: ValueKey(_controller.rootIdentity),
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.01,
              maxScale: 5.6,
              child: GraphView(
                key: ValueKey('${_controller.rootIdentity}_${_data?.nodes.length}_${_data?.edges.length}'),
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
    );
  }

  Widget _buildModeSelector() {
    return DropdownButton<GraphViewMode>(
      value: _controller.mode,
      onChanged: (mode) {
        if (mode != null) {
          Setting.get<String>(SettingType.graphMode).value = mode.name;
          setState(() {
            _controller.mode = mode;
            _refreshGraph();
          });
        }
      },
      items: GraphViewMode.values.map((m) {
        return DropdownMenuItem(
          value: m,
          child: Text(m.name.toUpperCase()),
        );
      }).toList(),
    );
  }

  Widget _buildFocusHeader() {
    final label = widget.feedModel.labeler.getLabel(_controller.focusedIdentity!);
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.blue[50],
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Focusing on: $label', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _controller.focusedIdentity = null;
                _refreshGraph();
              });
            },
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

    final label = widget.feedModel.labeler.getLabel(identity);
    final resolvedRoot = widget.feedModel.labeler.getIdentityForToken(_controller.rootIdentity);
    final resolvedFocused = _controller.focusedIdentity != null 
        ? widget.feedModel.labeler.getIdentityForToken(_controller.focusedIdentity!)
        : null;

    final isRoot = identity == resolvedRoot;
    final isFocused = identity == resolvedFocused;

    return GestureDetector(
      onTap: () {
        if (identity.startsWith('...')) return;
        setState(() {
          _controller.focusedIdentity = identity;
          _refreshGraph();
        });
      },
      onLongPress: () {
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
    final labeler = widget.feedModel.labeler;
    final labels = labeler.getAllLabels(identity);
    final tg = widget.feedModel.trustGraph;
    final keys = tg.getEquivalenceGroup(identity);
    final delegates = labeler.delegateResolver?.getDelegatesForIdentity(identity) ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(labeler.getLabel(identity)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Identity: $identity', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 10),
              const Text('All Monikers:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (labels.isEmpty) const Text('None'),
              ...labels.map((l) => Text('• $l')),
              const SizedBox(height: 10),
              const Text('Key Lineage:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...keys.map((k) {
                final isCanonical = k == identity;
                return Text('• $k ${isCanonical ? "(Canonical)" : "(Replaced)"}', 
                  style: TextStyle(fontSize: 10, color: isCanonical ? Colors.black : Colors.grey));
              }),
              if (delegates.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Authorized Delegates:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...delegates.map((d) => Text('• $d', style: const TextStyle(fontSize: 10, color: Colors.blue))),
              ],
              const SizedBox(height: 10),
              const Text('Incoming Trust Statements:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...tg.edges.values.expand((l) => l).where((s) => labeler.getIdentityForToken(s.subjectToken) == identity).map((s) {
                final issuerLabel = labeler.getLabel(labeler.getIdentityForToken(s.iToken));
                return ExpansionTile(
                  title: Text('From $issuerLabel (${s.verb.label})', style: const TextStyle(fontSize: 12)),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[100],
                      child: SelectableText(
                        encoder.convert(s.json),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        actions: [
          if (widget.onPovChanged != null && identity != _controller.rootIdentity)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onPovChanged!(identity);
              },
              child: const Text('Set as PoV'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
