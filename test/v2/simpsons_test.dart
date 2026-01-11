import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);
  });

  test('Simpsons Demo: Millhouse PoV', () async {
    await simpsonsDemo();

    final DemoIdentityKey milhouse = DemoIdentityKey.findByName('milhouse')!;
    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final TrustGraph graph = await pipeline.build(milhouse.id);

    final DemoIdentityKey homer = DemoIdentityKey.findByName('homer')!;
    final DemoIdentityKey homer2 = DemoIdentityKey.findByName('homer2')!;

    final V2Labeler labeler = V2Labeler(graph);

    expect(graph.isTrusted(homer.id), isTrue);

    // Verify that Homer and Homer2 have distinct labels
    final String label1 = labeler.getIdentityLabel(homer.id);
    final String label2 = labeler.getIdentityLabel(homer2.id);

    expect(label1 != label2, isTrue, reason: 'Old and new keys should have distinct labels');
    expect(label1, contains('Homer'));
    expect(label2, contains('Homer'));
  });

  test('Simpsons Demo: Lisa PoV', () async {
    await simpsonsDemo();

    final DemoIdentityKey lisa = DemoIdentityKey.findByName('lisa')!;
    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final TrustGraph graph = await pipeline.build(lisa.id);
    final V2Labeler labeler = V2Labeler(graph);

    // PoV should be "Lisa" because Marge (and others) name her "Lisa" in the graph.
    expect(labeler.getIdentityLabel(lisa.id), 'Lisa');

    expect(labeler.getIdentityLabel(DemoIdentityKey.findByName('marge')!.id), 'Mom');
    expect(labeler.getIdentityLabel(DemoIdentityKey.findByName('homer2')!.id), 'Homer');
  });

  test('Simpsons Demo: Bart PoV', () async {
    await simpsonsDemo();

    final DemoIdentityKey bart = DemoIdentityKey.findByName('bart')!;
    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final TrustGraph graph = await pipeline.build(bart.id);
    final V2Labeler labeler = V2Labeler(graph);

    expect(labeler.getIdentityLabel(bart.id), 'Bart');
    expect(labeler.getIdentityLabel(DemoIdentityKey.findByName('lisa')!.id), 'Sis');

    final DemoIdentityKey homer = DemoIdentityKey.findByName('homer')!;
    final DemoIdentityKey homer2 = DemoIdentityKey.findByName('homer2')!;

    // Homer2 is canonical, so it gets the clean name.
    // Homer is old, so it gets (Old).
    expect(labeler.getIdentityLabel(homer2.id), 'Homer');
    expect(labeler.getIdentityLabel(homer.id), "Homer'");
  });
}
