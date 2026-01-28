import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:oneofus_common/fire_factory.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/logic/content_pipeline.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/logic/trust_pipeline.dart';
import 'package:nerdster/demotest/test_util.dart';

// Scenario:
// 1. Run simpsonsDemo
// 2. Sign in as Lisa.
// 3. User Bart's PoV and <nerdster> context (where Lisa is blocked by Bart).
// 4. Lisa follows Bart for 'family'.
// 5. Verify that Lisa's follow of Bart is available in myLiteralStatements even if Bart is not a "subject" in the aggregation.

Future<(DemoIdentityKey, DemoDelegateKey)> followNotInNetwork() async {
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
    final labeler = Labeler(graph, delegateResolver: delegateResolver, meIdentity: meIdentity);

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
    final agg = await runPipeline(
        pov: bart.id, meIdentity: lisa.id, meDelegate: lisaN.id, context: context);

    final bartKey = ContentKey(bart.id.value);

    // Verify Bart is in myLiteralStatements
    final myStmts = agg.myLiteralStatements[bartKey];
    check(myStmts != null && myStmts.isNotEmpty, 'Bart NOT found in Lisa\'s myLiteralStatements');

    final hasFollow = myStmts!
        .any((s) => s.verb == ContentVerb.follow && s.contexts?.containsKey('family') == true);
    check(hasFollow,
        'Lisa\'s follow of Bart for family in myLiteralStatements: false (Expected: true)');

    // Verify if Bart is a "subject" in the aggregation
    // If he's not rated/related, he might NOT be a subject.
    final bartAsSubject = agg.subjects[bartKey];
    check(bartAsSubject == null,
        'Bart was found as subject in aggregation (Expected: null because he is blocked by Bart in nerdster context)');
  }

  return (lisa, lisaN);
}
