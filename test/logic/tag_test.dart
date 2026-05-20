import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/models/content_types.dart';
import 'package:oneofus_common/statement_source.dart';
import '../test_utils.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';

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

  group('Tag Logic Tests', () {
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

      final Labeler labeler = Labeler(trustGraph, delegateResolver: delegateResolver);
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

      final Labeler labeler = Labeler(trustGraph, delegateResolver: delegateResolver);
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

    test('Filtering by Tag (direct match)', () {
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

      final Labeler labeler = Labeler(trustGraph, delegateResolver: delegateResolver);
      final ContentAggregation aggregation = reduceContentAggregation(
        followNetwork,
        trustGraph,
        delegateResolver,
        ContentResult(delegateContent: byToken),
        labeler: labeler,
      );

      final ContentKey key1 = ContentKey(getToken(subject1));
      final ContentKey key2 = ContentKey(getToken(subject2));
      expect(aggregation.subjects[key1]!.tags, contains('#politics'));
      expect(aggregation.subjects[key1]!.tags, contains('#news'));
      expect(aggregation.subjects[key2]!.tags, contains('#world'));
      expect(aggregation.subjects[key1]!.tags, isNot(contains('#world')));
    });
  });
}
