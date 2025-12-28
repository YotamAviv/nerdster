import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/fire_choice.dart';
import 'simpsons_data_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore nerdsterFire;
  late FakeFirebaseFirestore oneofusFire;
  late V2FeedController controller;

  setUp(() async {
    fireChoice = FireChoice.fake;
    nerdsterFire = FakeFirebaseFirestore();
    oneofusFire = FakeFirebaseFirestore();

    // Initialize Statements BEFORE populating data
    TrustStatement.init();
    ContentStatement.init();

    await SimpsonsDataHelper.populate(nerdsterFire, oneofusFire);

    controller = V2FeedController(
      trustSource: DirectFirestoreSource<TrustStatement>(oneofusFire),
      identityContentSource: DirectFirestoreSource<ContentStatement>(oneofusFire),
      appContentSource: DirectFirestoreSource<ContentStatement>(nerdsterFire),
    );
  });

  test('Lisa feed should have expected names and content', () async {
    final lisaToken = DemoKey.findByName('lisa')!.token;
    await controller.refresh(lisaToken);

    expect(controller.error, isNull);
    expect(controller.value, isNotNull);

    final model = controller.value!;
    final labeler = model.labeler;

    // Verify some names from Simpsons data
    // We need to know what's in demoData.js to make specific assertions.
    // Based on previous logs, we saw "Secretariat", "Buck", etc.
    
    expect(model.aggregation.statements, isNotEmpty);
    print('Found ${model.aggregation.statements.length} statements');

    for (final s in model.aggregation.statements) {
      final authorName = labeler.getLabel(s.iToken);
      print('Statement by $authorName: ${s.comment ?? s.verb}');
    }

    // Verify some specific labels from Lisa's perspective
    final homerToken = DemoKey.findByName('homer')!.token;
    final homer2Token = DemoKey.findByName('homer2')!.token;
    final margeToken = DemoKey.findByName('marge')!.token;
    
    // Homer was replaced by Homer2, so Homer is "dad'" and Homer2 is "dad"
    expect(labeler.getLabel(homerToken), equals("dad'"));
    expect(labeler.getLabel(homer2Token), equals('dad'));
    expect(labeler.getLabel(margeToken), equals('mom'));
  });
}
