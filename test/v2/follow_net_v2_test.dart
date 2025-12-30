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
    final DemoKey bart = DemoKey.findByName('bart')!;
    
    // 1. Build TrustGraph (Identity Layer)
    final Map<String, List<TrustStatement>> allTrustStatements = {};
    for (final DemoKey dk in DemoKey.all.where((k) => k.isIdentity)) {
      allTrustStatements[dk.token] = dk.trustStatements;
    }

    final TrustGraph trustGraph = reduceTrustGraph(
      TrustGraph(root: bart.token),
      allTrustStatements,
    );

    expect(trustGraph.isTrusted(bart.token), true);
    
    final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

    // 2. Build FollowNetwork for <nerdster> context
    final Map<String, List<ContentStatement>> allContentStatements = {};
    for (final DemoKey dk in DemoKey.all.where((k) => k.isDelegate)) {
      allContentStatements[dk.token] = dk.contentStatements;
    }

    final FollowNetwork followNet = reduceFollowNetwork(
      trustGraph,
      delegateResolver,
      allContentStatements,
      kNerdsterContext, // Using the standard <nerdster> follow context
    );

    // Bart should be in the network
    expect(followNet.contains(bart.token), true);
    expect(followNet.rootIdentity, bart.token);
    
    // Check some other Simpsons
    final DemoKey homer = DemoKey.findByName('homer')!;
    final DemoKey lisa = DemoKey.findByName('lisa')!;
    
    expect(followNet.contains(trustGraph.resolveIdentity(homer.token)), true);
    // Lisa is blocked in <nerdster> context by Bart
    expect(followNet.contains(trustGraph.resolveIdentity(lisa.token)), false);
    
    // Check order (discovery order)
    expect(followNet.identities.indexOf(bart.token), 0);
    expect(followNet.identities.indexOf(trustGraph.resolveIdentity(homer.token)), greaterThan(0));
  });

  test('Simpsons Demo: Multi-POV Content Verification', () async {
    await simpsons();
    
    final DemoKey bart = DemoKey.findByName('bart')!;
    final DemoKey lisa = DemoKey.findByName('lisa')!;
    final DemoKey homer = DemoKey.findByName('homer')!;
    final DemoKey homer2 = DemoKey.findByName('homer2')!;
    final DemoKey marge = DemoKey.findByName('marge')!;

    final Map<String, List<TrustStatement>> allTrustStatements = {};
    final Map<String, List<ContentStatement>> allContentStatements = {};
    for (final DemoKey dk in DemoKey.all.where((k) => k.isIdentity)) {
      allTrustStatements[dk.token] = dk.trustStatements;
    }
    for (final DemoKey dk in DemoKey.all.where((k) => k.isDelegate)) {
      allContentStatements[dk.token] = dk.contentStatements;
    }

    final DemoKey margeN = DemoKey.findByName('marge-nerdster0')!;
    final ContentStatement margeRating = margeN.contentStatements.firstWhere((s) => s.verb == ContentVerb.rate);

    // --- LISA'S POV ---
    final TrustGraph trustLisa = reduceTrustGraph(TrustGraph(root: lisa.token), allTrustStatements);
    final DelegateResolver delegatesLisa = DelegateResolver(trustLisa);
    
    final FollowNetwork followLisa = reduceFollowNetwork(trustLisa, delegatesLisa, allContentStatements, kNerdsterContext);
    final ContentAggregation contentLisa = reduceContentAggregation(followLisa, trustLisa, delegatesLisa, allContentStatements);

    // Lisa should see content from Marge and Homer2
    expect(followLisa.contains(trustLisa.resolveIdentity(marge.token)), true, reason: 'Lisa should follow Marge');
    expect(followLisa.contains(trustLisa.resolveIdentity(homer.token)), true, reason: 'Lisa should follow Homer (Homer2)');
    
    // Check if Marge's content is there (MargeN signed it)
    expect(contentLisa.subjects.values.any((s) => s.canonicalToken == margeRating.subjectToken), true, reason: "Lisa should see Marge's content");

    // --- BART'S POV ---
    final TrustGraph trustBart = reduceTrustGraph(TrustGraph(root: bart.token), allTrustStatements);
    final DelegateResolver delegatesBart = DelegateResolver(trustBart);
    final FollowNetwork followBart = reduceFollowNetwork(trustBart, delegatesBart, allContentStatements, kNerdsterContext);
    reduceContentAggregation(followBart, trustBart, delegatesBart, allContentStatements);

    // Bart blocks Lisa in <nerdster> context in simpsons.dart
    expect(followBart.contains(trustBart.resolveIdentity(lisa.token)), false, reason: 'Bart blocks Lisa');

    // --- HOMER'S POV (Homer2) ---
    final TrustGraph trustHomer = reduceTrustGraph(TrustGraph(root: homer2.token), allTrustStatements);
    final DelegateResolver delegatesHomer = DelegateResolver(trustHomer);
    final FollowNetwork followHomer = reduceFollowNetwork(trustHomer, delegatesHomer, allContentStatements, kNerdsterContext);
    reduceContentAggregation(followHomer, trustHomer, delegatesHomer, allContentStatements);

    expect(followHomer.contains(trustHomer.resolveIdentity(lisa.token)), true, reason: 'Homer2 should follow Lisa');
  });

  test('Custom Context Filtering (V2)', () async {
    await simpsons();
    final DemoKey bart = DemoKey.findByName('bart')!;
    
    final Map<String, List<TrustStatement>> allTrustStatements = {};
    for (final DemoKey dk in DemoKey.all.where((k) => k.isIdentity)) {
      allTrustStatements[dk.token] = dk.trustStatements;
    }

    final TrustGraph trustGraph = reduceTrustGraph(
      TrustGraph(root: bart.token),
      allTrustStatements,
    );

    final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

    final Map<String, List<ContentStatement>> allContentStatements = {};
    for (final DemoKey dk in DemoKey.all.where((k) => k.isDelegate)) {
      allContentStatements[dk.token] = dk.contentStatements;
    }

    // 'family' is a custom follow context used in the Simpsons demo data
    final FollowNetwork familyNet = reduceFollowNetwork(
      trustGraph,
      delegateResolver,
      allContentStatements,
      'family',
    );

    final DemoKey homer = DemoKey.findByName('homer')!;
    final DemoKey marge = DemoKey.findByName('marge')!;
    final DemoKey milhouse = DemoKey.findByName('milhouse')!;
    final DemoKey lisa = DemoKey.findByName('lisa')!;

    expect(familyNet.contains(bart.token), true);
    expect(familyNet.rootIdentity, bart.token);
    
    expect(familyNet.contains(trustGraph.resolveIdentity(homer.token)), true);
    expect(familyNet.contains(trustGraph.resolveIdentity(marge.token)), true);
    expect(familyNet.contains(trustGraph.resolveIdentity(lisa.token)), true);
    // Milhouse is not family
    expect(familyNet.contains(trustGraph.resolveIdentity(milhouse.token)), false);
  });

  test('V2 Content Aggregation: Censorship and Equivalence', () async {
    final DemoKey homer = await DemoKey.create('homer');
    final DemoKey bart = await DemoKey.create('bart');
    final DemoKey lisa = await DemoKey.create('lisa');

    final DemoKey homerN = await homer.makeDelegate();
    final DemoKey bartN = await bart.makeDelegate();
    final DemoKey lisaN = await lisa.makeDelegate();

    final String news1 = 'https://news.com/1';
    final String news2 = 'https://news.com/2';
    final String spam = 'https://spam.com';

    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: homer.token), {
      homer.token: [
        await homer.trust(lisa, moniker: 'lisa'),
        await homer.trust(bart, moniker: 'bart'),
        ...homer.trustStatements, // includes the delegate
      ],
      bart.token: bart.trustStatements,
      lisa.token: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Bart rates news1 and news2
    await bartN.doRate(subject: news1, recommend: true);
    await bartN.doRate(subject: news2, recommend: true);

    // Lisa also censors spam
    await lisaN.doRate(subject: spam, censor: true);

    final Map<String, List<ContentStatement>> allStatementsByToken = {};
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final FollowNetwork followNet = reduceFollowNetwork(
      graph,
      delegateResolver,
      allStatementsByToken,
      kNerdsterContext,
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
    );

    // Spam should be censored
    expect(contentAgg.censored, contains(spam));
    // news1 and news2 should be equated
    expect(contentAgg.equivalence[news2], contentAgg.equivalence[news1]);
  });

  test('V2 Content Aggregation: Censorship Overrides', () async {
    final DemoKey homer = await DemoKey.create('homer');
    final DemoKey bart = await DemoKey.create('bart');
    final DemoKey lisa = await DemoKey.create('lisa');

    final DemoKey homerN = await homer.makeDelegate();
    final DemoKey bartN = await bart.makeDelegate();
    final DemoKey lisaN = await lisa.makeDelegate();

    // Lisa is more trusted than Bart
    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: homer.token), {
      homer.token: [
        await homer.trust(lisa, moniker: 'lisa'),
        await homer.trust(bart, moniker: 'bart'),
        ...homer.trustStatements,
      ],
      bart.token: bart.trustStatements,
      lisa.token: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Homer follows Bart and Lisa
    await homerN.doFollow(bart.token, {'news': 1});
    await homerN.doFollow(lisa.token, {'news': 1});
    
    final Map<String, List<ContentStatement>> allStatementsByToken = {};
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, 'news');

    // 1. Bart rates a spam URL
    final String spamUrl = 'https://spam.com';
    final ContentStatement spamRate = await bartN.doRate(subject: spamUrl, recommend: true);
    
    // 2. Lisa censors Bart's rating statement
    final ContentStatement lisaCensorship = await lisaN.doRate(subject: spamRate.token, censor: true);

    // 3. Homer also rates the spam URL (he likes it)
    final ContentStatement homerRate = await homerN.doRate(subject: spamUrl, recommend: true);

    // Rebuild map to include new statements
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // Lisa censored Bart's statement, so Bart's rating should be gone.
    // But the URL itself was NOT censored, so Homer's rating should remain.
    expect(aggregation.censored, contains(spamRate.token));
    expect(aggregation.censored, isNot(contains(spamUrl)));
    
    final Set<String> remainingTokens = aggregation.statements.map((s) => s.token).toSet();
    expect(remainingTokens, contains(homerRate.token));
    expect(remainingTokens, isNot(contains(spamRate.token)));

    // 4. Now Bart censors the URL itself
    final ContentStatement bartCensorship = await bartN.doRate(subject: spamUrl, censor: true);
    
    // Rebuild map again
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation2 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // 5. Lisa censors Bart's censorship statement
    final ContentStatement lisaCensorsBartCensorship = await lisaN.doRate(subject: bartCensorship.token, censor: true);

    // Rebuild map again
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation3 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // Lisa is more trusted than Bart.
    // Lisa censored Bart's censorship of the URL.
    // So the URL should NOT be censored anymore.
    expect(aggregation3.censored, contains(bartCensorship.token));
    expect(aggregation3.censored, isNot(contains(spamUrl)));
    expect(aggregation3.statements.map((s) => s.token), contains(homerRate.token));
  });

  test('V2 Follow Network: Delegate Resolution', () async {
    final DemoKey homer = await DemoKey.create('homer');
    final DemoKey bart = await DemoKey.create('bart');
    final DemoKey bartDelegate = await DemoKey.create('bart-delegate');

    final DemoKey homerN = await homer.makeDelegate();

    // 1. Homer trusts Bart
    final Map<String, List<TrustStatement>> trustStatements = {
      homer.token: [
        await homer.trust(bart, moniker: 'bart'),
        ...homer.trustStatements,
      ],
      bart.token: [await bart.delegate(bartDelegate, domain: kNerdsterDomain)],
    };

    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: homer.token), trustStatements);
    expect(graph.isTrusted(bart.token), isTrue);
    expect(graph.isTrusted(bartDelegate.token), isFalse); // Delegate is not in WoT

    final DelegateResolver delegateResolver = DelegateResolver(graph);
    // In the lazy resolver, we must resolve the identity to see its delegates
    expect(delegateResolver.getDelegatesForIdentity(bart.token), contains(bartDelegate.token));
    expect(delegateResolver.getIdentityForDelegate(bartDelegate.token), bart.token);

    // 2. Homer follows Bart in 'news-context'
    const String newsContext = 'news-context';
    await homerN.doFollow(bart.token, {newsContext: 1});

    // Bart's delegate signs a content statement
    final String news = 'https://news.com/1';
    await bartDelegate.doRate(subject: news, recommend: true);

    final Map<String, List<ContentStatement>> allStatementsByToken = {};
    for (final DemoKey dk in [homer, homerN, bart, bartDelegate].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final FollowNetwork network = reduceFollowNetwork(
      graph,
      delegateResolver,
      allStatementsByToken,
      newsContext,
    );

    // Homer should follow Bart
    expect(network.identities, contains(bart.token));
    expect(network.rootIdentity, homer.token);
    
    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // Bart's delegate's statement should be included
    expect(aggregation.statements.any((s) => s.subjectToken == news), isTrue);
  });

  test('V2 Content Aggregation: Proximity-Based Censorship (Censor-the-Censor)', () async {
    final DemoKey homer = await DemoKey.create('homer');
    final DemoKey bart = await DemoKey.create('bart');
    final DemoKey lisa = await DemoKey.create('lisa');

    final DemoKey homerN = await homer.makeDelegate();
    final DemoKey bartN = await bart.makeDelegate();
    final DemoKey lisaN = await lisa.makeDelegate();

    await homer.trust(bart, moniker: 'bart');
    await homer.trust(lisa, moniker: 'lisa');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: homer.token), {
      homer.token: homer.trustStatements,
      bart.token: bart.trustStatements,
      lisa.token: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Homer follows Bart and Lisa
    await homerN.doFollow(bart.token, {'news': 1});
    await homerN.doFollow(lisa.token, {'news': 1});
    
    final Map<String, List<ContentStatement>> allStatementsByToken = {};
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, 'news');

    // 1. Bart rates a spam URL
    final String spamUrl = 'https://spam.com';
    final ContentStatement spamRate = await bartN.doRate(subject: spamUrl, recommend: true);
    
    // 2. Lisa censors Bart's rating statement
    final ContentStatement lisaCensorship = await lisaN.doRate(subject: spamRate.token, censor: true);

    // 3. Homer also rates the spam URL (he likes it)
    final ContentStatement homerRate = await homerN.doRate(subject: spamUrl, recommend: true);

    // Rebuild map
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // Lisa censored Bart's statement, so Bart's rating should be gone.
    expect(aggregation.censored, contains(spamRate.token));
    expect(aggregation.censored, isNot(contains(spamUrl)));
    
    final Set<String> remainingTokens = aggregation.statements.map((s) => s.token).toSet();
    expect(remainingTokens, contains(homerRate.token));
    expect(remainingTokens, isNot(contains(spamRate.token)));

    // 4. Now Bart censors the URL itself
    final ContentStatement bartCensorship = await bartN.doRate(subject: spamUrl, censor: true);
    
    // Rebuild map
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation2 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // Now the URL is censored by Bart.
    expect(aggregation2.censored, contains(spamUrl));

    // 5. Lisa censors Bart's censorship statement
    final ContentStatement lisaCensorsBartCensorship = await lisaN.doRate(subject: bartCensorship.token, censor: true);

    // Rebuild map
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation3 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // Lisa censored Bart's censorship of the URL.
    // So the URL should NOT be censored anymore.
    expect(aggregation3.censored, contains(bartCensorship.token));
    expect(aggregation3.censored, isNot(contains(spamUrl)));
    expect(aggregation3.statements.map((s) => s.token), contains(homerRate.token));
  });

  test('Censoring Relate and Equate Statements (V2)', () async {
    final DemoKey homer = await DemoKey.create('homer');
    final DemoKey bart = await DemoKey.create('bart');
    final DemoKey lisa = await DemoKey.create('lisa');

    final DemoKey homerN = await homer.makeDelegate();
    final DemoKey bartN = await bart.makeDelegate();
    final DemoKey lisaN = await lisa.makeDelegate();

    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: homer.token), {
      homer.token: [
        await homer.trust(bart, moniker: 'bart'),
        await homer.trust(lisa, moniker: 'lisa'),
        ...homer.trustStatements,
      ],
      bart.token: bart.trustStatements,
      lisa.token: lisa.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    const String newsContext = 'news-context';
    await homerN.doFollow(bart.token, {newsContext: 1});
    await homerN.doFollow(lisa.token, {newsContext: 1});

    final Map<String, List<ContentStatement>> allStatementsByToken = {};
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, newsContext);

    final String subject1 = 'https://news.com/1';
    final String subject2 = 'https://news.com/2';
    final String subject3 = 'https://news.com/3';

    // 1. Bart equates 1 and 2
    final ContentStatement equate12 = await bartN.doRelate(ContentVerb.equate, subject: subject1, other: subject2);
    // 2. Bart relates 1 and 3
    final ContentStatement relate13 = await bartN.doRelate(ContentVerb.relate, subject: subject1, other: subject3);

    // 3. Lisa censors subject 2
    final ContentStatement censor2 = await lisaN.doRate(subject: subject2, censor: true);

    // Rebuild map
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    // The equate statement should be filtered because subject2 is censored
    expect(aggregation.statements.any((s) => s.token == equate12.token), isFalse);
    // The relate statement should remain because neither 1 nor 3 are censored
    expect(aggregation.statements.any((s) => s.token == relate13.token), isTrue);
    expect(network.rootIdentity, homer.token);

    // 4. Lisa censors the relate statement itself
    final ContentStatement censorRelate = await lisaN.doRate(subject: relate13.token, censor: true);

    // Rebuild map
    for (final DemoKey dk in [homer, homerN, bart, bartN, lisa, lisaN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation2 = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    expect(aggregation2.statements.any((s) => s.token == relate13.token), isFalse);
  });

  test('V2 Subject Aggregation: Grouping and Stats', () async {
    final DemoKey homer = await DemoKey.create('homer');
    final DemoKey bart = await DemoKey.create('bart');

    final DemoKey homerN = await homer.makeDelegate();
    final DemoKey bartN = await bart.makeDelegate();

    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: homer.token), {
      homer.token: [
        await homer.trust(bart, moniker: 'bart'),
        ...homer.trustStatements,
      ],
      bart.token: bart.trustStatements,
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    const String newsContext = 'news-context';
    await homerN.doFollow(bart.token, {newsContext: 1});

    final Map<String, List<ContentStatement>> allStatementsByToken = {};
    for (final DemoKey dk in [homer, homerN, bart, bartN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final FollowNetwork network = reduceFollowNetwork(graph, delegateResolver, allStatementsByToken, newsContext);

    final Map<String, dynamic> subject1 = {'url': 'https://news.com/1', 'title': 'News 1'};
    final String sToken = getToken(subject1);
    final String subject2 = sToken; // Use the actual token

    // 1. Bart rates subject1 with a tag
    await bartN.doRate(subject: subject1, recommend: true, comment: 'Great! #news');
    
    // 2. Homer rates subject2 (token only)
    await homerN.doRate(subject: subject2, recommend: true);

    // 3. Homer dismisses subject1
    await homerN.doRate(subject: subject1, dismiss: true);

    // Rebuild map
    for (final DemoKey dk in [homer, homerN, bart, bartN].where((k) => k.isDelegate)) {
      allStatementsByToken[dk.token] = dk.contentStatements;
    }

    final ContentAggregation aggregation = reduceContentAggregation(
      network,
      graph,
      delegateResolver,
      allStatementsByToken,
    );

    expect(aggregation.subjects.containsKey(sToken), isTrue);
    expect(network.rootIdentity, homer.token);
    
    final SubjectAggregation agg = aggregation.subjects[sToken]!;
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
