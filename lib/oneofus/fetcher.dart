import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../main.dart';
import '../prefs.dart'; // CODE: Kludgey way to include, but works with phone codebase.
import 'distincter.dart';
import 'fire_factory.dart';
import 'jsonish.dart';
import 'measure.dart';
import 'oou_verifier.dart';
import 'statement.dart';
import 'util.dart';

/// BUG: 3/12/25: Mr. Burner Phone revoked, signed in, still managed to clear, and caused data corruption.
/// I wasn't able to reproduce that bug (lost the private key), and I've changed the code since
/// by adding transactions, and so that bug might be fixed.
/// Regardless, the Fetcher factoy CTOR seems dangerous and sloppy.
///
/// OneofusNet / GreedyBfsTrust should be able to create and manage their own Fetchers.
/// Those Fetchers could retain their expired state for their lifetimes.
/// But I'm not sure that helps in any way.
/// - created expired at a token and will stay that way
/// - created not expired and will stay that way.
/// Same for FollowNet and its Nerdster Fetchers
///
/// Now we want to change network center or settings and not re-fetch what we don't have to.
/// These settings make OneofusNet dirty, and it could proceed as follows:
/// - take all Fetchers off the market
/// - run GreedyBfsTrust and re-use what we can (non-revoked fetchers, same revoked fetchers)
/// Same for FollowNet
///
/// CODE:
/// - remove the factory CTOR and make OneofusNet and FollowNet the source for Fetchers.
/// - they will of course have to create Fetchers, but other code shouldn't do what they do;
///   instead the other code (ContentBase, various trees, ...) should get them from OneofusNet, FollowNet
///
/// Options:
/// - OneofusNet / FollowNetL either expose the Fetchers or just their statements.
///   Leaning Fetcher:
///   - revokedAt token, time
///   - push() (must have)
///
/// Plan:
/// OneofusNet:
/// getFetcher(String oneofus)
/// GreedyBfsTrust / FetcherNode:
/// FetcherNode already has a _fetcher member, and it seems perfect.
/// But there's work to do if we want to reuse the Fetchers.
/// FetcherNode.clear:
/// - retire all the fetchers from the existing FetcherNodes, re-use them when appropriate in the internal ctor
///
/// FollowNet:
///
/// While I'm at it:
/// - DONE: actual transactions (transactionally check previous and push next statement)
/// - refresh fetchers, maybe. That'd mean calling fetch() again (or refresh()) on a non-revoked fetcher
///   to get only newer statements.
///   That'd make the demo a bit quicker, allow leaving the window open and just re-fetching.
///   - Measure first, make sure it's worth the hassle.
///
///

/// Cloud Functions distinct, order, tokens, checkPervious...
///
/// The only reason we use Firebase Cloud Functions is performance.
/// - distinct: send the client less data over
/// - omit [I, statement]: send the client less data
/// - (EXPERIMENTAL: send tokens, omit [signature, previous]:  measurably faster)
///
/// The Cloud Functions distinct is currently not complete (does not consider "other"), and so
/// for
///
/// Developing using Cloud Functions is challenging, espeically on Linux, and so I want to keep
/// the other path alive and for use with unit testing use FakeFirebase which can't Cloud Functions.
///
/// Integration Testing:
/// With non-trivial code in JavaScript cloud functions, integration testing is required.
/// As Firebase does not support Linux, this necessarily requires running in Chrome or Android (emulator).
/// I'm partway there with some tests implemented in demotest/cases. I don't want to re-implement
/// a test framework, and so I expect to end up somewhere in the middle (and yes, I have and will
/// always have bugs;)
///
/// Testing issues: cloud functions options, assert checka, previous token checks, revokedAt, etc...
/// Cloud functions require "includeId" for "checkPrevious"
/// I have a Fetcher integration test for checkPrevious
/// Fetcher irl needs neither checkPrevious nor includeId.
/// I don't want to slow the code down just so that I can test the code. But i am (not by much)
///
/// DEFER: filters (ex, past month)
///
/// DEFER: Cloud distinct to regard "other" subject.
/// All the pieces are there, and it shouldn't be hard. That said, relate / equate are rarely used.

