import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart'; // You have to add this manually, for some reason it cannot be added automatically
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/progress.dart';

import '../prefs.dart'; // CODE: Kludgey way to include, but might work for phone codebase.
import 'distincter.dart';
import 'fire_factory.dart';
import 'jsonish.dart';
import 'oou_verifier.dart';
import 'statement.dart';
import 'util.dart';

/// Cloud functions distinct...
///
/// Integration Testing:
/// With non-trivial code in JavaScript cloud functions, integration testing is required.
/// As Firebase does not support Linux, this will necessarily have to run in Chrome or on the Android emulator.
/// I'm partway there with some tests implemented in demotest/cases. I don't want to re-implement
/// a test framework, and so I expect to end up somewhere in the middle (and yes, I have and will
/// always have bugs;)
///
/// Nerdster web app, Nerdster content first.
///
/// Deploy a Cloud fuunction
/// - DEFER: revokedAt
/// - DEFER: other filters (ex, past month)
///
/// Maybe add a DEV menu helper / tester
///
/// CONCERN: How to get the full "I" key. Do we actually need it?
/// - I don't think we need it.
/// - We need it in NetTile, probably to show the key, which we like doing..
///   Can return this from cloud func: {"key": key, "statements": statements}
///
/// Modify Statement / ContentStatement
/// - deal with "I" token instead of full key
///
/// DEFER: Dealing with revokedAt
///
/// -------- Stop here and compare PROD performance --------------
/// - FollowNet: 0:00:01.760300 (fetchDistinct)
/// - FollowNet: 0:00:02.640401
/// So good.. Probably go with it.
///
/// DONE: get 'clear' cleared.
/// Done: Assert on the descending order.
///
/// -------- Stop here and compare PROD Oneofus performance --------------
///
/// TODO: Pass the correct token (it can't be computed without previous, "I", "statement")
///
/// TODO: Clean up index.js
/// - JavaScript unit testing
/// - Josonish.compute token
/// - trust and content statement verbs..
///
/// NEXT: Consider "other" subject, doc a little
///
/// TODO: Address testing:
/// - possible on emulaotr
///
/// Down the line:
/// TODO: Modify Trust1 to be just greedy, no revoking what was trusted
/// TODO: revokeAt in request

/// This class combines much functionality, which is messy, but it was even messier with multiple classes:
/// - Firestore fetch/push, cache
/// - revokeAt (part of trust algorithm)
/// - blockchain maintenance and verification (previous token)
/// - signature maintenance and verification
///
/// Blockchain:
/// Each signed statement (other than first) includes the token of the previous statement.
/// Revoking a key requires identifying its last, valid statement token. Without this, it doesn't work.
///
/// revokeAt: before and current:
/// before:
/// - OneofusNet and its FetcherNode have been responsible for setting revokeAt
/// - Fetcher.fetch() only fetches up to revokedAt; setRevokedAt trims the cache.
/// - refreshing OneofusNet requires re-fetching.
/// current:
/// - (OneofusNet and its FetcherNode remain responsible for setting revokeAt)
/// - Fetcher.fetch() fetches everything so that we can change revokedAt without re-fetching
///   - Fetcher.statements respects revokedAt (doesn't serve everything)
/// - (refreshing OneofusNet no longer requires re-fetching.)
final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);

class Fetcher {
  static int? testingCrashIn;

  static final OouVerifier _verifier = OouVerifier();

  // (I've lost track of the reasoning behind having a final VoidCallback for this.)
  static final VoidCallback changeNotify = clearDistinct;

  static final Map<String, Fetcher> _fetchers = <String, Fetcher>{};

  static final Measure mFire = Measure('fire');
  static final Measure mVerify = Measure('verify');

  final FirebaseFirestore fire;
  final String domain;
  final String token;
  final bool testingNoVerify;

  // 3 states:
  // - not revoked : null
  // - revoked at token (last legit statement) : token
  // - blocked : any string that isn't a toke makes this blocked (revoked since forever)
  String? _revokeAt; // set by others to let me know
  DateTime? _revokeAtTime; // set by me after querying the db

  // Due to clouddistinct, this isn't all statements.
  List<Statement>? _cached;
  String? _lastToken;

  static void clear() => _fetchers.clear();

  static resetRevokedAt() {
    for (Fetcher f in _fetchers.values) {
      f._revokeAt = null;
      f._revokeAtTime = null;
    }
    changeNotify();
  }

  factory Fetcher(String token, String domain, {bool testingNoVerify = false}) {
    String key = '$token$domain';
    FirebaseFirestore fire = FireFactory.find(domain);
    Fetcher out;
    if (_fetchers.containsKey(key)) {
      out = _fetchers[key]!;
      assert(out.fire == fire);
      assert(out.testingNoVerify == testingNoVerify);
    } else {
      out = Fetcher.internal(token, domain, fire, testingNoVerify: testingNoVerify);
      _fetchers[key] = out;
    }
    return out;
  }

