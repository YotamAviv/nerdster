import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';

import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';


import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/singletons.dart';

import 'simpsons_data_helper.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/most_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore nerdsterFire;
  late FakeFirebaseFirestore oneofusFire;
  late V2FeedController controller;

  setUp(() async {
    // Reset global state
    signInState.signOut(clearIdentity: true);
    
    fireChoice = FireChoice.fake;

    nerdsterFire = FakeFirebaseFirestore();
    oneofusFire = FakeFirebaseFirestore();

    // Initialize Statements BEFORE populating data
    TrustStatement.init();
    ContentStatement.init();

    await SimpsonsDataHelper.populate(nerdsterFire, oneofusFire);
    
    Setting.get<String>(SettingType.fcontext).value = 'family';

    controller = V2FeedController(
      trustSource: DirectFirestoreSource<TrustStatement>(oneofusFire),
      contentSource: DirectFirestoreSource<ContentStatement>(nerdsterFire),
    );
  });

  test('Lisa feed should have expected names and content', () async {
    final lisaToken = DemoIdentityKey.findByName('lisa')!.token;
    await controller.refresh(IdentityKey(lisaToken));

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
    final homerToken = DemoIdentityKey.findByName('homer')!.token;
    final homer2Token = DemoIdentityKey.findByName('homer2')!.token;
    final margeToken = DemoIdentityKey.findByName('marge')!.token;
    
    // Homer was replaced by Homer2, so Homer is "dad'" and Homer2 is "dad"
    expect(labeler.getLabel(homerToken), equals("dad'"));
    expect(labeler.getLabel(homer2Token), equals('dad'));
    expect(labeler.getLabel(margeToken), equals('mom'));
  });

  test('My delegate statements should be available in myDelegateStatements but not in main aggregation if not in PoV network', () async {
    // 1. Create Stranger and Me
    final stranger = await DemoIdentityKey.findOrCreate('stranger');
    final strangerDelegate = await stranger.makeDelegate();
    final me = await DemoIdentityKey.findOrCreate('me');
    final meDelegate = await me.makeDelegate();

    // 2. Stranger (via delegate) rates "Secretariat" (so it appears in the feed)
    await strangerDelegate.doRate(title: 'Secretariat', recommend: true);

    // 3. Me (via delegate) rates "Secretariat"
    await meDelegate.doRate(title: 'Secretariat', recommend: true, comment: 'I like horses');

    // 4. Sign in as Me
    await me.keyPair;
    final meDelegateKeyPair = await meDelegate.keyPair;
    await signInState.signIn(me.token, meDelegateKeyPair);

    // 5. Refresh with Stranger as PoV
    // Stranger does NOT trust Me, so Me is not in the trust graph.
    await controller.refresh(stranger.id, meIdentity: me.id);

    expect(controller.error, isNull);
    expect(controller.value, isNotNull);

    final model = controller.value!;
    
    // 6. Find Secretariat aggregation
    final secretariatAgg = model.aggregation.subjects.values.where((agg) => 
      agg.subject['title'] == 'Secretariat'
    ).firstOrNull;

    if (secretariatAgg != null) {
      // Main statements should NOT contain Me's rating
      final myRatingInMain = secretariatAgg.statements.where((s) => s.iToken == meDelegate.token);
      expect(myRatingInMain, isEmpty, reason: "Me's rating should NOT be in main aggregation");
      
      // main aggregation if not in PoV network
      final myLiteralStmts = model.aggregation.myLiteralStatements[secretariatAgg.token] ?? [];
      expect(myLiteralStmts, isNotEmpty, reason: "myLiteralStatements should be available for UI overlay even in Pure PoV");
    }

    // Check for My Statements in Global map
    final secretariatKey = model.aggregation.myLiteralStatements.keys.firstWhere(
      (k) => model.aggregation.myLiteralStatements[k]!.any((s) => (s.subject as Map)['title'] == 'Secretariat'),
    );
    final myLiteralStatements = model.aggregation.myLiteralStatements[secretariatKey] ?? [];
    expect(myLiteralStatements, isNotEmpty, reason: "Me's rating SHOULD be in aggregation.myLiteralStatements");
    expect(myLiteralStatements.first.comment, equals('I like horses'));
  });

  test('Rating a rating should not result in the rating appearing as a top-level subject', () async {
    // 1. Setup Viewer, Rater, Critic
    final viewer = await DemoIdentityKey.findOrCreate('viewer');
    final viewerDelegate = await viewer.makeDelegate(); // Viewer needs delegate to follow
    final rater = await DemoIdentityKey.findOrCreate('rater');
    final raterDelegate = await rater.makeDelegate();
    final critic = await DemoIdentityKey.findOrCreate('critic');
    final criticDelegate = await critic.makeDelegate();

    // Viewer trusts Rater and Critic (Identities)
    await viewer.trust(rater, moniker: 'rater');
    await viewer.trust(critic, moniker: 'critic');
    
    // Viewer follows Rater and Critic (Content) so their content appears in 'family' feed
    await viewerDelegate.doFollow(rater, {'family': 1});
    await viewerDelegate.doFollow(critic, {'family': 1});

    // 2. Rater (via delegate) rates "Inception"
    final ratingStatement = await raterDelegate.doRate(title: 'Inception', recommend: true);
    final ratingToken = ratingStatement.token;

    // 3. Critic (via delegate) rates Rater's rating (e.g. dislikes it)
    await criticDelegate.doRate(subject: ratingToken, recommend: false, comment: 'Bad take');

    // 4. Refresh Viewer's feed
    await controller.refresh(viewer.id);

    expect(controller.error, isNull);
    final model = controller.value!;

    // 5. Verify "Inception" is a subject
    final inceptionAgg = model.aggregation.subjects.values.where((agg) => 
      agg.subject['title'] == 'Inception'
    );
    expect(inceptionAgg, isNotEmpty, reason: "Inception should be in the feed");
    


    // 6. Verify the Rating Statement IS in the aggregation (for lookup)
    final ratingAsSubject = model.aggregation.subjects.values.where((agg) => 
      agg.canonical == ratingToken
    );
    expect(ratingAsSubject, isEmpty, reason: "The rating statement should not be in the aggregation for lookup");
  });

  test('My delegate statements should be fetched even if I am not in the PoV graph and not signed in with that delegate', () async {
    // 1. Create Stranger and Me
    final DemoIdentityKey stranger = await DemoIdentityKey.findOrCreate('stranger');
    final DemoIdentityKey me = await DemoIdentityKey.findOrCreate('me');
    final DemoDelegateKey meDelegate = await me.makeDelegate();

    // 2. Me (via delegate) rates "Secretariat"
    await meDelegate.doRate(title: 'Secretariat', recommend: true, comment: 'I like horses');

    // 3. Sign in as Me (Identity ONLY, no delegate credential active)
    await signInState.signIn(me.token, null);

    // 4. Refresh with Stranger as PoV
    // Stranger does NOT trust Me.
    await controller.refresh(stranger.id, meIdentity: me.id);

    // Wait for controller to finish loading the requested PoV
    // (Because signIn triggered a refresh for 'Me', the explicit refresh call might have returned early)
    while (controller.value?.povIdentity != stranger.id || controller.loading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    expect(controller.error, isNull);
    final V2FeedModel model = controller.value!;
    

    // 5. Find Secretariat aggregation in the FEED result
    final secretariatInFeed = model.effectiveSubjects.where((agg) => 
      agg.subject['title'] == 'Secretariat'
    ).firstOrNull;

    expect(secretariatInFeed, isNull, reason: "Secretariat should NOT be in the feed for Stranger PoV");

    // Check for My Statements in Global map (might not be top-level in feed)
    final secretariatKey = model.aggregation.myLiteralStatements.keys.firstWhere(
      (k) => model.aggregation.myLiteralStatements[k]!.any((s) => (s.subject as Map)['title'] == 'Secretariat'),
    );
    final myLiteralStatements = model.aggregation.myLiteralStatements[secretariatKey] ?? [];
    
    expect(myLiteralStatements, isNotEmpty, reason: "Me's rating SHOULD be in aggregation.myLiteralStatements even if not in feed");
    expect(myLiteralStatements.first.comment, equals('I like horses'));
  });
}
