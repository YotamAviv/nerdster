import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/main.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoKey.reset();
  });

  test('Simpsons Demo: Millhouse PoV', () async {
    await simpsonsDemo();
    
    final milhouse = DemoKey.findByName('milhouse')!;
    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(milhouse.token);
    
    final homer = DemoKey.findByName('homer')!;
    final homer2 = DemoKey.findByName('homer2')!;
    final lisa = DemoKey.findByName('lisa')!;

    print('Lisa trusted: ${graph.isTrusted(lisa.token)} (dist: ${graph.distances[lisa.token]})');
    print('Homer trusted: ${graph.isTrusted(homer.token)} (dist: ${graph.distances[homer.token]})');
    print('Homer2 trusted: ${graph.isTrusted(homer2.token)} (dist: ${graph.distances[homer2.token]})');

    print('Edges to Homer2:');
    for (final issuer in graph.edges.keys) {
      for (final s in graph.edges[issuer]!) {
        if (s.subjectToken == homer2.token) {
          print('  - from ${DemoKey.findByToken(issuer)?.name} ($issuer) verb: ${s.verb}');
        }
      }
    }

    print('Edges to Homer:');
    for (final issuer in graph.edges.keys) {
      for (final s in graph.edges[issuer]!) {
        if (s.subjectToken == homer.token) {
          print('  - from ${DemoKey.findByToken(issuer)?.name} ($issuer) verb: ${s.verb}');
        }
      }
    }

    print('Trusted tokens: ${graph.distances.keys.length}');
    for (var t in graph.distances.keys) {
      final name = DemoKey.findByToken(t)?.name ?? 'unknown';
      print('  - $t ($name) (dist: ${graph.distances[t]})');
    }

    final labeler = V2Labeler(graph);
    
    print('Labels:');
    for (var t in graph.distances.keys) {
      print('  - $t: ${labeler.getLabel(t)}');
    }

    expect(graph.isTrusted(homer.token), isTrue);
    
    // Verify that Homer and Homer2 have distinct labels
    final label1 = labeler.getLabel(homer.token);
    final label2 = labeler.getLabel(homer2.token);
    
    expect(label1 != label2, isTrue, reason: 'Old and new keys should have distinct labels');
    expect(label1, contains('Homer'));
    expect(label2, contains('Homer'));
  });

  test('Simpsons Demo: Lisa PoV', () async {
    await simpsonsDemo();
    
    final lisa = DemoKey.findByName('lisa')!;
    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(lisa.token);
    final labeler = V2Labeler(graph);

    // Root should be "Lisa" because Marge (and others) name her "Lisa" in the graph.
    expect(labeler.getLabel(lisa.token), 'Lisa');
    
    expect(labeler.getLabel(DemoKey.findByName('marge')!.token), 'Mom');
    expect(labeler.getLabel(DemoKey.findByName('homer2')!.token), 'Homer');
  });

  test('Simpsons Demo: Bart PoV', () async {
    await simpsonsDemo();
    
    final bart = DemoKey.findByName('bart')!;
    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(bart.token);
    final labeler = V2Labeler(graph);

    expect(labeler.getLabel(bart.token), 'Bart');
    expect(labeler.getLabel(DemoKey.findByName('lisa')!.token), 'Sis');
    
    final homer = DemoKey.findByName('homer')!;
    final homer2 = DemoKey.findByName('homer2')!;
    
    // Homer2 is canonical, so it gets the clean name.
    // Homer is old, so it gets (Old).
    expect(labeler.getLabel(homer2.token), 'Homer');
    expect(labeler.getLabel(homer.token), "Homer'");
  });
}
