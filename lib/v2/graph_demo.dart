import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/v2/trust_logic.dart';

/// A loader widget that runs the TrustPipeline and then shows the visualizer.
class TrustGraphVisualizerLoader extends StatefulWidget {
  final String? rootToken;

  const TrustGraphVisualizerLoader({super.key, this.rootToken});

  @override
  State<TrustGraphVisualizerLoader> createState() => _TrustGraphVisualizerLoaderState();
}

class _TrustGraphVisualizerLoaderState extends State<TrustGraphVisualizerLoader> {
  TrustGraph? _graph;
  String? _currentRoot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentRoot = widget.rootToken;
    if (_currentRoot != null) {
      _load();
    } else {
      _loading = false;
    }
    Setting.get(SettingType.identityPathsReq).notifier.addListener(_onSettingChanged);
  }

  @override
  void dispose() {
    Setting.get(SettingType.identityPathsReq).notifier.removeListener(_onSettingChanged);
    super.dispose();
  }

  void _onSettingChanged() {
    setState(() {
      _loading = true;
      _graph = null;
    });
    _load();
  }

  Future<void> _load() async {
    final root = _currentRoot;
    if (root == null) return;
    try {
      final source = SourceFactory.get<TrustStatement>(kOneofusDomain);
      
      final identityPathsReq = Setting.get<String>(SettingType.identityPathsReq).value;
      PathRequirement? pathReq;
      final reqString = pathsReq[identityPathsReq] ?? pathsReq['standard']!;
      
      try {
        final parts = reqString.split(RegExp(r'[-,\s]+'));
        final reqs = parts.map(int.parse).toList();
        if (reqs.isNotEmpty) {
          pathReq = (int distance) {
            final index = distance - 1;
            if (index >= 0 && index < reqs.length) return reqs[index];
            return reqs.last;
          };
        }
      } catch (e) {
        debugPrint('Error parsing identityPathsReq: $e');
      }

      final pipeline = TrustPipeline(source, pathRequirement: pathReq);
      final graph = await pipeline.build(root);
      if (mounted) {
        setState(() {
          _graph = graph;
          _loading = false;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _error = '$e\n$stack';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentRoot == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view the trust graph.')),
      );
    }
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: SingleChildScrollView(child: Text(_error!)),
      );
    }
    return TrustGraphVisualizer(
      graph: _graph!,
      onPovChanged: (newToken) {
        setState(() {
          _currentRoot = newToken;
          _loading = true;
          _graph = null;
        });
        _load();
      },
    );
  }
}

/// A quick demo app to run the visualizer.
void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('Pass a TrustGraph to TrustGraphVisualizer'),
      ),
    ),
  ));
}

/// A quick demo widget to visualize the TrustGraph using GraphView.
class TrustGraphVisualizer extends StatefulWidget {
  final TrustGraph graph;
  final Function(String)? onPovChanged;

  const TrustGraphVisualizer({super.key, required this.graph, this.onPovChanged});

  @override
  State<TrustGraphVisualizer> createState() => _TrustGraphVisualizerState();
}

class _TrustGraphVisualizerState extends State<TrustGraphVisualizer> {
  final Graph graph = Graph();
  final FruchtermanReingoldAlgorithm algorithm =
      FruchtermanReingoldAlgorithm(FruchtermanReingoldConfiguration());
  late V2Labeler _labeler;

  @override
  void initState() {
    super.initState();
    _labeler = V2Labeler(widget.graph);
    _buildGraph();
  }

  void _buildGraph() {
    final Map<String, Node> nodes = {};

    // 1. Create Nodes for all trusted keys
    for (final token in widget.graph.distances.keys) {
      nodes[token] = Node.Id(token);
    }

    // 2. Add Edges based on TrustStatements
    for (final issuer in widget.graph.edges.keys) {
      final issuerNode = nodes[issuer];
      if (issuerNode == null) continue;

      for (final s in widget.graph.edges[issuer]!) {
        final subject = s.subjectToken;

        final subjectNode = nodes[subject];
        if (subjectNode == null && s.verb != TrustVerb.block) continue;

        // Determine Edge Color
        Color edgeColor = Colors.grey;
        if (s.verb == TrustVerb.trust) edgeColor = Colors.blue;
        if (s.verb == TrustVerb.replace) edgeColor = Colors.green;
        if (s.verb == TrustVerb.block) edgeColor = Colors.red;

        // For blocks, the subject might not be in the 'trusted' nodes map
        final targetNode = subjectNode ?? Node.Id(subject);
        if (!nodes.containsKey(subject)) {
           nodes[subject] = targetNode;
        }

        graph.addEdge(
          issuerNode, 
          targetNode, 
          paint: Paint()
            ..color = edgeColor.withOpacity(0.6)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trust Network Visualization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              graph.nodes.clear();
              graph.edges.clear();
              _buildGraph();
            }),
          )
        ],
      ),
      body: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.01,
        maxScale: 5.6,
        child: GraphView(
          graph: graph,
          algorithm: algorithm,
          paint: Paint()
            ..color = Colors.black
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final String token = node.key!.value as String;
            final int dist = widget.graph.distances[token] ?? 99;
            final bool isBlocked = widget.graph.blocked.contains(token);
            final bool isRoot = token == widget.graph.root;

            // Fading based on distance
            final double opacity = (1.0 - (dist * 0.2)).clamp(0.1, 1.0);

            return Opacity(
              opacity: opacity,
              child: GestureDetector(
                onLongPress: () => _showNodeDetails(token),
                child: _buildNodeWidget(token, dist, isRoot, isBlocked),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showNodeDetails(String token) {
    final labels = _labeler.getAllLabels(token);
    final paths = _labeler.getLabeledPaths(token);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_labeler.getLabel(token)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Token: $token', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 10),
              const Text('All Monikers:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (labels.isEmpty) const Text('None'),
              ...labels.map((l) => Text('• $l')),
              const SizedBox(height: 10),
              const Text('Shortest Paths:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (paths.isEmpty) const Text('None'),
              ...paths.map((p) => Text('• $p')),
            ],
          ),
        ),
        actions: [
          if (widget.onPovChanged != null && token != widget.graph.root)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onPovChanged!(token);
              },
              child: const Text('Set as PoV'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(String token, int dist, bool isRoot, bool isBlocked) {
    final label = _labeler.getLabel(token);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isRoot ? Colors.amber[100] : (isBlocked ? Colors.red[50] : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRoot ? Colors.amber : (isBlocked ? Colors.red : Colors.blue),
          width: isRoot ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isRoot ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          if (!isRoot)
            Text(
              'Dist: $dist',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