/// EXPERIMENTAL: Get and use token from cloud instead of computing it.
/// This allows us to omit [previous, signature].
/// It's a destabilizing change to deal with Jsonish instances whose tokens aren't the tokens we'd
/// compute from their Json, but it seems to work.
/// Options:
/// - Don't even bother.
/// - Move to Jsonish over Json wherever possible, and be very careful (ideally enforce) not to
///   compute tokens from Jsonish.json.
///   - remove Jsonish.json (override [] instead)
///   - remove Statement.json (ppJson or jsonish only instead)

/// This class combines much functionality, which is messy, but it was even messier with multiple classes:
/// - Firestore fetch/push, cache
/// - revokeAt (part of trust algorithm)
/// - blockchain maintenance and verification (previous token)
/// - signature maintenance and verification
///
/// Blockchain notarization (I've been loosly calling this this, but it's probably inaccurate):
/// Each signed statement (other than first) includes the token of the previous statement.
/// Revoking a key requires identifying its last, valid statement token. Without this, it doesn't work.

final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);

abstract class Corruptor {
  void corrupt(String token, String error);
}

class Fetcher {
  static final OouVerifier _verifier = OouVerifier();

  static final Map<String, Fetcher> _fetchers = <String, Fetcher>{};

  static final Measure mFire = Measure('fire');
  static final Measure mVerify = Measure('verify');

  final FirebaseFirestore fire;
  final FirebaseFunctions? functions;
  final String domain;
  final String token;
  final bool testingNoVerify;

  // 3 states:
  // - not revoked : null
  // - revoked at token (last legit statement) : token
  // - blocked : any string that isn't a statement token makes this blocked (revokedAt might be "since forever")
  String? _revokeAt; // set by others to let this object know
  DateTime? _revokeAtTime; // set by this object after querying the db
  // MAINTAIN: Cloud Functions and FakeFirestore paths should use _cached similary ({distinct, revoked}).
  List<Statement>? _cached;
  String? _lastToken;

  static void clear() => _fetchers.clear();

  // 3/12/25: BUG: Corruption, Burner Phone pushed using a revoked delegate, not sure how (couldn't
  // reproduce), but there is much be careful of here.
  // One possible danger is: use the Factory constructor to create an un-revoked fetcher, which
  // should be revoked and would be revoked had FollowNet or OneofusNet created it.
  //
  // If we ever fetched a statement for {domain, token}, then that statement remains correct forever.
  // But if we change center (POV) or learn about a new trust or block, then that might change revokedAt.
  static resetRevokedAt() {
    for (Fetcher f in _fetchers.values) {
      if (f._revokeAt != null) {
        f._cached = null;
        f._revokeAt = null;
        f._revokeAtTime = null;
      }
    }
  }

  factory Fetcher(String token, String domain, {bool testingNoVerify = false}) {
    String key = '$token$domain';
    FirebaseFirestore fire = FireFactory.find(domain);
    FirebaseFunctions? functions = FireFactory.findFunctions(domain);
    Fetcher out;
    if (_fetchers.containsKey(key)) {
      out = _fetchers[key]!;
      assert(out.fire == fire);
      assert(out.testingNoVerify == testingNoVerify);
    } else {
      out = Fetcher.internal(token, domain, fire, functions, testingNoVerify: testingNoVerify);
      _fetchers[key] = out;
    }
    return out;
  }

  Fetcher.internal(this.token, this.domain, this.fire, this.functions,
      {this.testingNoVerify = false});

  // Oneofus trust does not allow 2 different keys replace a key (that's a conflict).
  // Fetcher isn't responsible for implementing that, but I am going to assume that
  // something else does and I'll rely on that, assert that, and not implement code to update
  // revokeAt.
  //
  // Changing center is encouraged, and we'd like to make that fast (without re-fetching too much).
  //
  // Moving to clouddistinct... What if
  //
  void setRevokeAt(String revokeAt) {
    // CONSIDER: I don't think that even setting the same value twice should be supported.  I tried
    // that and failed tests on follow net and delegate related stuff. Hmm..
    // assert(_revokeAt == null);
    // Only allowing revoke before any fetch seems reasonable as well, but that fails tests, too.
    // assert(_cached == null);
    if (_revokeAt == revokeAt) return;
    assert(_revokeAt == null);
    _revokeAt = revokeAt;
    _revokeAtTime = null;
    _cached = null;
  }

