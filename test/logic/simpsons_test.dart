import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/logic/trust_pipeline.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);
  });

  // Verifies that karennet.net (Marge/Luann's domain) trust statements are
  // fetched via the correct channel and blocks are applied in Lisa's PoV.
  // Uses separate Firestores per domain to match the production app layout.
  test('Federation: Marge on karennet blocks sideshow in Lisa PoV', () async {
    final FakeFirebaseFirestore nerdsterFs = FakeFirebaseFirestore();
    final FakeFirebaseFirestore oneofusFs = FakeFirebaseFirestore();
    final FakeFirebaseFirestore karenetFs = FakeFirebaseFirestore();

    channelFactory = ChannelFactory(FireChoice.fake);
    channelFactory.register('nerdster.org', firestore: nerdsterFs);
    channelFactory.register('one-of-us.net', firestore: oneofusFs);
    channelFactory.register('karennet.net', firestore: karenetFs);

    ContentStatement.init();
    DismissStatement.init();
    TrustStatement.init();
    ContentStatement.clearCache();
    DismissStatement.clearCache();
    TrustStatement.clearCache();
    Jsonish.wipeCache();
    FedKey.clearRegistry();
    useClock(TestClock());
    DemoKey.reset();

    await simpsonsDemo();

    final DemoIdentityKey lisa = DemoIdentityKey.findByName('lisa')!;
    final DemoIdentityKey marge = DemoIdentityKey.findByName('marge')!;
    final DemoIdentityKey sideshow = DemoIdentityKey.findByName('sideshow')!;

    final source = channelFactory.getChannel<TrustStatement>(kNativeUrl, 'statements');
    final TrustPipeline pipeline = TrustPipeline(
      source,
      channelFactory: channelFactory,
      maxDegrees: 6,
      pathRequirement: (d) => 1,
    );
    final TrustGraph graph = await pipeline.build(lisa.id);

    expect(graph.isTrusted(marge.id), isTrue,
        reason: 'Marge (karennet) should be in Lisa\'s trust network');
    expect(graph.isTrusted(sideshow.id), isFalse,
        reason: 'Sideshow should be blocked by Marge\'s karennet block statement');
  });

  test('Simpsons Demo: Millhouse PoV', () async {
    await simpsonsDemo();

    final DemoIdentityKey milhouse = DemoIdentityKey.findByName('milhouse')!;
    final source = channelFactory.getChannel<TrustStatement>(kNativeUrl, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final TrustGraph graph = await pipeline.build(milhouse.id);

    final DemoIdentityKey homer = DemoIdentityKey.findByName('homer')!;
    final DemoIdentityKey homer2 = DemoIdentityKey.findByName('homer2')!;

    final Labeler labeler = Labeler(graph);

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
    final source = channelFactory.getChannel<TrustStatement>(kNativeUrl, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final TrustGraph graph = await pipeline.build(lisa.id);
    final Labeler labeler = Labeler(graph);

    // PoV should be "Lisa" because Marge (and others) name her "Lisa" in the graph.
    expect(labeler.getIdentityLabel(lisa.id), 'Lisa');

    expect(labeler.getIdentityLabel(DemoIdentityKey.findByName('marge')!.id), 'Mom');
    expect(labeler.getIdentityLabel(DemoIdentityKey.findByName('homer2')!.id), 'Homer');
  });

  test('Simpsons Demo: Bart PoV', () async {
    await simpsonsDemo();

    final DemoIdentityKey bart = DemoIdentityKey.findByName('bart')!;
    final source = channelFactory.getChannel<TrustStatement>(kNativeUrl, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final TrustGraph graph = await pipeline.build(bart.id);
    final Labeler labeler = Labeler(graph);

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
