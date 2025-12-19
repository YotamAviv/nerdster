import 'dart:convert';
import 'dart:io';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:test/test.dart';

void main() {
  group('V2 Orchestrator', () {
    test('Builds graph from Lisa sample', () async {
      final file = File('test/v2/lisa_oneofus.json');
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final Map<String, dynamic> rawData = jsonDecode(jsonString);
      final rootKey = rawData.keys.first;

      // Setup Pipeline
      final source = MemorySource(rawData.cast<String, List<dynamic>>());
      final pipeline = TrustPipeline(source);

      // Run
      final graph = await pipeline.build(rootKey);

      // Verify
      print('Graph Root: ${graph.root}');
      print('Trusted Nodes: ${graph.distances.length}');
      print('Distances: ${graph.distances}');
      
      expect(graph.isTrusted(rootKey), isTrue);
      
      // In the sample data, Lisa delegates to another key.
      // Let's see if that key ended up in the graph.
      // (We can inspect the output to confirm).
    });
  });
}
