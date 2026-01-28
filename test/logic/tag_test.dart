import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_types.dart';
import '../test_utils.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/settings/prefs.dart';

import 'package:oneofus_common/source_error.dart';
import 'package:nerdster/logic/labeler.dart';

class MockSource<T extends Statement> implements StatementSource<T> {
  @override
  List<SourceError> get errors => [];

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async => {};
}

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  group('V2 Tag Logic Tests', () {
    test('Recursive Tag Collection', () {
      final Json identityKey = mockKey('identity1');
      final String identityToken = Jsonish(identityKey).token;

      final Json delegateKey = mockKey('delegate1');
      final String delegateToken = Jsonish(delegateKey).token;

      final TrustStatement delegateStatement = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: delegateKey,
        iJson: identityKey,
        domain: 'nerdster.org',
      );

      final Map<String, dynamic> subject1 = createTestSubject(title: 'Subject 1');
      final String subject1Token = getToken(subject1);

      final ContentStatement s1 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject1,
        comment: 'Hello #world',
        iJson: delegateKey,
      );
      final ContentStatement s2 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: s1.jsonish.json, // Reply to s1
        comment: 'Reply with #tag2',
        iJson: delegateKey,
      );

      final FollowNetwork followNetwork = FollowNetwork(
          fcontext: 'test',
          povIdentity: IdentityKey(identityToken),
          identities: [IdentityKey(identityToken)]);
      final TrustGraph trustGraph = TrustGraph(pov: IdentityKey(identityToken), distances: {
        IdentityKey(identityToken): 0
      }, edges: {
        IdentityKey(identityToken): [delegateStatement]
      });
      final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

      final Map<DelegateKey, List<ContentStatement>> byToken = {
        DelegateKey(delegateToken): [s2, s1],
      };

      final V2Labeler labeler = V2Labeler(trustGraph, delegateResolver: delegateResolver);
      final ContentAggregation aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
        labeler: labeler,
      );

      final SubjectAggregation? subjectAgg = aggregation.subjects[ContentKey(subject1Token)];
      expect(subjectAgg, isNotNull);
      expect(subjectAgg!.tags, contains('#world'));
      expect(subjectAgg.tags, contains('#tag2'));
    });

    test('Tag Equivalence (Transitive)', () {
      final Json identityKey = mockKey('identity1');
      final String identityToken = Jsonish(identityKey).token;

      final Json delegateKey = mockKey('delegate1');
      final String delegateToken = Jsonish(delegateKey).token;

      final TrustStatement delegateStatement = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: delegateKey,
        iJson: identityKey,
        domain: 'nerdster.org',
      );

      final Map<String, dynamic> subject1 = createTestSubject(title: 'Subject 1');
      final Map<String, dynamic> subject2 = createTestSubject(title: 'Subject 2');

      final ContentStatement s1 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject1,
        comment: 'Co-occurrence #news #politics',
        iJson: delegateKey,
      );
      final ContentStatement s2 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject2,
        comment: 'Co-occurrence #politics #world',
        iJson: delegateKey,
      );

      final FollowNetwork followNetwork = FollowNetwork(
          fcontext: 'test',
          povIdentity: IdentityKey(identityToken),
          identities: [IdentityKey(identityToken)]);
      final TrustGraph trustGraph = TrustGraph(pov: IdentityKey(identityToken), distances: {
        IdentityKey(identityToken): 0
      }, edges: {
        IdentityKey(identityToken): [delegateStatement]
      });
      final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

      final Map<DelegateKey, List<ContentStatement>> byToken = {
        DelegateKey(delegateToken): [s2, s1],
      };

      final V2Labeler labeler = V2Labeler(trustGraph, delegateResolver: delegateResolver);
      final ContentAggregation aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
        labeler: labeler,
      );

      final String? newsCanonical = aggregation.tagEquivalence['#news'];
      final String? politicsCanonical = aggregation.tagEquivalence['#politics'];
      final String? worldCanonical = aggregation.tagEquivalence['#world'];

      expect(newsCanonical, isNotNull);
      expect(newsCanonical, equals(politicsCanonical));
      expect(politicsCanonical, equals(worldCanonical));
    });

    test('Tag Frequency Tracking', () {
      final Json identityKey = mockKey('identity1');
      final String identityToken = Jsonish(identityKey).token;

      final Json delegateKey = mockKey('delegate1');
      final String delegateToken = Jsonish(delegateKey).token;

      final TrustStatement delegateStatement = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: delegateKey,
        iJson: identityKey,
        domain: 'nerdster.org',
      );

      final Map<String, dynamic> subject1 = createTestSubject(title: 'Subject 1');
      final Map<String, dynamic> subject2 = createTestSubject(title: 'Subject 2');

      final ContentStatement s1 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject1,
        comment: '#common #rare',
        iJson: delegateKey,
      );
      final ContentStatement s2 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject2,
        comment: '#common',
        iJson: delegateKey,
      );

      final FollowNetwork followNetwork = FollowNetwork(
          fcontext: 'test',
          povIdentity: IdentityKey(identityToken),
          identities: [IdentityKey(identityToken)]);
      final TrustGraph trustGraph = TrustGraph(pov: IdentityKey(identityToken), distances: {
        IdentityKey(identityToken): 0
      }, edges: {
        IdentityKey(identityToken): [delegateStatement]
      });
      final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

      final Map<DelegateKey, List<ContentStatement>> byToken = {
        DelegateKey(delegateToken): [s2, s1],
      };

      final V2Labeler labeler = V2Labeler(trustGraph, delegateResolver: delegateResolver);
      final ContentAggregation aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
        labeler: labeler,
      );

      expect(aggregation.mostTags.first, equals('#common'));
      expect(aggregation.mostTags, contains('#rare'));
    });

    test('Filtering by Tag (including equivalents)', () {
      final Json identityKey = mockKey('identity1');
      final String identityToken = Jsonish(identityKey).token;

      final Json delegateKey = mockKey('delegate1');
      final String delegateToken = Jsonish(delegateKey).token;

      final TrustStatement delegateStatement = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: delegateKey,
        iJson: identityKey,
        domain: 'nerdster.org',
      );

      // Use valid subjects that have a contentType so they pass the filter
      final Map<String, dynamic> subject1 =
          createTestSubject(type: ContentType.article, url: 'https://sub1.com')..['id'] = 'sub1';
      final Map<String, dynamic> subject2 =
          createTestSubject(type: ContentType.article, url: 'https://sub2.com')..['id'] = 'sub2';

      final ContentStatement s1 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject1,
        comment: '#news #politics',
        iJson: delegateKey,
      );
      final ContentStatement s2 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject2,
        comment: '#world',
        iJson: delegateKey,
      );

      final FollowNetwork followNetwork = FollowNetwork(
          fcontext: 'test',
          povIdentity: IdentityKey(identityToken),
          identities: [IdentityKey(identityToken)]);
      final TrustGraph trustGraph = TrustGraph(pov: IdentityKey(identityToken), distances: {
        IdentityKey(identityToken): 0
      }, edges: {
        IdentityKey(identityToken): [delegateStatement]
      });
      final DelegateResolver delegateResolver = DelegateResolver(trustGraph);

      final Map<DelegateKey, List<ContentStatement>> byToken = {
        DelegateKey(delegateToken): [s2, s1],
      };

      final V2Labeler labeler = V2Labeler(trustGraph, delegateResolver: delegateResolver);
      final ContentAggregation aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
        labeler: labeler,
      );

      // Filter by #politics...
      Setting.get<String>(SettingType.tag).value = '#politics';
      expect(aggregation.tagEquivalence['#news'], equals(aggregation.tagEquivalence['#politics']));
    });
  });
}
