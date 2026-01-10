import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/orchestrator.dart';

// Scenario:
// 1. Run simpsonsDemo
// 2. Sign in as Lisa.
// 3. User Bart's PoV and <nerdster> context (where Lisa is blocked by Bart).
// 4. Lisa follows Bart for 'family'.
// 5. Verify that Lisa's follow of Bart is available in myLiteralStatements even if Bart is not a "subject" in the aggregation.

Future<(DemoIdentityKey, DemoDelegateKey)>
    followNotInNetwork() async {
  // 1. Run Base Demo
  await simpsonsDemo();

  final lisa = await DemoIdentityKey.findOrCreate('lisa');
  final bart = await DemoIdentityKey.findOrCreate('bart');

  final lisaN = await DemoDelegateKey.findOrCreate('lisa-nerdster0');

  // Sign in as Lisa
  await signInState.signIn(lisa.token, lisaN.keyPair);

  // 4. Lisa follows Bart for 'family'
  await lisaN.doFollow(bart.id, {'family': 1});

  // --- REGRESSION VERIFICATION LOGIC ---
  print('Starting Verification Check for Follow Not In Network...');

  Future<ContentAggregation> runPipeline({
    required IdentityKey pov,
    required IdentityKey meIdentity,
    required DelegateKey meDelegate,
    required String context,
  }) async {
    final trustSource = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final trustPipeline = TrustPipeline(trustSource);

    // Build Trust Graph
    final graph = await trustPipeline.build(pov);
    final delegateResolver = DelegateResolver(graph);

    final appSource = DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final contentPipeline = ContentPipeline(
      delegateSource: appSource,
    );

    // Fetch Content
    final Set<DelegateKey> delegateKeysToFetch = {};
    for (final identity in graph.orderedKeys) {
      delegateKeysToFetch.addAll(delegateResolver.getDelegatesForIdentity(identity));
    }
    // Also fetch ME (Lisa)
    delegateKeysToFetch.addAll(delegateResolver.getDelegatesForIdentity(meIdentity));

    final delegateContent = await contentPipeline.fetchDelegateContent(
      delegateKeysToFetch,
      delegateResolver: delegateResolver,
      graph: graph,
    );
    final contentResult = ContentResult(delegateContent: delegateContent);

    // Labeler
    final labeler = V2Labeler(graph, delegateResolver: delegateResolver, meIdentity: meIdentity);

    // Follow Network
    final followNetwork = reduceFollowNetwork(
      graph,
      delegateResolver,
      contentResult,
      context,
    );

    return reduceContentAggregation(
      followNetwork,
      graph,
      delegateResolver,
      contentResult,
      meDelegateKeys: [meDelegate],
      labeler: labeler,
    );
  }

  {
    const String context = 'nerdster';
    final agg = await runPipeline(pov: bart.id, meIdentity: lisa.id, meDelegate: lisaN.id, context: context);
    
    final bartKey = ContentKey(bart.id.value);
    
    // Verify Bart is in myLiteralStatements
    final myStmts = agg.myLiteralStatements[bartKey];
    if (myStmts == null || myStmts.isEmpty) {
      print('FAILED: Bart NOT found in Lisa\'s myLiteralStatements');
    } else {
      final hasFollow = myStmts.any((s) => s.verb == ContentVerb.follow && s.contexts?.containsKey('family') == true);
      print('Lisa\'s follow of Bart for family in myLiteralStatements: $hasFollow (Expected: true)');
    }

    // Verify if Bart is a "subject" in the aggregation
    // If he's not rated/related, he might NOT be a subject.
    final bartAsSubject = agg.subjects[bartKey];
    print('Bart as subject in aggregation: ${bartAsSubject != null}');
  }

  return (lisa, lisaN);
}
