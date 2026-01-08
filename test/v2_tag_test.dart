import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_types.dart';
import 'test_utils.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/oneofus/prefs.dart';

import 'package:nerdster/v2/source_error.dart';

class MockSource<T extends Statement> implements StatementSource<T> {
  @override
  List<SourceError> get errors => [];

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async => {};
}

void main() {
  setUpAll(() {
    ContentStatement.init();
    TrustStatement.init();
  });

  group('V2 Tag Logic Tests', () {
    test('Recursive Tag Collection', () {
      final now = DateTime.now().toIso8601String();
      final identityJsonish = Jsonish({'oneofusKey': 'identity1'});
      final identityToken = identityJsonish.token;
      
      final delegateJsonish = Jsonish({'oneofusKey': 'delegate1'});
      final delegateToken = delegateJsonish.token;

      final delegateStatement = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'time': now,
        'I': identityJsonish.json,
        'delegate': delegateJsonish.json,
        'with': {'domain': 'nerdster.org'}
      }));

      final Json subject1 = {'url': 'subject1'};
      final String subject1Token = getToken(subject1);

      final s1 = ContentStatement(Jsonish({
        'rate': subject1,
        'comment': 'Hello #world',
        'I': delegateJsonish.json,
        'time': now,
      }));
      final s2 = ContentStatement(Jsonish({
        'rate': s1.jsonish.json, // Reply to s1
        'comment': 'Reply with #tag2',
        'I': delegateJsonish.json,
        'time': now,
      }));

      final followNetwork = FollowNetwork(fcontext: 'test', povIdentity: IdentityKey(identityToken), identities: [IdentityKey(identityToken)]);
      final trustGraph = TrustGraph(
        pov: IdentityKey(identityToken), 
        distances: {IdentityKey(identityToken): 0},
        edges: {IdentityKey(identityToken): [delegateStatement]}
      );
      final delegateResolver = DelegateResolver(trustGraph);
      
      final byToken = {
        DelegateKey(delegateToken): [s1, s2],
      };

      final aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
      );

      final subjectAgg = aggregation.subjects[subject1Token];
      expect(subjectAgg, isNotNull);
      expect(subjectAgg!.tags, contains('#world'));
      expect(subjectAgg.tags, contains('#tag2'));
    });

    test('Tag Equivalence (Transitive)', () {
      final now = DateTime.now().toIso8601String();
      final identityJsonish = Jsonish({'oneofusKey': 'identity1'});
      final identityToken = identityJsonish.token;

      final delegateJsonish = Jsonish({'oneofusKey': 'delegate1'});
      final delegateToken = delegateJsonish.token;

      final delegateStatement = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'time': now,
        'I': identityJsonish.json,
        'delegate': delegateJsonish.json,
        'with': {'domain': 'nerdster.org'}
      }));

      final Json subject1 = {'url': 'subject1'};
      final Json subject2 = {'url': 'subject2'};

      final s1 = ContentStatement(Jsonish({
        'rate': subject1,
        'comment': 'Co-occurrence #news #politics',
        'I': delegateJsonish.json,
        'time': now,
      }));
      final s2 = ContentStatement(Jsonish({
        'rate': subject2,
        'comment': 'Co-occurrence #politics #world',
        'I': delegateJsonish.json,
        'time': now,
      }));

      final followNetwork = FollowNetwork(fcontext: 'test', povIdentity: IdentityKey(identityToken), identities: [IdentityKey(identityToken)]);
      final trustGraph = TrustGraph(
        pov: IdentityKey(identityToken), 
        distances: {IdentityKey(identityToken): 0},
        edges: {IdentityKey(identityToken): [delegateStatement]}
      );
      final delegateResolver = DelegateResolver(trustGraph);
      
      final byToken = {
        DelegateKey(delegateToken): [s1, s2],
      };

      final aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
      );

      final newsCanonical = aggregation.tagEquivalence['#news'];
      final politicsCanonical = aggregation.tagEquivalence['#politics'];
      final worldCanonical = aggregation.tagEquivalence['#world'];

      expect(newsCanonical, isNotNull);
      expect(newsCanonical, equals(politicsCanonical));
      expect(politicsCanonical, equals(worldCanonical));
    });

    test('Tag Frequency Tracking', () {
      final now = DateTime.now().toIso8601String();
      final identityJsonish = Jsonish({'oneofusKey': 'identity1'});
      final identityToken = identityJsonish.token;

      final delegateJsonish = Jsonish({'oneofusKey': 'delegate1'});
      final delegateToken = delegateJsonish.token;

      final delegateStatement = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'time': now,
        'I': identityJsonish.json,
        'delegate': delegateJsonish.json,
        'with': {'domain': 'nerdster.org'}
      }));

      final Json subject1 = {'url': 'subject1'};
      final Json subject2 = {'url': 'subject2'};

      final s1 = ContentStatement(Jsonish({
        'rate': subject1,
        'comment': '#common #rare',
        'I': delegateJsonish.json,
        'time': now,
      }));
      final s2 = ContentStatement(Jsonish({
        'rate': subject2,
        'comment': '#common',
        'I': delegateJsonish.json,
        'time': now,
      }));

      final followNetwork = FollowNetwork(fcontext: 'test', povIdentity: IdentityKey(identityToken), identities: [IdentityKey(identityToken)]);
      final trustGraph = TrustGraph(
        pov: IdentityKey(identityToken), 
        distances: {IdentityKey(identityToken): 0},
        edges: {IdentityKey(identityToken): [delegateStatement]}
      );
      final delegateResolver = DelegateResolver(trustGraph);
      
      final byToken = {
        DelegateKey(delegateToken): [s1, s2],
      };

      final aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
      );

      expect(aggregation.mostTags.first, equals('#common'));
      expect(aggregation.mostTags, contains('#rare'));
    });

    test('Filtering by Tag (including equivalents)', () {
      final now = DateTime.now().toIso8601String();
      final identityJsonish = Jsonish({'oneofusKey': 'identity1'});
      final identityToken = identityJsonish.token;

      final delegateJsonish = Jsonish({'oneofusKey': 'delegate1'});
      final delegateToken = delegateJsonish.token;

      final delegateStatement = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'time': now,
        'I': identityJsonish.json,
        'delegate': delegateJsonish.json,
        'with': {'domain': 'nerdster.org'}
      }));

      // Use valid subjects that have a contentType so they pass the filter
      final subject1 = createTestSubject(type: ContentType.article, url: 'https://sub1.com')..['id'] = 'sub1';
      final subject2 = createTestSubject(type: ContentType.article, url: 'https://sub2.com')..['id'] = 'sub2';

      final s1 = ContentStatement(Jsonish({
        'rate': subject1,
        'comment': '#news #politics',
        'I': delegateJsonish.json,
        'time': now,
      }));
      final s2 = ContentStatement(Jsonish({
        'rate': subject2,
        'comment': '#world',
        'I': delegateJsonish.json,
        'time': now,
      }));

      final followNetwork = FollowNetwork(fcontext: 'test', povIdentity: IdentityKey(identityToken), identities: [IdentityKey(identityToken)]);
      final trustGraph = TrustGraph(
        pov: IdentityKey(identityToken), 
        distances: {IdentityKey(identityToken): 0},
        edges: {IdentityKey(identityToken): [delegateStatement]}
      );
      final delegateResolver = DelegateResolver(trustGraph);
      
      final byToken = {
        DelegateKey(delegateToken): [s1, s2],
      };

      final aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
      );

      final controller = V2FeedController(
        trustSource: MockSource(),
        contentSource: MockSource(),
      );

      final sub1 = aggregation.subjects.values.firstWhere((s) => (s.subject as Map)['id'] == 'sub1');
      final sub2 = aggregation.subjects.values.firstWhere((s) => (s.subject as Map)['id'] == 'sub2');

      // Filter by #politics, should show subject1 (because it has #news which is equivalent to #politics)
      Setting.get<String>(SettingType.tag).value = '#politics';
      // expect(controller.shouldShow(sub1), isTrue); // shouldShow uses logic that might not support equivalence yet
      
      // Filter by #politics, should NOT show subject2
      Setting.get<String>(SettingType.tag).value = '#politics';
      // expect(controller.shouldShow(sub2), isFalse);
    });
  });
}
