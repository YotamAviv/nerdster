import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/model.dart';
import '../test_utils.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  group('EquivalenceStatement parsing', () {
    test('equate statement fields', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement s = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: '#world',
        canonical: '#news',
      );

      // string = canonical (verb field), otherString = equivalent (with.otherSubject)
      expect(s.string, equals('#news'));
      expect(s.otherString, equals('#world'));
      expect(s.not, isFalse);
    });

    test('dontEquate statement fields', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement s = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: '#python',
        canonical: '#snake',
        not: true,
      );

      expect(s.string, equals('#snake'));
      expect(s.otherString, equals('#python'));
      expect(s.not, isTrue);
    });

    test('getDistinctSignature is symmetric for equate', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement s1 = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: '#world',
        canonical: '#news',
      );
      final EquivalenceStatement s2 = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: '#news',
        canonical: '#world',
      );

      expect(s1.getDistinctSignature(), equals(s2.getDistinctSignature()));
    });

    test('getDistinctSignature differs for equate vs dontEquate', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement eq = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: '#world',
        canonical: '#news',
      );
      final EquivalenceStatement dont = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: '#world',
        canonical: '#news',
        not: true,
      );

      expect(eq.getDistinctSignature(), isNot(equals(dont.getDistinctSignature())));
    });
  });

  group('Tag equivalence in feed pipeline', () {
    // Shared setup helpers
    _Setup buildSetup() {
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
      final FollowNetwork followNetwork = FollowNetwork(
        fcontext: 'test',
        povIdentity: IdentityKey(identityToken),
        identities: [IdentityKey(identityToken)],
      );
      final TrustGraph trustGraph = TrustGraph(
        pov: IdentityKey(identityToken),
        distances: {IdentityKey(identityToken): 0},
        edges: {
          IdentityKey(identityToken): [delegateStatement]
        },
      );
      final DelegateResolver delegateResolver = DelegateResolver(trustGraph);
      final Labeler labeler = Labeler(trustGraph, delegateResolver: delegateResolver);
      return _Setup(
        identityToken: identityToken,
        delegateKey: delegateKey,
        delegateToken: delegateToken,
        followNetwork: followNetwork,
        trustGraph: trustGraph,
        delegateResolver: delegateResolver,
        labeler: labeler,
      );
    }

    test('tagEquivalence is empty with no EquivalenceStatements', () {
      final setup = buildSetup();
      final ContentStatement s = makeContentStatement(
        verb: ContentVerb.rate,
        subject: createTestSubject(title: 'Article 1'),
        comment: '#world',
        iJson: setup.delegateKey,
      );
      final ContentResult contentResult = ContentResult(delegateContent: {
        DelegateKey(setup.delegateToken): [s],
      });

      final ContentAggregation agg = reduceContentAggregation(
        setup.followNetwork,
        setup.trustGraph,
        setup.delegateResolver,
        contentResult,
        labeler: setup.labeler,
      );

      expect(agg.tagEquivalence, isEmpty);
      expect(agg.mostTags, contains('#world'));
    });

    test('tagEquivalence maps non-canonical to canonical', () {
      final setup = buildSetup();
      final ContentStatement s = makeContentStatement(
        verb: ContentVerb.rate,
        subject: createTestSubject(title: 'Article 1'),
        comment: '#world',
        iJson: setup.delegateKey,
      );
      final EquivalenceStatement eq = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: '#world',
        canonical: '#news',
      );
      final ContentResult contentResult = ContentResult(delegateContent: {
        DelegateKey(setup.delegateToken): [s],
      });
      final EquivalenceResult equivalenceResult = EquivalenceResult(delegateContent: {
        DelegateKey(setup.delegateToken): [eq],
      });

      final ContentAggregation agg = reduceContentAggregation(
        setup.followNetwork,
        setup.trustGraph,
        setup.delegateResolver,
        contentResult,
        equivalenceResult: equivalenceResult,
        labeler: setup.labeler,
      );

      expect(agg.tagEquivalence['#world'], equals('#news'));
      expect(agg.tagEquivalence['#news'], equals('#news'));
    });

    test('mostTags counts canonical, not individual equivalents', () {
      final setup = buildSetup();
      // Two articles: one tagged #world, one tagged #news. They equate → canonical #news.
      // mostTags should count #news twice, not have both #world and #news separately.
      final ContentStatement s1 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: createTestSubject(title: 'Article 1'),
        comment: '#world',
        iJson: setup.delegateKey,
      );
      final ContentStatement s2 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: createTestSubject(title: 'Article 2'),
        comment: '#news',
        iJson: setup.delegateKey,
      );
      final EquivalenceStatement eq = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: '#world',
        canonical: '#news',
      );
      final ContentResult contentResult = ContentResult(delegateContent: {
        DelegateKey(setup.delegateToken): [s2, s1], // descending time order
      });
      final EquivalenceResult equivalenceResult = EquivalenceResult(delegateContent: {
        DelegateKey(setup.delegateToken): [eq],
      });

      final ContentAggregation agg = reduceContentAggregation(
        setup.followNetwork,
        setup.trustGraph,
        setup.delegateResolver,
        contentResult,
        equivalenceResult: equivalenceResult,
        labeler: setup.labeler,
      );

      expect(agg.mostTags, contains('#news'));
      expect(agg.mostTags, isNot(contains('#world')));
    });

    test('tag filter by canonical matches content tagged with equivalent', () {
      final setup = buildSetup();
      final Map<String, dynamic> subject1 =
          createTestSubject(type: ContentType.article, url: 'https://sub1.com');
      final Map<String, dynamic> subject2 =
          createTestSubject(type: ContentType.article, url: 'https://sub2.com');

      // s1 tagged #world (equivalent to canonical #news)
      final ContentStatement s1 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject1,
        comment: '#world',
        iJson: setup.delegateKey,
      );
      // s2 tagged #sports (unrelated)
      final ContentStatement s2 = makeContentStatement(
        verb: ContentVerb.rate,
        subject: subject2,
        comment: '#sports',
        iJson: setup.delegateKey,
      );
      final EquivalenceStatement eq = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: '#world',
        canonical: '#news',
      );
      final ContentResult contentResult = ContentResult(delegateContent: {
        DelegateKey(setup.delegateToken): [s2, s1], // descending time order
      });
      final EquivalenceResult equivalenceResult = EquivalenceResult(delegateContent: {
        DelegateKey(setup.delegateToken): [eq],
      });

      final ContentAggregation agg = reduceContentAggregation(
        setup.followNetwork,
        setup.trustGraph,
        setup.delegateResolver,
        contentResult,
        equivalenceResult: equivalenceResult,
        labeler: setup.labeler,
      );

      // Apply the same filter logic as shouldShow
      final String canonicalFilter = agg.tagEquivalence['#news'] ?? '#news';
      bool matchesFilter(SubjectAggregation subject) =>
          subject.tags.any((t) => (agg.tagEquivalence[t] ?? t) == canonicalFilter);

      final ContentKey key1 = ContentKey(getToken(subject1));
      final ContentKey key2 = ContentKey(getToken(subject2));

      expect(agg.subjects[key1], isNotNull);
      expect(agg.subjects[key2], isNotNull);
      expect(matchesFilter(agg.subjects[key1]!), isTrue,
          reason: 'subject tagged #world should match filter #news');
      expect(matchesFilter(agg.subjects[key2]!), isFalse,
          reason: 'subject tagged #sports should not match filter #news');
    });

    test('dontEquate prevents grouping', () {
      final setup = buildSetup();
      // #python and #snake are explicitly NOT equivalent
      final EquivalenceStatement dont = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: '#python',
        canonical: '#snake',
        not: true,
      );
      final ContentResult contentResult = ContentResult();
      final EquivalenceResult equivalenceResult = EquivalenceResult(delegateContent: {
        DelegateKey(setup.delegateToken): [dont],
      });

      final ContentAggregation agg = reduceContentAggregation(
        setup.followNetwork,
        setup.trustGraph,
        setup.delegateResolver,
        contentResult,
        equivalenceResult: equivalenceResult,
        labeler: setup.labeler,
      );

      // Neither should map to the other
      expect(agg.tagEquivalence['#python'], isNot(equals('#snake')));
      expect(agg.tagEquivalence['#snake'], isNot(equals('#python')));
    });
  });
}

class _Setup {
  final String identityToken;
  final Json delegateKey;
  final String delegateToken;
  final FollowNetwork followNetwork;
  final TrustGraph trustGraph;
  final DelegateResolver delegateResolver;
  final Labeler labeler;

  _Setup({
    required this.identityToken,
    required this.delegateKey,
    required this.delegateToken,
    required this.followNetwork,
    required this.trustGraph,
    required this.delegateResolver,
    required this.labeler,
  });
}