  Fetcher.internal(this.token, this.domain, this.fire, {this.testingNoVerify = false});

  // Oneofus trust does not allow 2 different keys replace a key (that's a conflict).
  // Fetcher isn't responsible for implementing that, but I am going to assume that
  // something else does and I'll rely on that and not implement code to update
  // revokeAt.
  //
  // Changing center is encouraged, and we'd like to make that fast (without re-fetching too much).
  //
  // Moving to clouddistinct... What if
  //
  void setRevokeAt(String revokeAt) {
    if (_revokeAt == revokeAt) return;

    _revokeAt = revokeAt;
    _revokeAtTime = null;
    _cached = null; // Have to re-fetch.
    changeNotify();
    return;

    // TEMP: NEW: I don't think that even setting the same value twice should be supported
    // assert(_revokeAt == null);

    // TEMP: NEW: Greedier
    // assert(_cached == null);

    // NEXT: Remove dead code
    // return;
    if (b(_revokeAt)) {
      // Changing revokeAt not supported
      assert(_revokeAt == revokeAt, '$_revokeAt != $revokeAt');
      return;
    }
    changeNotify();
    _revokeAt = revokeAt;

    // If I can't find revokeAtStatement, then something strange is going on unless it's 'since always'
    // CONSIDER: Use the same string for 'since always' (although I should be able to handle any string.)
    // CONSIDER: Warn when it's not 'since always' or a valid past statement token.
    if (b(_cached)) {
      Statement? revokeAtStatement = _cached!.firstWhereOrNull((s) => s.token == _revokeAt);
      if (b(revokeAtStatement)) {
        _revokeAtTime = parseIso(revokeAtStatement!.json['time']);
      } else {
        _revokeAtTime = date0;
      }
    }
  }

  String? get revokeAt => _revokeAt;

  DateTime? get revokeAtTime => _revokeAtTime;

  bool get isCached => b(_cached);

  // NEXT: Rename
  static const Map fetchhParams = {
    "bIncludeId": true,
    "bDistinct": true,
    "bClearClear": true,
    "omit": ['statement', 'I'] // DEFER: ['statement', 'I', 'signature', 'previous']
  };

  Future<void> fetch() async {
    if (b(testingCrashIn) && testingCrashIn! > 0) {
      testingCrashIn = testingCrashIn! - 1;
      if (testingCrashIn == 0) {
        testingCrashIn = null;
        throw Exception('testing Exception');
      }
    }

    if (b(_cached)) return;
    _cached = <Statement>[];

    DateTime? time;
    FirebaseFunctions? functions = FireFactory.findFunctions(domain);
    if (functions != null && Prefs.fetchDistinct.value) {
      Map params = Map.of(fetchhParams);
      params["token"] = token;
      final result = await mFire.mAsync(() {
        return functions.httpsCallable('clouddistinct').call(params);
      });
      List statements = result.data["statements"];
      if (statements.isEmpty) return;
      Json iKey = result.data['I'];
      assert(getToken(iKey) == token);
      _lastToken = result.data["lastToken"];
      for (Json j in statements) {
        DateTime jTime = parseIso(j['time']);
        if (time != null) {
          assert(jTime.isBefore(time));
        }
        time = jTime;
        j['statement'] = domain2statementType[domain]!;
        j['I'] = iKey; // TODO: Allow token in 'I' in statements; we might be already.
        assert(getToken(j['I']) == getToken(iKey));
        String serverToken = j['id'];
        j.remove('id');

        /// CONSIDER: Don't get [signature, previous] from server.
        /// That requires getting and using token from server instead if computing it.
        /// It'd be a destabilizing change to deal with Jsonish instances whose tokens aren't the tokens we'd compute from their Json.
        ///
        /// Options:
        /// - Don't even bother.
        /// - Move to Jsonish over Json wherever possible, and be very careful not to compute the
        ///   token of a Json that you got from a Jsonish.
        ///   - One way to do this might be to
        ///     - not have Jsonish.json (override [] instead)
        ///     - not have Statement.json (ppJson or jsonish only instead)

        Jsonish jsonish = mVerify.mSync(() => Jsonish(j));
        assert(jsonish.token == serverToken);
        Statement statement = Statement.make(jsonish);
        assert(statement.token == serverToken);
        _cached!.add(statement);
      }
    } else {
      CollectionReference<Map<String, dynamic>> fireStatements =
          fire.collection(token).doc('statements').collection('statements');

      // query _revokeAtTime
      if (_revokeAt != null && _revokeAtTime == null) {
        DocumentReference<Json> doc = fireStatements.doc(_revokeAt);
        final DocumentSnapshot<Json> docSnap = await mFire.mAsync(doc.get);
        // _revokeAt can be any string. If it is the id (token) of something this Fetcher has ever
        // stated, the we revoke it there; otherwise, it's blocked - revoked "since forever".
        // TODO(2): add unit test.
        if (b(docSnap.data())) {
          final Json data = docSnap.data()!;
          _revokeAtTime = parseIso(data['time']);
        } else {
          _revokeAtTime = DateTime(0);
        }
      }

      Query<Json> query = fireStatements.orderBy('time', descending: true); // newest to oldest
      QuerySnapshot<Json> snapshots = await mFire.mAsync(query.get);
      // DEFER: Something with the error.
      // .catchError((e) => print("Error completing: $e"));
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
        DateTime time = parseIso(jsonish.json['time']);
        if (previousTime == null) {
          // no check
        } else {
          if (jsonish.token != previousToken) {
            // DEFER: Something.
            print('Notarization violation: ($domain/$token): ${jsonish.token} != $previousToken');
            continue;
          }
          if (!time.isBefore(previousTime)) {
            // DEFER: Something.
            String error = '!Descending: ($domain/$token): $time >= $previousTime';
            print(error);
            // DEFER: continue; Not continuing because my (Tom) data is currently corrupt ;(
          }
        }
        previousToken = data['previous'];
        previousTime = time;

        _cached!.add(Statement.make(jsonish));
      }
      if (_cached!.isNotEmpty) _lastToken = _cached!.first.token;
    }

