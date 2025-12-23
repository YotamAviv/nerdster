import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

const String kOneofusDomain = 'one-of-us.net';

/// A loader widget that runs the TrustPipeline and then shows the visualizer.
class TrustGraphVisualizerLoader extends StatefulWidget {
  final String rootToken;

  const TrustGraphVisualizerLoader({super.key, required this.rootToken});

  @override
  State<TrustGraphVisualizerLoader> createState() => _TrustGraphVisualizerLoaderState();
}

class _TrustGraphVisualizerLoaderState extends State<TrustGraphVisualizerLoader> {
  TrustGraph? _graph;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final source = SourceFactory.get<TrustStatement>(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final graph = await pipeline.build(widget.rootToken);
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
    return TrustGraphVisualizer(graph: _graph!);
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

  const TrustGraphVisualizer({super.key, required this.graph});

  @override
  State<TrustGraphVisualizer> createState() => _TrustGraphVisualizerState();
}

class _TrustGraphVisualizerState extends State<TrustGraphVisualizer> {
  final Graph graph = Graph();
  final FruchtermanReingoldAlgorithm algorithm = FruchtermanReingoldAlgorithm(FruchtermanReingoldConfiguration());

  @override
  void initState() {
    super.initState();
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
              child: _buildNodeWidget(token, dist, isRoot, isBlocked),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNodeWidget(String token, int dist, bool isRoot, bool isBlocked) {
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
            isRoot ? 'YOU (Root)' : 'Key ${token.substring(0, 6)}...',
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