  String? get revokeAt => _revokeAt;

  DateTime? get revokeAtTime => _revokeAtTime;

  bool get isCached => b(_cached);

  static const Map fetchParamsProto = {
    "distinct": true,
    "omit": ['statement', 'I'],
    "orderStatements": "false",

    "checkPrevious": true,
    "includeId": true, // includeId required for checkPrevious, not needed but tested and liked.

    // EXPERIMENTAL: "includeId": true,
    // EXPERIMENTAL: "omit": ['statement', 'I', 'signature', 'previous']
  };

  Future<void> fetch() async {
    if (b(_cached)) return;
    // TEMP: await Future.delayed(Duration(milliseconds: 300));
    try {
      _cached = <Statement>[];
      DateTime? time;
      if (functions != null && Prefs.cloudFetchDistinct.value) {
        Map params = Map.of(fetchParamsProto);
        params["token"] = token;
        if (_revokeAt != null) params["revokeAt"] = revokeAt;
        final result = await mFire.mAsync(() {
          return functions!.httpsCallable('clouddistinct').call(params);
        });
        List statements = result.data["statements"];
        if (_revokeAt != null) {
          if (statements.isNotEmpty) {
            assert(statements.first['id'] == _revokeAt);
            // without includeId, this might work:
            // assert(getToken(statements.first) == _revokeAt);
            _revokeAtTime = parseIso(statements.first['time']);
          } else {
            _revokeAtTime = DateTime(0); // "since always" (or any unknown token);
          }
        }
        if (statements.isEmpty) return; // QUESTIONABLE
        final Json iKey = result.data['I'];
        final String iKeyToken = getToken(iKey);
        assert(iKeyToken == token);
        for (Json j in statements) {
          DateTime jTime = parseIso(j['time']);
          if (time != null) assert(jTime.isBefore(time));
          time = jTime;
          j['statement'] = domain2statementType[domain]!;
          j['I'] = iKey; // PERFORMANCE: Allow token in 'I' in statements; we might be already.
          j.remove('id');

          // EXPERIMENTAL: "EXPERIMENTAL" tagged where the code allows us to not compute the tokens
          // but just use the stored values, which allows us to not ask for [signature, previous].
          // The changes worked, but the performance hardly changed. And with this, we wouldn't have
          // [signature, previous] locally, couldn't verify statements, and there'd be more code
          // paths. So, no.
          // Jsonish jsonish = mVerify.mSync(() => Jsonish(j, serverToken));
          // String serverToken = j['id'];
          // j.remove('id');
          // assert(jsonish.token == serverToken);

          Jsonish jsonish = mVerify.mSync(() => Jsonish(j));
          Statement statement = Statement.make(jsonish);
          _cached!.add(statement);
        }
      } else {
        final CollectionReference<Map<String, dynamic>> collectionRef =
            fire.collection(token).doc('statements').collection('statements');

        // query _revokeAtTime
        if (_revokeAt != null && _revokeAtTime == null) {
          DocumentReference<Json> doc = collectionRef.doc(_revokeAt);
          final DocumentSnapshot<Json> docSnap = await mFire.mAsync(doc.get);
          if (b(docSnap.data())) {
            final Json data = docSnap.data()!;
            _revokeAtTime = parseIso(data['time']);
          } else {
            _revokeAtTime = DateTime(0); // "since always" (or any unknown token)
          }
        }

        Query<Json> query = collectionRef.orderBy('time', descending: true);
        if (_revokeAtTime != null) {
          query = query.where('time', isLessThanOrEqualTo: formatIso(_revokeAtTime!));
        }
        QuerySnapshot<Json> snapshots = await mFire.mAsync(query.get);
        bool first = true;
        String? previousToken;
        DateTime? previousTime;
        for (final docSnapshot in snapshots.docs) {
          final Json data = docSnapshot.data();
          Jsonish jsonish;
          if (Prefs.skipVerify.value || testingNoVerify) {
            jsonish = mVerify.mSync(() => Jsonish(data));
          } else {
            jsonish = await mVerify.mAsync(() => Jsonish.makeVerify(data, _verifier));
          }

          // newest to oldest
          // First: previousToken is null
          // middles: statement.token = previousToken
          // Last: statement.token = null
          DateTime time = parseIso(jsonish['time']);
          if (first) {
            first = false;
          } else {
            if (jsonish.token != previousToken) {
              String error =
                  'Notarization violation: ($domain/$token): ${jsonish.token} != $previousToken';
              print(error);
              throw error;
            }
            if (!time.isBefore(previousTime!)) {
              String error = '!Descending: ($domain/$token): $time >= $previousTime';
              print(error);
              throw error;
            }
          }
          previousToken = data['previous'];
          previousTime = time;

          _cached!.add(Statement.make(jsonish));
        }
      }

      // Maintain Cloud Functions or not behave similarly.
      // Callilng distinct(..) on the Cloud Functions is required for that as the Cloud impl is not
      // complete, and I wouldn't want to rely on it anyway as it can't be tested using our
      // FakeFirebase unit tests.
      assert(fetchParamsProto.containsKey('distinct'));
      _cached = distinct(_cached!);
      if (_cached!.isNotEmpty) _lastToken = _cached!.first.token;
    } catch (e) {
      corruptor.corrupt(token, e.toString());
    }
  }

