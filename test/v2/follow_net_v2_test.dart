import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  setUp(() async {
    useClock(TestClock());
    DemoKey.reset();
  });

  test('Simpsons Follow Network (V2)', () async {
    await simpsons();
    final DemoIdentityKey bart = DemoIdentityKey.findByName('bart')!;
    
    // 1. Build TrustGraph (Identity Layer)
    final Map<IdentityKey, List<TrustStatement>> allTrustStatements = {};
    for (final DemoIdentityKey dk in DemoIdentityKey.all) {
      allTrustStatements[dk.id] = dk.trustStatements;
    }

    final TrustGraph trustGraph = reduceTrustGraph(
      TrustGraph(pov: bart.id),
      allTrustStatements,
    );

    expect(trustGraph.isTrusted(bart.id), true);
    
    final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

    // 2. Build FollowNetwork for <nerdster> context
    final ContentResult allContentStatements = buildContentResult(DemoDelegateKey.all);

    final FollowNetwork followNet = reduceFollowNetwork(
      trustGraph,
      delegateResolver,
      allContentStatements,
      kFollowContextNerdster, // Using the standard <nerdster> follow context
    );

    // Bart should be in the network
    expect(followNet.contains(bart.id), true);
    expect(followNet.povIdentity, bart.token);
    
    // Check some other Simpsons
    final DemoIdentityKey homer = DemoIdentityKey.findByName('homer')!;
    final DemoIdentityKey lisa = DemoIdentityKey.findByName('lisa')!;
    
    expect(followNet.contains(trustGraph.resolveIdentity(homer.id)), true);
    // Lisa is blocked in <nerdster> context by Bart
    expect(followNet.contains(trustGraph.resolveIdentity(lisa.id)), false);
    
    // Check order (discovery order)
    expect(followNet.identities.indexOf(bart.id), 0);
    expect(followNet.identities.indexOf(trustGraph.resolveIdentity(homer.id)), greaterThan(0));
  });

  test('Simpsons Demo: Multi-POV Content Verification', () async {
    await simpsons();
    
    final DemoIdentityKey bart = DemoIdentityKey.findByName('bart')!;
    final DemoIdentityKey lisa = DemoIdentityKey.findByName('lisa')!;
    final DemoIdentityKey homer = DemoIdentityKey.findByName('homer')!;
    final DemoIdentityKey homer2 = DemoIdentityKey.findByName('homer2')!;
    final DemoIdentityKey marge = DemoIdentityKey.findByName('marge')!;

    final Map<IdentityKey, List<TrustStatement>> allTrustStatements = {};
    for (final DemoIdentityKey dk in DemoIdentityKey.all) {
      allTrustStatements[dk.id] = dk.trustStatements;
    }
    final ContentResult allContentStatements = buildContentResult(DemoDelegateKey.all);

    final DemoDelegateKey margeN = DemoDelegateKey.findByName('marge-nerdster0')!;
    final ContentStatement margeRating = margeN.contentStatements.firstWhere((s) => s.verb == ContentVerb.rate);

    // --- LISA'S POV ---
    final TrustGraph trustLisa = reduceTrustGraph(TrustGraph(pov: lisa.id), allTrustStatements);
    final DelegateResolver delegatesLisa = DelegateResolver(trustLisa);
    
    final FollowNetwork followLisa = reduceFollowNetwork(trustLisa, delegatesLisa, allContentStatements, kFollowContextNerdster);
    final ContentAggregation contentLisa = reduceContentAggregation(
        followLisa, trustLisa, delegatesLisa, allContentStatements,
        labeler: V2Labeler(trustLisa, delegateResolver: delegatesLisa));

    // Lisa should see content from Marge and Homer2
    expect(followLisa.contains(trustLisa.resolveIdentity(marge.id)), true, reason: 'Lisa should follow Marge');
    expect(followLisa.contains(trustLisa.resolveIdentity(homer.id)), true, reason: 'Lisa should follow Homer (Homer2)');
    
    // Check if Marge's content is there (MargeN signed it)
    expect(contentLisa.subjects.values.any((s) => s.canonical == ContentKey(margeRating.subjectToken!)), true, reason: "Lisa should see Marge's content");

    // --- BART'S POV ---
    final TrustGraph trustBart = reduceTrustGraph(TrustGraph(pov: bart.id), allTrustStatements);
    final DelegateResolver delegatesBart = DelegateResolver(trustBart);
    final FollowNetwork followBart = reduceFollowNetwork(trustBart, delegatesBart, allContentStatements, kFollowContextNerdster);
    reduceContentAggregation(followBart, trustBart, delegatesBart, allContentStatements,
        labeler: V2Labeler(trustBart, delegateResolver: delegatesBart));

    // Bart blocks Lisa in <nerdster> context in simpsons.dart
    expect(followBart.contains(trustBart.resolveIdentity(lisa.id)), false,
        reason: 'Bart blocks Lisa');

    // --- HOMER'S POV (Homer2) ---
    final TrustGraph trustHomer =
        reduceTrustGraph(TrustGraph(pov: homer2.id), allTrustStatements);
    final DelegateResolver delegatesHomer = DelegateResolver(trustHomer);
    final FollowNetwork followHomer = reduceFollowNetwork(
        trustHomer, delegatesHomer, allContentStatements, kFollowContextNerdster);
    reduceContentAggregation(followHomer, trustHomer, delegatesHomer, allContentStatements,
        labeler: V2Labeler(trustHomer, delegateResolver: delegatesHomer));

    expect(followHomer.contains(trustHomer.resolveIdentity(lisa.id)), true, reason: 'Homer2 should follow Lisa');
  });

  test('Custom Context Filtering (V2)', () async {
    await simpsons();
    final DemoIdentityKey bart = DemoIdentityKey.findByName('bart')!;
    
    final Map<IdentityKey, List<TrustStatement>> allTrustStatements = {};
    for (final DemoIdentityKey dk in DemoIdentityKey.all) {
      allTrustStatements[dk.id] = dk.trustStatements;
    }

    final TrustGraph trustGraph = reduceTrustGraph(
      TrustGraph(pov: bart.id),
      allTrustStatements,
    );

    final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

    final ContentResult allContentStatements = buildContentResult(DemoDelegateKey.all);

    // 'family' is a custom follow context used in the Simpsons demo data
    final FollowNetwork familyNet = reduceFollowNetwork(
      trustGraph,
      delegateResolver,
      allContentStatements,
      'family',
    );

    final DemoIdentityKey homer = DemoIdentityKey.findByName('homer')!;
    final DemoIdentityKey marge = DemoIdentityKey.findByName('marge')!;
    final DemoIdentityKey milhouse = DemoIdentityKey.findByName('milhouse')!;
    final DemoIdentityKey lisa = DemoIdentityKey.findByName('lisa')!;

    expect(familyNet.contains(bart.id), true);
    expect(familyNet.povIdentity, bart.token);
    
    expect(familyNet.contains(trustGraph.resolveIdentity(homer.id)), true);
    expect(familyNet.contains(trustGraph.resolveIdentity(marge.id)), true);
    expect(familyNet.contains(trustGraph.resolveIdentity(lisa.id)), true);
    // Milhouse is not family
    expect(familyNet.contains(trustGraph.resolveIdentity(milhouse.id)), false);
  });

  test('V2 Content Aggregation: Censorship and Equivalence', () async {
    final DemoIdentityKey homer = await DemoIdentityKey.create('homer');
    final DemoIdentityKey bart = await DemoIdentityKey.create('bart');
    final DemoIdentityKey lisa = await DemoIdentityKey.create('lisa');

    final DemoDelegateKey homerN = await homer.makeDelegate();
    final DemoDelegateKey bartN = await bart.makeDelegate();
    final DemoDelegateKey lisaN = await lisa.makeDelegate();

    final Json news1 = {'contentType': 'url', 'url': 'https://news.com/1'};
    final Json news2 = {'contentType': 'url', 'url': 'https://news.com/2'};
    final Json spam = {'contentType': 'url', 'url': 'https://spam.com'};

    final String news1Token = getToken(news1);
    final String news2Token = getToken(news2);
    final String spamToken = getToken(spam);

    await homer.trust(lisa, moniker: 'lisa');
    await homer.trust(bart, moniker: 'bart');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: homer.id), {
      homer.id: homer.trustStatements,
      bart.id: bart.trustStatements,
      lisa.id: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Bart rates news1 and news2
    await bartN.doRate(subject: news1, recommend: true);
    await bartN.doRate(subject: news2, recommend: true);

    // Lisa also censors spam
    await lisaN.doRate(subject: spam, censor: true);

    final ContentResult allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final FollowNetwork followNet = reduceFollowNetwork(
      graph,
      delegateResolver,
      allStatementsByToken,
      kFollowContextNerdster,
    );

    // 3. Content Aggregation
    // Equate news1 and news2
    await bartN.doRelate(ContentVerb.equate, subject: news1, other: news2);
    // Rate news1
    await bartN.doRate(subject: news1, recommend: true);
    // Lisa rates spam (but she also censored it)
    await lisaN.doRate(subject: spam, dismiss: true);

    final ContentAggregation contentAgg = reduceContentAggregation(
      followNet,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // Spam should be censored
    expect(contentAgg.censored, contains(ContentKey(spamToken)));
    // news1 and news2 should be equated
    expect(contentAgg.equivalence[ContentKey(news2Token)], contentAgg.equivalence[ContentKey(news1Token)]);
  });

  test('V2 Content Aggregation: Censorship Overrides', () async {
    final DemoIdentityKey homer = await DemoIdentityKey.create('homer');
    final DemoIdentityKey bart = await DemoIdentityKey.create('bart');
    final DemoIdentityKey lisa = await DemoIdentityKey.create('lisa');

    final DemoDelegateKey homerN = await homer.makeDelegate();
    final DemoDelegateKey bartN = await bart.makeDelegate();
    final DemoDelegateKey lisaN = await lisa.makeDelegate();

    // Lisa is more trusted than Bart
    await homer.trust(bart, moniker: 'bart');
    await homer.trust(lisa, moniker: 'lisa');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: homer.id), {
      homer.id: homer.trustStatements,
      bart.id: bart.trustStatements,
      lisa.id: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Homer follows Bart and Lisa
    await homerN.doFollow(bart.token, {'news': 1});
    await homerN.doFollow(lisa.token, {'news': 1});
    
    var allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, 'news');

    // 1. Bart rates a spam URL
    final Json spamMap = {'contentType': 'url', 'url': 'https://spam.com'};
    final String spamToken = getToken(spamMap);
    final ContentStatement spamRate = await bartN.doRate(subject: spamMap, recommend: true);
    
    // 2. Lisa censors Bart's rating statement
    await lisaN.doRate(subject: spamRate.token, censor: true);

    // 3. Homer also rates the spam URL (he likes it)
    final ContentStatement homerRate = await homerN.doRate(subject: spamMap, recommend: true);

    // Rebuild map to include new statements
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // Lisa censored Bart's statement, so Bart's rating should be gone.
    // But the URL itself was NOT censored, so Homer's rating should remain.
    expect(aggregation.censored, contains(spamRate.token));
    expect(aggregation.censored, isNot(contains(spamToken)));
    
    final Set<String> remainingTokens = aggregation.statements.map((s) => s.token).toSet();
    expect(remainingTokens, contains(homerRate.token));
    expect(remainingTokens, isNot(contains(spamRate.token)));

    // 4. Now Bart censors the URL itself
    final ContentStatement bartCensorship = await bartN.doRate(subject: spamMap, censor: true);
    
    // Rebuild map again
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation2 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // 5. Lisa censors Bart's censorship statement
    await lisaN.doRate(subject: bartCensorship.token, censor: true);

    // Rebuild map again
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation3 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // Lisa is more trusted than Bart.
    // Lisa censored Bart's censorship of the URL.
    // So the URL should NOT be censored anymore.
    expect(aggregation3.censored, contains(bartCensorship.token));
    expect(aggregation3.censored, isNot(contains(spamToken)));
    expect(aggregation3.statements.map((s) => s.token), contains(homerRate.token));
  });

  test('V2 Follow Network: Delegate Resolution', () async {
    final DemoIdentityKey homer = await DemoIdentityKey.create('homer');
    final DemoIdentityKey bart = await DemoIdentityKey.create('bart');
    final DemoDelegateKey bartDelegate = await DemoDelegateKey.create('bart-delegate');

    final DemoDelegateKey homerN = await homer.makeDelegate();

    // 1. Homer trusts Bart
    await homer.trust(bart, moniker: 'bart');

    final Map<IdentityKey, List<TrustStatement>> trustStatements = {
      homer.id: homer.trustStatements,
      bart.id: [await bart.delegate(bartDelegate, domain: kNerdsterDomain)],
    };

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: homer.id), trustStatements);
    expect(graph.isTrusted(bart.id), isTrue);
    expect(graph.isTrusted(IdentityKey(bartDelegate.token)), isFalse); // Delegate is not in WoT

    final DelegateResolver delegateResolver = DelegateResolver(graph);
    // In the lazy resolver, we must resolve the identity to see its delegates
    expect(delegateResolver.getDelegatesForIdentity(bart.id), contains(bartDelegate.id));
    expect(delegateResolver.getIdentityForDelegate(bartDelegate.id), bart.id);

    // 2. Homer follows Bart in 'news-context'
    const String newsContext = 'news-context';
    await homerN.doFollow(bart.token, {newsContext: 1});

    // Bart's delegate signs a content statement
    final Json newsMap = {'contentType': 'url', 'url': 'https://news.com/1'};
    final String newsToken = getToken(newsMap);
    await bartDelegate.doRate(subject: newsMap, recommend: true);

    final ContentResult allStatementsByToken = buildContentResult([homer, homerN, bart, bartDelegate].where((k) => k.isDelegate));

    final FollowNetwork network = reduceFollowNetwork(
      graph,
      delegateResolver,
      allStatementsByToken,
      newsContext,
    );

    // Homer should follow Bart
    expect(network.identities, contains(bart.token));
    expect(network.povIdentity, homer.token);
    
    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // Bart's delegate's statement should be included
    expect(aggregation.statements.any((s) => s.subjectToken == newsToken), isTrue);
  });

  test('V2 Content Aggregation: Proximity-Based Censorship (Censor-the-Censor)', () async {
    final DemoIdentityKey homer = await DemoIdentityKey.create('homer');
    final DemoIdentityKey bart = await DemoIdentityKey.create('bart');
    final DemoIdentityKey lisa = await DemoIdentityKey.create('lisa');

    final DemoDelegateKey homerN = await homer.makeDelegate();
    final DemoDelegateKey bartN = await bart.makeDelegate();
    final DemoDelegateKey lisaN = await lisa.makeDelegate();

    await homer.trust(bart, moniker: 'bart');
    await homer.trust(lisa, moniker: 'lisa');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: homer.id), {
      homer.id: homer.trustStatements,
      bart.id: bart.trustStatements,
      lisa.id: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Homer follows Bart and Lisa
    await homerN.doFollow(bart.token, {'news': 1});
    await homerN.doFollow(lisa.token, {'news': 1});
    
    var allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, 'news');

    // 1. Bart rates a spam URL
    final Json spamMap = {'contentType': 'url', 'url': 'https://spam.com'};
    final String spamToken = getToken(spamMap);
    final ContentStatement spamRate = await bartN.doRate(subject: spamMap, recommend: true);
    
    // 2. Lisa censors Bart's rating statement
    await lisaN.doRate(subject: spamRate.token, censor: true);

    // 3. Homer also rates the spam URL (he likes it)
    final ContentStatement homerRate = await homerN.doRate(subject: spamMap, recommend: true);

    // Rebuild map
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // Lisa censored Bart's statement, so Bart's rating should be gone.
    expect(aggregation.censored, contains(spamRate.token));
    expect(aggregation.censored, isNot(contains(spamToken)));
    
    final Set<String> remainingTokens = aggregation.statements.map((s) => s.token).toSet();
    expect(remainingTokens, contains(homerRate.token));
    expect(remainingTokens, isNot(contains(spamRate.token)));

    // 4. Now Bart censors the URL itself
    final ContentStatement bartCensorship = await bartN.doRate(subject: spamMap, censor: true);
    
    // Rebuild map
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation2 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // Now the URL is censored by Bart.
    expect(aggregation2.censored, contains(spamToken));

    // 5. Lisa censors Bart's censorship statement
    await lisaN.doRate(subject: bartCensorship.token, censor: true);

    // Rebuild map
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation3 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // Lisa censored Bart's censorship of the URL.
    // So the URL should NOT be censored anymore.
    expect(aggregation3.censored, contains(bartCensorship.token));
    expect(aggregation3.censored, isNot(contains(spamToken)));
    expect(aggregation3.statements.map((s) => s.token), contains(homerRate.token));
  });

  test('Censoring Relate and Equate Statements (V2)', () async {
    final DemoIdentityKey homer = await DemoIdentityKey.create('homer');
    final DemoIdentityKey bart = await DemoIdentityKey.create('bart');
    final DemoIdentityKey lisa = await DemoIdentityKey.create('lisa');

    final DemoDelegateKey homerN = await homer.makeDelegate();
    final DemoDelegateKey bartN = await bart.makeDelegate();
    final DemoDelegateKey lisaN = await lisa.makeDelegate();

    await homer.trust(bart, moniker: 'bart');
    await homer.trust(lisa, moniker: 'lisa');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: homer.id), {
      homer.id: homer.trustStatements,
      bart.id: bart.trustStatements,
      lisa.id: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    const String newsContext = 'news-context';
    await homerN.doFollow(bart.token, {newsContext: 1});
    await homerN.doFollow(lisa.token, {newsContext: 1});

    var allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, newsContext);

    final Json subject1 = {'contentType': 'url', 'url': 'https://news.com/1'};
    final Json subject2 = {'contentType': 'url', 'url': 'https://news.com/2'};
    final Json subject3 = {'contentType': 'url', 'url': 'https://news.com/3'};

    final String subject1Token = getToken(subject1);
    final String subject2Token = getToken(subject2);
    final String subject3Token = getToken(subject3);

    // 1. Bart equates 1 and 2
    final ContentStatement equate12 = await bartN.doRelate(ContentVerb.equate, subject: subject1, other: subject2);
    // 2. Bart relates 1 and 3
    final ContentStatement relate13 = await bartN.doRelate(ContentVerb.relate, subject: subject1, other: subject3);

    // 3. Lisa censors subject 2
    await lisaN.doRate(subject: subject2, censor: true);

    // Rebuild map
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    // The equate statement should be filtered because subject2 is censored
    expect(aggregation.statements.any((s) => s.token == equate12.token), isFalse);
    // The relate statement should remain because neither 1 nor 3 are censored
    expect(aggregation.statements.any((s) => s.token == relate13.token), isTrue);
    expect(network.povIdentity, homer.token);

    // 4. Lisa censors the relate statement itself
    await lisaN.doRate(subject: relate13.token, censor: true);

    // Rebuild map
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate));

    final ContentAggregation aggregation2 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    expect(aggregation2.statements.any((s) => s.token == relate13.token), isFalse);
  });

  test('V2 Subject Aggregation: Grouping and Stats', () async {
    final DemoIdentityKey homer = await DemoIdentityKey.create('homer');
    final DemoIdentityKey bart = await DemoIdentityKey.create('bart');

    final DemoDelegateKey homerN = await homer.makeDelegate();
    final DemoDelegateKey bartN = await bart.makeDelegate();

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: homer.id), {
      homer.id: [
        await homer.trust(bart, moniker: 'bart'),
        ...homer.trustStatements,
      ],
      bart.id: bart.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    const String newsContext = 'news-context';
    await homerN.doFollow(bart.token, {newsContext: 1});

    var allStatementsByToken = buildContentResult([homer, homerN, bart, bartN].where((k) => k.isDelegate));

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, newsContext);

    final Map<String, dynamic> subject1 = {'contentType': 'url', 'url': 'https://news.com/1', 'title': 'News 1'};
    final String sToken = getToken(subject1);
    final String subject2 = sToken; // Use the actual token

    // 1. Bart rates subject1 with a tag
    await bartN.doRate(subject: subject1, recommend: true, comment: 'Great! #news');
    
    // 2. Homer rates subject2 (token only)
    await homerN.doRate(subject: subject2, recommend: true);

    // 3. Homer dismisses subject1
    await homerN.doRate(subject: subject1, dismiss: true);

    // Rebuild map
    allStatementsByToken = buildContentResult([homer, homerN, bart, bartN].where((k) => k.isDelegate));

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
      labeler: V2Labeler(graph, delegateResolver: delegateResolver),
    );

    expect(aggregation.subjects.containsKey(ContentKey(sToken)), isTrue);
    expect(network.povIdentity, homer.id);
    
    final SubjectAggregation agg = aggregation.subjects[ContentKey(sToken)]!;
    // Homer's dismissal overwrites his previous like because they are the same subject (token vs map)
    expect(agg.likes, equals(1)); 
    expect(agg.tags, contains('#news'));
    expect(agg.isDismissed, isTrue); // Dismissed by Homer (POV)
    expect(agg.statements.length, equals(2));
    
    // Verify bestSubject (should be the JSON, not the token string)
    expect(agg.subject, isA<Map>());
    expect(agg.subject['title'], equals('News 1'));
  });
}

ContentResult buildContentResult(Iterable<DemoKey> keys) {
  final Map<DelegateKey, List<ContentStatement>> delegateContent = {};
  
  for (final k in keys) {
    if (k is DemoDelegateKey) {
      delegateContent[k.id] = k.contentStatements;
    }
  }
  return ContentResult(delegateContent: delegateContent);
}
