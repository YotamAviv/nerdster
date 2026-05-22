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
        equivalent: 'world',
        canonical: 'news',
      );

      // canonical = verb field value, equivalent = with.otherSubject value
      expect(s.canonical, equals('news'));
      expect(s.equivalent, equals('world'));
      expect(s.not, isFalse);
    });

    test('dontEquate statement fields', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement s = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'python',
        canonical: 'snake',
        verb: EquivalenceVerb.dontEquate,
      );

      expect(s.canonical, equals('snake'));
      expect(s.equivalent, equals('python'));
      expect(s.not, isTrue);
    });

    test('getDistinctSignature is symmetric for equate', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement s1 = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'world',
        canonical: 'news',
      );
      final EquivalenceStatement s2 = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'news',
        canonical: 'world',
      );

      expect(s1.getDistinctSignature(), equals(s2.getDistinctSignature()));
    });

    test('getDistinctSignature same for equate vs dontEquate (latest supersedes)', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement eq = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'world',
        canonical: 'news',
      );
      final EquivalenceStatement dont = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'world',
        canonical: 'news',
        verb: EquivalenceVerb.dontEquate,
      );

      expect(eq.getDistinctSignature(), equals(dont.getDistinctSignature()));
    });

    test('getDistinctSignature same for relate vs equate (latest supersedes)', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement eq = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'horses',
        canonical: 'equestrian',
      );
      final EquivalenceStatement rel = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.relate,
      );

      expect(eq.getDistinctSignature(), equals(rel.getDistinctSignature()));
    });

    test('getDistinctSignature is symmetric for relate', () {
      final Json iJson = mockKey('identity1');
      final EquivalenceStatement s1 = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.relate,
      );
      final EquivalenceStatement s2 = makeEquivalenceStatement(
        iJson: iJson,
        equivalent: 'equestrian',
        canonical: 'horses',
        verb: EquivalenceVerb.relate,
      );

      expect(s1.getDistinctSignature(), equals(s2.getDistinctSignature()));
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
      expect(agg.mostTags, contains('world'));
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
        equivalent: 'world',
        canonical: 'news',
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

      expect(agg.tagEquivalence['world'], equals('news'));
      expect(agg.tagEquivalence['news'], equals('news'));
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
        equivalent: 'world',
        canonical: 'news',
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

      expect(agg.mostTags, contains('news'));
      expect(agg.mostTags, isNot(contains('world')));
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
        equivalent: 'world',
        canonical: 'news',
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
      final String canonicalFilter = agg.tagEquivalence['news'] ?? 'news';
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

    test('relate supersedes earlier equate from same issuer', () {
      final setup = buildSetup();
      final DateTime t1 = DateTime(2025, 10, 1);
      final DateTime t2 = DateTime(2026, 2, 1);

      // Older: equate horses → equestrian
      final EquivalenceStatement equateOld = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.equate,
        time: t1,
      );
      // Newer: relate horses ~ equestrian (supersedes the equate)
      final EquivalenceStatement relateNew = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.relate,
        time: t2,
      );

      final ContentResult contentResult = ContentResult(delegateContent: {
        DelegateKey(setup.delegateToken): [],
      });
      // Descending time order: newer first
      final EquivalenceResult equivalenceResult = EquivalenceResult(delegateContent: {
        DelegateKey(setup.delegateToken): [relateNew, equateOld],
      });

      final ContentAggregation agg = reduceContentAggregation(
        setup.followNetwork,
        setup.trustGraph,
        setup.delegateResolver,
        contentResult,
        equivalenceResult: equivalenceResult,
        labeler: setup.labeler,
      );

      // relate keeps both tags independent — no equivalence mapping
      expect(agg.tagEquivalence['horses'], isNot(equals('equestrian')),
          reason: 'equate should be superseded by relate');
      // relate creates a symmetric peer entry
      expect(agg.tagRelate.peersOf('horses'), contains('equestrian'));
      expect(agg.tagRelate.peersOf('equestrian'), contains('horses'));
    });

    test('relate is transitive: A~B and B~C implies A~C', () {
      final setup = buildSetup();
      final EquivalenceStatement relateAB = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: 'horses',
        canonical: 'classic',
        verb: EquivalenceVerb.relate,
      );
      final EquivalenceStatement relateBC = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: 'equestrian',
        canonical: 'horses',
        verb: EquivalenceVerb.relate,
      );

      final ContentResult contentResult = ContentResult(delegateContent: {
        DelegateKey(setup.delegateToken): [],
      });
      // relateBC stamped after relateAB by TestClock; list must be newest-first
      final EquivalenceResult equivalenceResult = EquivalenceResult(delegateContent: {
        DelegateKey(setup.delegateToken): [relateBC, relateAB],
      });

      final ContentAggregation agg = reduceContentAggregation(
        setup.followNetwork,
        setup.trustGraph,
        setup.delegateResolver,
        contentResult,
        equivalenceResult: equivalenceResult,
        labeler: setup.labeler,
      );

      expect(agg.tagRelate.peersOf('horses'), containsAll(['classic', 'equestrian']));
      expect(agg.tagRelate.peersOf('classic'), containsAll(['horses', 'equestrian']));
      expect(agg.tagRelate.peersOf('equestrian'), containsAll(['classic', 'horses']));
    });

    test('dontEquate prevents grouping', () {
      final setup = buildSetup();
      // #python and #snake are explicitly NOT equivalent
      final EquivalenceStatement dont = makeEquivalenceStatement(
        iJson: setup.delegateKey,
        equivalent: 'python',
        canonical: 'snake',
        verb: EquivalenceVerb.dontEquate,
      );
      final ContentResult contentResult = ContentResult(delegateContent: {
        DelegateKey(setup.delegateToken): [],
      });
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
      expect(agg.tagEquivalence['python'], isNot(equals('snake')));
      expect(agg.tagEquivalence['snake'], isNot(equals('python')));
    });
  });

  group('Tag equivalence network-order priority', () {
    _TwoSetup buildTwoSetup() {
      final Json povIdentityKey = mockKey('pov_identity');
      final String povIdentityToken = Jsonish(povIdentityKey).token;
      final Json povDelegateKey = mockKey('pov_delegate');
      final String povDelegateToken = Jsonish(povDelegateKey).token;

      final Json peerIdentityKey = mockKey('peer_identity');
      final String peerIdentityToken = Jsonish(peerIdentityKey).token;
      final Json peerDelegateKey = mockKey('peer_delegate');
      final String peerDelegateToken = Jsonish(peerDelegateKey).token;

      final TrustStatement povDelegateStmt = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: povDelegateKey,
        iJson: povIdentityKey,
        domain: 'nerdster.org',
      );
      final TrustStatement peerDelegateStmt = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: peerDelegateKey,
        iJson: peerIdentityKey,
        domain: 'nerdster.org',
      );

      // POV is first in identities list — network order.
      final FollowNetwork followNetwork = FollowNetwork(
        fcontext: 'test',
        povIdentity: IdentityKey(povIdentityToken),
        identities: [IdentityKey(povIdentityToken), IdentityKey(peerIdentityToken)],
      );
      final TrustGraph trustGraph = TrustGraph(
        pov: IdentityKey(povIdentityToken),
        distances: {
          IdentityKey(povIdentityToken): 0,
          IdentityKey(peerIdentityToken): 1,
        },
        edges: {
          IdentityKey(povIdentityToken): [povDelegateStmt],
          IdentityKey(peerIdentityToken): [peerDelegateStmt],
        },
      );
      final DelegateResolver delegateResolver = DelegateResolver(trustGraph);
      final Labeler labeler = Labeler(trustGraph, delegateResolver: delegateResolver);

      return _TwoSetup(
        povDelegateKey: povDelegateKey,
        povDelegateToken: povDelegateToken,
        peerDelegateKey: peerDelegateKey,
        peerDelegateToken: peerDelegateToken,
        followNetwork: followNetwork,
        trustGraph: trustGraph,
        delegateResolver: delegateResolver,
        labeler: labeler,
      );
    }

    ContentAggregation run(_TwoSetup s, EquivalenceResult equivalenceResult) {
      return reduceContentAggregation(
        s.followNetwork,
        s.trustGraph,
        s.delegateResolver,
        ContentResult(delegateContent: {
          DelegateKey(s.povDelegateToken): [],
          DelegateKey(s.peerDelegateToken): [],
        }),
        equivalenceResult: equivalenceResult,
        labeler: s.labeler,
      );
    }

    test('POV relate beats peer equate for same pair', () {
      final s = buildTwoSetup();
      final EquivalenceStatement povRelate = makeEquivalenceStatement(
        iJson: s.povDelegateKey,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.relate,
      );
      final EquivalenceStatement peerEquate = makeEquivalenceStatement(
        iJson: s.peerDelegateKey,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.equate,
      );

      final agg = run(s, EquivalenceResult(delegateContent: {
        DelegateKey(s.povDelegateToken): [povRelate],
        DelegateKey(s.peerDelegateToken): [peerEquate],
      }));

      expect(agg.tagRelate.peersOf('horses'), contains('equestrian'),
          reason: 'POV relate should win over peer equate');
      expect(agg.tagEquivalence['horses'], isNot(equals('equestrian')),
          reason: 'peer equate should be overridden by POV relate');
    });

    test('POV equate beats peer relate for same pair', () {
      final s = buildTwoSetup();
      final EquivalenceStatement povEquate = makeEquivalenceStatement(
        iJson: s.povDelegateKey,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.equate,
      );
      final EquivalenceStatement peerRelate = makeEquivalenceStatement(
        iJson: s.peerDelegateKey,
        equivalent: 'horses',
        canonical: 'equestrian',
        verb: EquivalenceVerb.relate,
      );

      final agg = run(s, EquivalenceResult(delegateContent: {
        DelegateKey(s.povDelegateToken): [povEquate],
        DelegateKey(s.peerDelegateToken): [peerRelate],
      }));

      expect(agg.tagEquivalence['horses'], equals('equestrian'),
          reason: 'POV equate should win over peer relate');
      expect(agg.tagRelate.peersOf('horses'), isNot(contains('equestrian')),
          reason: 'peer relate should be overridden by POV equate');
    });
  });
}

class _TwoSetup {
  final Json povDelegateKey;
  final String povDelegateToken;
  final Json peerDelegateKey;
  final String peerDelegateToken;
  final FollowNetwork followNetwork;
  final TrustGraph trustGraph;
  final DelegateResolver delegateResolver;
  final Labeler labeler;

  _TwoSetup({
    required this.povDelegateKey,
    required this.povDelegateToken,
    required this.peerDelegateKey,
    required this.peerDelegateToken,
    required this.followNetwork,
    required this.trustGraph,
    required this.delegateResolver,
    required this.labeler,
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
