import 'package:flutter/material.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/net_tree_model.dart';
import 'package:nerdster/v2/net_tree_view.dart';
import 'package:nerdster/content/content_statement.dart';

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
  List<ContentStatement>? _content;
  bool _loading = false;
  String? _error;
  
  // Persist cache across runs within this view
  final CachedSource _cachedIdentity = CachedSource(SourceFactory.get(kOneofusDomain));
  final CachedSource _cachedContent = CachedSource(SourceFactory.get(kNerdsterDomain));

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
    final root = V2NetTreeModel([], _graph!, token: _graph!.root);
    Navigator.push(context, MaterialPageRoute(builder: (_) => V2NetTreeView(root: root)));
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
                        return ListTile(
                          title: Text('${item.verb.label} ${item.subject}'),
                          subtitle: Text('By: ${item.iToken}\n${item.subject}'),
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
                              'Nodes: ${_graph!.distances.length}, Blocked: ${_graph!.blocked.length}, Conflicts: ${_graph!.conflicts.length}'),
                        ),
                        const Divider(),
                        if (_graph!.conflicts.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Conflicts',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                          ),
                          ..._graph!.conflicts.map((c) => ListTile(
                                title: Text(c.subject),
                                subtitle: Text(c.reason),
                                leading: const Icon(Icons.warning,
                                    color: Colors.red),
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
                                title: Text(b),
                                leading: const Icon(Icons.block),
                              )),
                          const Divider(),
                        ],
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Trusted Nodes',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ..._graph!.distances.entries.map((e) => ListTile(
                              title: Text(e.key),
                              subtitle: Text('Distance: ${e.value}'),
                              leading: const Icon(Icons.check_circle,
                                  color: Colors.green),
                            )),
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
