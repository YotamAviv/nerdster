import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/fan_algorithm.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/singletons.dart';

import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/identity_context_selector.dart';
import 'package:nerdster/v2/key_info_view.dart';

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
    _graphController.mode = (fcontext == kOneofusContext) 
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
      _graphController.mode = (fcontext == kOneofusContext) 
          ? GraphViewMode.identity 
          : GraphViewMode.follow;
          
      _refreshGraph();
    }
  }

  void _updateAlgorithm() {
    _algorithm = FanAlgorithm(
      rootId: _graphController.rootIdentity,
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
    final model = widget.controller.value;
    if (model == null || _data == null || _data!.nodes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Network Graph')),
        body: const Center(child: Text('No nodes to display in this context.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // Hide default AppBar to use custom controls
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildControls(model),
            Expanded(
              child: InteractiveViewer(
                key: ValueKey(_graphController.rootIdentity),
                transformationController: _transformationController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.01,
                maxScale: 5.6,
                child: GraphView(
                  key: ValueKey('${_graphController.rootIdentity}_${_data?.nodes.length}_${_data?.edges.length}'),
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
      child: IdentityContextSelector(
        availableIdentities: model.trustGraph.orderedKeys,
        availableContexts: model.availableContexts,
        activeContexts: model.activeContexts,
        labeler: model.labeler,
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
    final resolvedRoot = model.labeler.getIdentityForToken(_graphController.rootIdentity);
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
    final V2FeedModel model = widget.controller.value!;
    final V2Labeler labeler = model.labeler;
    final List<String> labels = labeler.getAllLabels(identity);
    final TrustGraph tg = model.trustGraph;
    final List<String> keys = tg.getEquivalenceGroup(identity);
    final List<String> delegates = labeler.delegateResolver?.getDelegatesForIdentity(identity) ?? [];
    final String fcontext = model.fcontext;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Builder(
          builder: (context) {
            TapDownDetails? tapDetails;
            return InkWell(
              onTapDown: (details) => tapDetails = details,
              onTap: () {
                KeyInfoView.show(context, identity, kOneofusDomain, details: tapDetails);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(labeler.getLabel(identity))),
                  const SizedBox(width: 8),
                  const Icon(Icons.qr_code, size: 20, color: Colors.blue),
                ],
              ),
            );
          }
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('All Monikers:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (labels.isEmpty) const Text('None'),
              ...labels.map((l) => Text('• $l')),
              const SizedBox(height: 10),
              const Text('Key Lineage:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...keys.map((k) {
                final isCanonical = k == identity;
                return Builder(
                  builder: (context) {
                    TapDownDetails? tapDetails;
                    return InkWell(
                      onTapDown: (details) => tapDetails = details,
                      onTap: () => KeyInfoView.show(context, k, kOneofusDomain, details: tapDetails),
                      child: Text('• $k ${isCanonical ? "(Canonical)" : "(Replaced)"}', 
                        style: TextStyle(fontSize: 10, color: isCanonical ? Colors.black : Colors.grey, decoration: TextDecoration.underline)),
                    );
                  }
                );
              }),
              if (delegates.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Authorized Delegates:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...delegates.map((d) => Builder(
                  builder: (context) {
                    TapDownDetails? tapDetails;
                    return InkWell(
                      onTapDown: (details) => tapDetails = details,
                      onTap: () => KeyInfoView.show(context, d, kNerdsterDomain, details: tapDetails),
                      child: Text('• $d', style: const TextStyle(fontSize: 10, color: Colors.blue, decoration: TextDecoration.underline)),
                    );
                  }
                )),
              ],
              const SizedBox(height: 10),
              
              if (fcontext == kOneofusContext)
                _buildIdentityDetails(identity, model)
              else if (fcontext == kNerdsterContext)
                _buildNerdsterDetails(identity, model)
              else
                _buildContextDetails(identity, model, fcontext),
            ],
          ),
        ),
        actions: [
          if (identity != _graphController.rootIdentity)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                signInState.pov = identity;
                widget.controller.refresh(identity, meToken: signInState.identity);
              },
              child: const Text('Set as PoV'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildIdentityDetails(String identity, V2FeedModel model) {
    final labeler = model.labeler;
    final tg = model.trustGraph;
    
    final statements = tg.edges.values
        .expand((l) => l)
        .where((s) => labeler.getIdentityForToken(s.subjectToken) == identity)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Incoming Trust Statements:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (statements.isEmpty) const Text('None'),
        ...statements.map((s) => _buildStatementTile(s, labeler)),
      ],
    );
  }

  Widget _buildContextDetails(String identity, V2FeedModel model, String context) {
    final labeler = model.labeler;
    final fn = model.followNetwork;
    
    final statements = fn.edges.values
        .expand((l) => l)
        .where((s) => labeler.getIdentityForToken(s.subjectToken) == identity)
        .where((s) => s.contexts?.containsKey(context) == true)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Incoming Follows ($context):', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (statements.isEmpty) const Text('None'),
        ...statements.map((s) => _buildStatementTile(s, labeler, fcontext: context)),
      ],
    );
  }

  Widget _buildNerdsterDetails(String identity, V2FeedModel model) {
    final labeler = model.labeler;
    final fn = model.followNetwork;
    final tg = model.trustGraph;

    // 1. Explicit Follows
    final explicitStatements = fn.edges.values
        .expand((l) => l)
        .where((s) => labeler.getIdentityForToken(s.subjectToken) == identity)
        .where((s) => s.contexts?.containsKey(kNerdsterContext) == true)
        .toList();

    final explicitIssuers = explicitStatements
        .map((s) => labeler.getIdentityForToken(s.iToken))
        .toSet();

    // 2. Implicit Follows (Trust)
    // Only show trust statements if the issuer hasn't explicitly followed/blocked in this context
    final implicitStatements = tg.edges.values
        .expand((l) => l)
        .where((s) => labeler.getIdentityForToken(s.subjectToken) == identity)
        .where((s) {
          final issuer = labeler.getIdentityForToken(s.iToken);
          return !explicitIssuers.contains(issuer);
        })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nerdster Context:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
        const Text(
          'Includes explicit follows AND implicit follows derived from Trust (unless overridden).',
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        
        const Text('Explicit Follows:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (explicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...explicitStatements.map((s) => _buildStatementTile(s, labeler, fcontext: kNerdsterContext)),
        
        const SizedBox(height: 10),
        const Text('Implicit Follows (Trust):', style: TextStyle(fontWeight: FontWeight.bold)),
        if (implicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...implicitStatements.map((s) => _buildStatementTile(s, labeler)),
      ],
    );
  }

  Widget _buildStatementTile(dynamic s, V2Labeler labeler, {String? fcontext}) {
    final issuerLabel = labeler.getLabel(labeler.getIdentityForToken(s.iToken));
    String verbLabel = s is TrustStatement ? s.verb.label : (s as ContentStatement).verb.label;
    bool isBlock = false;

    if (s is ContentStatement && s.verb.label == 'follow' && fcontext != null) {
      final val = s.contexts?[fcontext];
      if (val != null) {
         final num v = val is num ? val : num.tryParse(val.toString()) ?? 0;
         if (v < 0) {
           verbLabel = '-follow';
           isBlock = true;
         }
      }
    }
    
    return ExpansionTile(
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'From $issuerLabel ('),
            TextSpan(
              text: verbLabel,
              style: TextStyle(color: isBlock ? Colors.red : null),
            ),
            const TextSpan(text: ')'),
          ],
        ),
        style: const TextStyle(fontSize: 12, color: Colors.black),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          height: 200,
          child: JsonDisplay(s.json),
        ),
      ],
    );
  }
}
