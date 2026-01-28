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
// - Run simpsonsDemo
/*
I'm signed in as lisa.
I use the <identity> follow context
I turn off censorship, and then I see Superbad (WORKING CORRECTLY)
I rate it with comment, "lisa" 
I see that I rated it (the rate icon on it is blue) (WORKING CORRECTLY)
I see my rating listed as staetments made about it. (WORKING CORRECTLY)

I switch to Bart's PoV
(still using the <identity> follow context)
I see Lisa's rating (WORKING CORRECTLY)
I see that I (Lisa the signed in identity) rated it  (the rate icon on it is blue) (WORKING CORRECTLY)
I switch to the <nerdster> context (where Bart has blocked Lisa) 
I don't see Lisa's rating statement (WORKING CORRECTLY)
I don't see that I (Lisa the signed in identity) rated it (icon not blue) (BUG!)
I click on that icon to rate it and don't see my previous rating (BUG!)



Censorship shouldn't matter, and when I run this in the  UI, I can toggle censorship off and on .
When I'm viewing as Lisa, Superbad appears and disappears
When I'm viewing as Bart,  Superbad is always there.

BUG in how this test does it:
Bart's PoV shouldn't by Marge when using the <nerdster> context.
But this works fine in the UI.

BUG in the UI:
Lisa doesn't see her own delegate's rating when using Bart's PoV.
*/
Future<(DemoIdentityKey, DemoDelegateKey)> rateWhenNotInNetwork() async {
  // 1. Run Base Demo
  await simpsonsDemo();

  final lisa = await DemoIdentityKey.findOrCreate('lisa');
  final bart = await DemoIdentityKey.findOrCreate('bart');

  // simpsonsDemo creates delegates predictably: name + "-nerdster0"
  // See `makeDelegate` in demo_key.dart
  final lisaN = await DemoDelegateKey.findOrCreate('lisa-nerdster0');
  final bartN = await DemoDelegateKey.findOrCreate('bart-nerdster0');

  // Sign in as Lisa (This is important)
  await signInState.signIn(lisa.token, lisaN.keyPair);

  // 2. (Bart has blocked Lisa in <nerdster> Context Already)

  // 3. Lisa Rates Superbad
  // In `simpsonsDemo` Lisa does NOT rate Superbad.
  // We need to do that here.
  const Json superbad = {'contentType': 'movie', 'title': "Superbad", 'year': '2007'};

  await lisaN.doRate(subject: superbad, comment: "lisa");

  // --- REGRESSION VERIFICATION LOGIC ---

  Future<ContentAggregation> runPipeline({
    required IdentityKey pov,
    required DelegateKey meDelegate,
    required String context,
    required bool enableCensorship,
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
    // We must fetch content FIRST to determine the Follow Network (because blocks/follows are content)
    // Fetch delegates in graph + ME (Lisa)
    final Set<DelegateKey> delegateKeysToFetch = {};
    for (final identity in graph.orderedKeys) {
      delegateKeysToFetch.addAll(delegateResolver.getDelegatesForIdentity(identity));
    }
    // We must manually add Me's delegate locally
    delegateKeysToFetch.add(meDelegate);

    final delegateContent = await contentPipeline.fetchDelegateContent(
      delegateKeysToFetch,
      delegateResolver: delegateResolver,
      graph: graph,
    );
    final contentResult = ContentResult(delegateContent: delegateContent);

    // Build Follow Network (Using the fetched content to respect blocks)
    final followNetwork = reduceFollowNetwork(graph, delegateResolver, contentResult, context);

    // Reduce Aggregation
    final labeler = Labeler(
      graph,
      delegateResolver: delegateResolver,
      meIdentity: delegateResolver.getIdentityForDelegate(meDelegate),
    );
    return reduceContentAggregation(
      followNetwork,
      graph,
      delegateResolver,
      contentResult,
      enableCensorship: enableCensorship,
      meDelegateKeys: [meDelegate],
      labeler: labeler,
    );
  }

  // 1. Lisa PoV (Identity Context) - Censorship OFF
  // "I turn off censorship, and then I see Superbad"
  // "I see my rating listed as statements made about it."
  {
    final agg = await runPipeline(
      pov: lisa.id,
      meDelegate: lisaN.id,
      context: kFollowContextIdentity,
      enableCensorship: false,
    );

    final subject = agg.subjects.values.where((s) => s.subject['title'] == 'Superbad').firstOrNull;

    check(subject != null, 'Superbad found: NO (Critical Failure)');

    final myStatements = subject!.statements.where((s) => s.iToken == lisaN.id.value);
    check(myStatements.isNotEmpty,
        'Lisa\'s statements in feed: ${myStatements.length} (Expected: >0)');

    final myOverlay =
        agg.myLiteralStatements[subject.token]?.where((s) => s.iToken == lisaN.id.value) ?? [];
    check(myOverlay.isNotEmpty, 'Lisa\'s overlay status (Blue Star): false (Expected: true)');
  }

  // 2. Bart's PoV (Identity Context)
  // "I see Lisa's rating"
  // "I see that I (Lisa) rated it"
  {
    signInState.pov = bart.id.value; // Switch PoV to Bart

    final agg = await runPipeline(
      pov: bart.id,
      meDelegate: lisaN.id, // Lisa is signed in
      context: kFollowContextIdentity,
      enableCensorship: false,
    );

    final subject = agg.subjects.values.where((s) => s.subject['title'] == 'Superbad').firstOrNull;

    check(subject != null, 'Superbad found: NO (Critical Failure)');

    final lisaInFeed = subject!.statements.where((s) => s.iToken == lisaN.id.value);
    check(lisaInFeed.isNotEmpty, 'Lisa\'s statements in feed: ${lisaInFeed.length} (Expected: >0)');

    final myOverlay =
        agg.myLiteralStatements[subject.token]?.where((s) => s.iToken == lisaN.id.value) ?? [];
    check(myOverlay.isNotEmpty, 'Lisa\'s overlay status (Blue Star): false (Expected: true)');
  }

  // 3. Use Bart's PoV, set follow context to <nerdster> (where Lisa is blocked)
  // "I don't see Lisa's rating statement (correct)"
  // "I don't see that I (Lisa) rated it (icon not blue, BUG)"
  {
    final agg = await runPipeline(
      pov: bart.id,
      meDelegate: lisaN.id, // Lisa is signed in
      context: kFollowContextNerdster,
      // Bart has blocked Marge for <nerdster> (seen in simpsons_demo.dart).
      // Since we correctly fetch content before building FollowNetwork, Marge is excluded.
      // Therefore, her censorship of Superbad does not apply.
      // Superbad should be visible even with censorship enabled.
      enableCensorship: true,
    );

    final subject = agg.subjects.values.where((s) => s.subject['title'] == 'Superbad').firstOrNull;

    check(subject != null, 'Superbad found: NO (Critical Failure)');

    final lisaInFeed = subject!.statements.where((s) => s.iToken == lisaN.id.value);
    check(lisaInFeed.isEmpty, 'Lisa\'s statements in feed: ${lisaInFeed.length} (Expected: 0)');

    final myOverlay =
        agg.myLiteralStatements[subject.token]?.where((s) => s.iToken == lisaN.id.value) ?? [];
    check(myOverlay.isNotEmpty, 'Lisa\'s overlay status (Blue Star): false (Expected: true)');

    // Verify RateDialog data availability
    // Since Lisa is blocked, Secretariat might not be in agg.subjects,
    // but it MUST be in agg.myLiteralStatements.
    final matches = agg.myLiteralStatements.entries.where(
      (e) => e.value.any((s) => s.subject is Map && s.subject['title'] == 'Secretariat'),
    );
    check(matches.isNotEmpty, 'Secretariat not found in myLiteralStatements');

    MapEntry<ContentKey, List<ContentStatement>> secretariatEntry = matches.first;
    List<ContentStatement> myLiteralStatements = secretariatEntry.value;
    bool hasMyRating =
        myLiteralStatements.any((s) => s.iToken == lisaN.id.value && s.verb == ContentVerb.rate);
    check(hasMyRating, 'RateDialog Data Available: false (Expected: true)');
  }

  return (lisa, lisaN);
}
