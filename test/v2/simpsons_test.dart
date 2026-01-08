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
import 'package:nerdster/app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoIdentityKey.reset();
    DemoDelegateKey.reset();
  });

  test('Simpsons Demo: Millhouse PoV', () async {
    await simpsonsDemo();
    
    final milhouse = DemoIdentityKey.findByName('milhouse')!;
    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(milhouse.id);
    
    final homer = DemoIdentityKey.findByName('homer')!;
    final homer2 = DemoIdentityKey.findByName('homer2')!;
    final lisa = DemoIdentityKey.findByName('lisa')!;

    final labeler = V2Labeler(graph);

    expect(graph.isTrusted(homer.id), isTrue);
    
    // Verify that Homer and Homer2 have distinct labels
    final label1 = labeler.getLabel(homer.token);
    final label2 = labeler.getLabel(homer2.token);
    
    expect(label1 != label2, isTrue, reason: 'Old and new keys should have distinct labels');
    expect(label1, contains('Homer'));
    expect(label2, contains('Homer'));
  });

  test('Simpsons Demo: Lisa PoV', () async {
    await simpsonsDemo();
    
    final lisa = DemoIdentityKey.findByName('lisa')!;
    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(lisa.id);
    final labeler = V2Labeler(graph);

    // PoV should be "Lisa" because Marge (and others) name her "Lisa" in the graph.
    expect(labeler.getLabel(lisa.token), 'Lisa');
    
    expect(labeler.getLabel(DemoIdentityKey.findByName('marge')!.token), 'Mom');
    expect(labeler.getLabel(DemoIdentityKey.findByName('homer2')!.token), 'Homer');
  });

  test('Simpsons Demo: Bart PoV', () async {
    await simpsonsDemo();
    
    final bart = DemoIdentityKey.findByName('bart')!;
    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(bart.id);
    final labeler = V2Labeler(graph);

    expect(labeler.getLabel(bart.token), 'Bart');
    expect(labeler.getLabel(DemoIdentityKey.findByName('lisa')!.token), 'Sis');
    
    final homer = DemoIdentityKey.findByName('homer')!;
    final homer2 = DemoIdentityKey.findByName('homer2')!;
    
    // Homer2 is canonical, so it gets the clean name.
    // Homer is old, so it gets (Old).
    expect(labeler.getLabel(homer2.token), 'Homer');
    expect(labeler.getLabel(homer.token), "Homer'");
  });
}