    // print('fetched: $fire, $token');
  }

  List<Statement> get statements {
    if (b(_revokeAt)) {
      // TODO: NEXT: Might need to disable the ability to set revokedAt due to clouddistinct
      Statement? revokeAtStatement = _cached!.firstWhereOrNull((s) => s.token == _revokeAt);
      if (b(revokeAtStatement)) {
        return _cached!.sublist(_cached!.indexOf(revokeAtStatement!));
      } else {
        return [];
      }
    } else {
      return _cached!;
    }
  }

  // TODO: Why return value Jsonish and not Statement?
  // Side effects: add 'previous', 'signature'
  Future<Jsonish> push(Json json, StatementSigner? signer) async {
    // (I've had this commented out in the past for persistDemo)
    assert(_revokeAt == null);
    changeNotify();

    if (_cached == null) await fetch(); // Was green.

    // add 'previous', verify time is later than last statement
    Statement? previous;
    if (_cached!.isNotEmpty) {
      previous = _cached!.first;

      // assert time is after last statement time
      // This is a little confusing with clouddistinct, but I think this is okay.
      DateTime prevTime = parseIso(previous.json['time']!);
      DateTime thisTime = parseIso(json['time']!);
      assert(thisTime.isAfter(prevTime));

      if (json.containsKey('previous')) {
        // for load dump
        assert(json['previous'] == _lastToken);
      }
    }
    if (_lastToken != null) json['previous'] = _lastToken;

    // sign (or verify) statement
    String? signature = json['signature'];
    Jsonish jsonish;
    if (signer != null) {
      assert(signature == null);
      jsonish = await Jsonish.makeSign(json, signer);
    } else {
      assert(signature != null);
      jsonish = await Jsonish.makeVerify(json, _verifier);
    }

    _cached!.insert(0, Statement.make(jsonish));
    _lastToken = jsonish.token;

    final fireStatements = fire.collection(token).doc('statements').collection('statements');
    // NOTE: We don't 'await'.. Ajax!.. Bad idea now that others call this, like tests.
    // DEFER: In case this seems slow, try Ajax after all.
    await fireStatements
        .doc(jsonish.token)
        .set(jsonish.json)
        .then((doc) {}, onError: (e) => print("Error: $e"));
    // CONSIDER: Handle in case async DB write succeeds or fails.

    // Now fetch to check our optimistic concurrency.
    Query<Json> query = fireStatements.orderBy('time', descending: true);
    QuerySnapshot<Json> snapshots = await query.get();
    final docSnapshot0 = snapshots.docs.elementAt(0);
    if (docSnapshot0.id != jsonish.token) {
      print('${docSnapshot0.id} != ${jsonish.token}');
      // TODO: Make this exception reach the user, not just in the stack trace in Developer Tools
      throw Exception('${docSnapshot0.id} != ${jsonish.token}');
    }
    if (previous != null) {
      final docSnapshot1 = snapshots.docs.elementAt(1);
      if (docSnapshot1.id != previous.token) {
        print('${docSnapshot1.id} != ${previous.token}');
        // TODO: Make this exception reach the user, not just in the stack trace in Developer Tools
        throw Exception('${docSnapshot1.id} != ${previous.token}');
      }
    }

    return jsonish;
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
