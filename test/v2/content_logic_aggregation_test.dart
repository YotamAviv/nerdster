import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/model.dart';

void main() {
  test('reduceContentAggregation includes my follow statements in myDelegateStatements', () {
    // Setup
    final meToken = 'me';
    final subjectToken = 'subject';
    
    // Mock TrustGraph
    final trustGraph = TrustGraph(
      root: meToken,
      distances: {meToken: 0, subjectToken: 1},
      orderedKeys: [meToken, subjectToken],
    );

    // Mock FollowNetwork
    final followNetwork = FollowNetwork(
      fcontext: 'nerd',
      rootIdentity: meToken,
      identities: [meToken, subjectToken],
    );

    // Mock DelegateResolver
    final delegateResolver = DelegateResolver(trustGraph);

    // Create a follow statement from me to subject
    final meJson = {'token': meToken}; // Minimal identity object
    final followJson = {
      'statement': 'content.nerdster.org',
      'time': DateTime.now().toIso8601String(),
      'I': meJson,
      'follow': subjectToken,
      'with': {
        'contexts': {'nerd': 1}
      }
    };
    final followStatement = ContentStatement(Jsonish(followJson));

    // Create a dummy rate statement so the subject exists in aggregation
    final rateJson = {
      'statement': 'content.nerdster.org',
      'time': DateTime.now().add(Duration(seconds: 1)).toIso8601String(),
      'I': meJson,
      'rate': subjectToken,
      'with': {
        'recommend': true
      }
    };
    final rateStatement = ContentStatement(Jsonish(rateJson));

    // Input map
    // Ensure sorted descending (newest first)
    final Map<String, List<ContentStatement>> byToken = {
      meToken: [rateStatement, followStatement],
    };

    // Run reduction
    final aggregation = reduceContentAggregation(
      followNetwork,
      trustGraph,
      delegateResolver,
      byToken,
      meToken: meToken,
      meKeys: [meToken],
    );

    // Verify
    final subjectAgg = aggregation.subjects[subjectToken];
    expect(subjectAgg, isNotNull, reason: 'Subject aggregation should exist');
    
    final myStatements = subjectAgg!.myDelegateStatements;
    expect(myStatements, isNotEmpty, reason: 'Should have my statements');
    
    final hasFollow = myStatements.any((s) => s.verb == ContentVerb.follow);
    expect(hasFollow, isTrue, reason: 'Should include my follow statement');
  });

  test('reduceContentAggregation creates subject if only I follow it', () {
    // Setup
    final meToken = 'me';
    final subjectToken = 'subject_only_follow';
    
    final trustGraph = TrustGraph(
      root: meToken,
      distances: {meToken: 0, subjectToken: 1},
      orderedKeys: [meToken, subjectToken],
    );

    final followNetwork = FollowNetwork(
      fcontext: 'nerd',
      rootIdentity: meToken,
      identities: [meToken, subjectToken],
    );

    final delegateResolver = DelegateResolver(trustGraph);

    final meJson = {'token': meToken};
    final followJson = {
      'statement': 'content.nerdster.org',
      'time': DateTime.now().toIso8601String(),
      'I': meJson,
      'follow': subjectToken,
      'with': {
        'contexts': {'nerd': 1}
      }
    };
    final followStatement = ContentStatement(Jsonish(followJson));

    final Map<String, List<ContentStatement>> byToken = {
      meToken: [followStatement],
    };

    // Run reduction
    final aggregation = reduceContentAggregation(
      followNetwork,
      trustGraph,
      delegateResolver,
      byToken,
      meToken: meToken,
      meKeys: [meToken],
    );

    // Verify
    final subjectAgg = aggregation.subjects[subjectToken];
    expect(subjectAgg, isNotNull, reason: 'Subject aggregation should exist even if only I follow');
    
    final myStatements = subjectAgg!.myDelegateStatements;
    expect(myStatements, isNotEmpty);
    expect(myStatements.first.verb, ContentVerb.follow);
  });

  test('reduceContentAggregation handles key replacement', () {
    // Setup
    final meToken = 'me';
    final bartOld = 'bart_old';
    final bartNew = 'bart_new';
    
    // TrustGraph where bartOld is replaced by bartNew
    final trustGraph = TrustGraph(
      root: meToken,
      distances: {meToken: 0, bartNew: 1, bartOld: 1}, // Both trusted
      orderedKeys: [meToken, bartNew, bartOld],
      replacements: {bartOld: bartNew}, // Old -> New
    );

    final followNetwork = FollowNetwork(
      fcontext: 'nerd',
      rootIdentity: meToken,
      identities: [meToken, bartNew], // Only canonical usually in identities list?
      // Actually identities list comes from FollowNet which uses TrustGraph.
      // If TrustGraph has replacement, FollowNet usually uses canonical.
    );

    final delegateResolver = DelegateResolver(trustGraph);

    final meJson = {'token': meToken};
    // I follow BartOld
    final followJson = {
      'statement': 'content.nerdster.org',
      'time': DateTime.now().toIso8601String(),
      'I': meJson,
      'follow': bartOld, // Following the OLD key
      'with': {
        'contexts': {'nerd': 1}
      }
    };
    final followStatement = ContentStatement(Jsonish(followJson));

    final Map<String, List<ContentStatement>> byToken = {
      meToken: [followStatement],
    };

    // Run reduction
    final aggregation = reduceContentAggregation(
      followNetwork,
      trustGraph,
      delegateResolver,
      byToken,
      meToken: meToken,
      meKeys: [meToken],
    );

    // Verify aggregation under NEW key
    final subjectAgg = aggregation.subjects[bartNew];
    expect(subjectAgg, isNotNull, reason: 'Subject aggregation should exist for canonical key');
    
    final myStatements = subjectAgg!.myDelegateStatements;
    expect(myStatements, isNotEmpty);
    expect(myStatements.first.verb, ContentVerb.follow);
    expect(myStatements.first.subjectToken, bartOld, reason: 'Statement still points to old key');
  });
}
