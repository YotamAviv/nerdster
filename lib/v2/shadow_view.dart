import 'package:flutter/material.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/net_tree_model.dart';
import 'package:nerdster/v2/net_tree_view.dart';
import 'package:nerdster/v2/graph_demo.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

const String kOneofusDomain = 'one-of-us.net';
const String kNerdsterDomain = 'nerdster.org';

class ShadowView extends StatefulWidget {
  final String rootToken;

  const ShadowView({super.key, required this.rootToken});

  @override
  State<ShadowView> createState() => _ShadowViewState();
}

class _ShadowViewState extends State<ShadowView> {
  TrustGraph? _graph;
  V2Labeler? _labeler;
  List<ContentStatement>? _content;
  bool _loading = false;
  String? _error;
  
  // Persist cache across runs within this view
  final CachedSource<TrustStatement> _cachedIdentity = CachedSource(SourceFactory.get<TrustStatement>(kOneofusDomain));
  final CachedSource<ContentStatement> _cachedContent = CachedSource(SourceFactory.get<ContentStatement>(kNerdsterDomain));

  Future<void> _runPipeline() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Identity Pipeline
      final trustPipeline = TrustPipeline(_cachedIdentity);
      final graph = await trustPipeline.build(widget.rootToken);

      // 2. Content Pipeline
      final contentPipeline = ContentPipeline(_cachedContent);
      final content = await contentPipeline.fetchContent(graph);

      if (mounted) {
        setState(() {
          _graph = graph;
          _labeler = V2Labeler(graph);
          _content = content;
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

  void _showTree() {
    if (_graph == null) return;
    final labeler = V2Labeler(_graph!);
    final root = V2NetTreeModel([], _graph!, labeler, token: _graph!.root);
    Navigator.push(context, MaterialPageRoute(builder: (_) => V2NetTreeView(root: root)));
  }

  void _showGraph() {
    if (_graph == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Trust Graph Visualization')),
          body: TrustGraphVisualizer(graph: _graph!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('V2 Shadow Pipeline'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Content'),
              Tab(text: 'Graph & Conflicts'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loading ? null : _runPipeline,
                    child: _loading ? const CircularProgressIndicator() : const Text('Run Pipeline'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _loading ? null : () {
                      _cachedIdentity.clear();
                      _cachedContent.clear();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
                    },
                    child: const Text('Clear Cache'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (_graph == null || _loading) ? null : _showTree,
                    child: const Text('Show Tree'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (_graph == null || _loading) ? null : _showGraph,
                    child: const Text('Visualize'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Expanded(
                  child: SingleChildScrollView(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)))),
            if (_graph != null)
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Content
                    ListView.builder(
                      itemCount: _content?.length ?? 0,
                      itemBuilder: (context, index) {
                        final item = _content![index];
                        final label = _labeler?.getLabel(item.iToken) ?? item.iToken;
                        return ListTile(
                          title: Text('${item.verb.label} ${item.subject}'),
                          subtitle: Text('By: $label\n${item.subject}'),
                          trailing: Text(item.time.toString().split(' ')[0]),
                        );
                      },
                    ),
                    // Tab 2: Graph Details
                    ListView(
                      children: [
                        ListTile(
                          title: const Text('Stats'),
                          subtitle: Text(
                              'Nodes: ${_graph!.distances.length}, Blocked: ${_graph!.blocked.length}, Notifications: ${_graph!.notifications.length}'),
                        ),
                        const Divider(),
                        if (_graph!.notifications.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Notifications & Conflicts',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                          ..._graph!.notifications.map((n) => ListTile(
                                title: Text(_labeler?.getLabel(n.subject) ?? n.subject),
                                subtitle: Text(n.reason),
                                leading: Icon(
                                    n.isConflict ? Icons.warning : Icons.info,
                                    color: n.isConflict ? Colors.red : Colors.blue),
                              )),
                          const Divider(),
                        ],
                        if (_graph!.blocked.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Blocked',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ..._graph!.blocked.map((b) => ListTile(
                                title: Text(_labeler?.getLabel(b) ?? b),
                                subtitle: Text('Token: $b'),
                                leading: const Icon(Icons.block, color: Colors.red),
                              )),
                          const Divider(),
                        ],
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Trusted Identities',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ..._graph!.getEquivalenceGroups().entries.map((entry) {
                          final canonical = entry.key;
                          final members = entry.value;
                          final label = _labeler?.getLabel(canonical) ?? canonical;
                          
                          return ExpansionTile(
                            title: Text(label),
                            subtitle: Text('Identity: $canonical (${members.length} keys)'),
                            leading: const Icon(Icons.person, color: Colors.green),
                            children: members.map((token) {
                              final memberLabel = _labeler?.getLabel(token) ?? token;
                              final dist = _graph!.distances[token];
                              final isCanonical = token == canonical;
                              
                              return ListTile(
                                title: Text(memberLabel),
                                subtitle: Text('Distance: $dist\nToken: $token'),
                                leading: Icon(
                                  isCanonical ? Icons.check_circle : Icons.history,
                                  color: isCanonical ? Colors.green : Colors.orange,
                                ),
                                dense: true,
                              );
                            }).toList(),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
