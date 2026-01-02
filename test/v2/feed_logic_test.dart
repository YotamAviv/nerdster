import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';

import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/setting_type.dart';


import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/singletons.dart';

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
      contentSource: DirectFirestoreSource<ContentStatement>(nerdsterFire),
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

  test('My delegate statements should be available in myDelegateStatements but not in main aggregation if not in PoV network', () async {
    // 1. Create Stranger and Me
    final stranger = await DemoKey.findOrCreate('stranger');
    final strangerDelegate = await stranger.makeDelegate();
    final me = await DemoKey.findOrCreate('me');
    final meDelegate = await me.makeDelegate();

    // 2. Stranger (via delegate) rates "Secretariat" (so it appears in the feed)
    await strangerDelegate.doRate(title: 'Secretariat', recommend: true);

    // 3. Me (via delegate) rates "Secretariat"
    await meDelegate.doRate(title: 'Secretariat', recommend: true, comment: 'I like horses');

    // 4. Sign in as Me
    final meKeyPair = await me.keyPair;
    final meDelegateKeyPair = await meDelegate.keyPair;
    await signInState.signIn(me.token, meDelegateKeyPair);

    // 5. Refresh with Stranger as PoV
    // Stranger does NOT trust Me, so Me is not in the trust graph.
    await controller.refresh(stranger.token, meToken: me.token);

    expect(controller.error, isNull);
    expect(controller.value, isNotNull);

    final model = controller.value!;
    
    // 6. Find Secretariat aggregation
    final secretariatAgg = model.aggregation.subjects.values.firstWhere((agg) => 
      agg.subject is Map && agg.subject['title'] == 'Secretariat'
    );
    
    // Main statements should NOT contain Me's rating
    final myRatingInMain = secretariatAgg.statements.where((s) => s.iToken == meDelegate.token);
    expect(myRatingInMain, isEmpty, reason: "Me's rating should NOT be in main aggregation");

    // myDelegateStatements should contain Me's rating
    final myRatingInMy = secretariatAgg.myDelegateStatements.where((s) => s.iToken == meDelegate.token);
    expect(myRatingInMy, isNotEmpty, reason: "Me's rating SHOULD be in myDelegateStatements");
    expect(myRatingInMy.first.comment, equals('I like horses'));
  });

  test('Rating a rating should not result in the rating appearing as a top-level subject', () async {
    // 1. Setup Viewer, Rater, Critic
    final viewer = await DemoKey.findOrCreate('viewer');
    final rater = await DemoKey.findOrCreate('rater');
    final raterDelegate = await rater.makeDelegate();
    final critic = await DemoKey.findOrCreate('critic');
    final criticDelegate = await critic.makeDelegate();

    // Viewer trusts Rater and Critic (Identities)
    await viewer.trust(rater, moniker: 'rater');
    await viewer.trust(critic, moniker: 'critic');

    // 2. Rater (via delegate) rates "Inception"
    final ratingStatement = await raterDelegate.doRate(title: 'Inception', recommend: true);
    final ratingToken = ratingStatement.token;

    // 3. Critic (via delegate) rates Rater's rating (e.g. dislikes it)
    await criticDelegate.doRate(subject: ratingToken, recommend: false, comment: 'Bad take');

    // 4. Refresh Viewer's feed
    await controller.refresh(viewer.token);

    expect(controller.error, isNull);
    final model = controller.value!;

    // 5. Verify "Inception" is a subject
    final inceptionAgg = model.aggregation.subjects.values.where((agg) => 
      agg.subject is Map && agg.subject['title'] == 'Inception'
    );
    expect(inceptionAgg, isNotEmpty, reason: "Inception should be in the feed");

    // 6. Verify the Rating Statement IS in the aggregation (for lookup)
    final ratingAsSubject = model.aggregation.subjects.values.where((agg) => 
      agg.token == ratingToken
    );
    expect(ratingAsSubject, isNotEmpty, reason: "The rating statement should be in the aggregation for lookup");

    // 7. Verify it is hidden from the feed
    final shouldShow = controller.shouldShow(ratingAsSubject.first, V2FilterMode.ignoreDisses, false);
    expect(shouldShow, isFalse, reason: "The rating statement should be hidden from the feed");
  });
}