  List<Statement> get statements => _cached!;

  // Side effects: add 'previous', 'signature'
  Future<Statement> push(Json json, StatementSigner? signer) async {
    assert(_revokeAt == null);

    if (_cached == null) await fetch(); // Was green.

    // add 'previous', verify time is later than last statement
    Statement? previous;
    if (_cached!.isNotEmpty) {
      previous = _cached!.first;

      // assert time is after last statement time
      DateTime prevTime = previous.time;
      DateTime thisTime = parseIso(json['time']!);
      assert(thisTime.isAfter(prevTime));

      // for load dump
      if (json.containsKey('previous')) assert(json['previous'] == _lastToken);
    }
    if (_lastToken != null) json['previous'] = _lastToken;

    // sign (verify)
    String? signature = json['signature'];
    Jsonish jsonish;
    if (signer != null) {
      assert(signature == null);
      jsonish = await Jsonish.makeSign(json, signer);
    } else {
      assert(signature != null);
      jsonish = await Jsonish.makeVerify(json, _verifier);
    }

    Statement statement = Statement.make(jsonish);
    _cached!.insert(0, statement);
    _cached = distinct(_cached!);
    _lastToken = jsonish.token;

    final fireStatements = fire.collection(token).doc('statements').collection('statements');
    // Transaction!
    // TODO: TEST: Testing might be easier after the change away from the factory CTOR.
    await fire.runTransaction((_) async {
      Query<Json> query = fireStatements.orderBy('time', descending: true);
      QuerySnapshot<Json> snapshots = await query.get();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snapshots.docs;
      if (docs.isEmpty) {
        assert(!jsonish.containsKey('previous'));
      } else {
        final docSnapshot0 = docs.elementAt(0);
        if (docSnapshot0.id != jsonish['previous']) {
          String error = 'Your data was stale. Reload. (${docSnapshot0.id} != ${jsonish.token})';
          throw Exception(error);
        }
      }
      // (An old thought: Don't 'await', Ajax!)
      await fireStatements.doc(jsonish.token).set(jsonish.json).then((doc) {}, onError: (e) {
        throw e;
      });
    });

    return statement;
  }

  Future<Iterable<Statement>> fetchAllNoVerify() async {
    List<Statement> out = <Statement>[];
    FirebaseFirestore fire = FireFactory.find(domain);
    CollectionReference<Json> fireStatements =
        fire.collection(token).doc('statements').collection('statements');
    Query<Json> query = fireStatements.orderBy('time', descending: true);
    QuerySnapshot<Json> snapshots = await query.get();
    for (final docSnapshot in snapshots.docs) {
      final Json data = docSnapshot.data();
      Jsonish jsonish = Jsonish(data);
      assert(docSnapshot.id == jsonish.token);
      out.add(Statement.make(jsonish));
    }
    return out;
  }

  @override
  String toString() => 'Fetcher: $domain $token';
}
