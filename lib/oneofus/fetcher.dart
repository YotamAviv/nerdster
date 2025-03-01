import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../prefs.dart'; // CODE: Kludgey way to include, but might work for phone codebase.
import 'distincter.dart';
import 'fire_factory.dart';
import 'jsonish.dart';
import 'measure.dart';
import 'oou_verifier.dart';
import 'statement.dart';
import 'util.dart';

/// Cloud Functions distinct, order, tokens, checkPervious...
///
/// Integration Testing:
/// With non-trivial code in JavaScript cloud functions, integration testing is required.
/// As Firebase does not support Linux, this necessarily requires running in Chrome or Android (emulator).
/// I'm partway there with some tests implemented in demotest/cases. I don't want to re-implement
/// a test framework, and so I expect to end up somewhere in the middle (and yes, I have and will
/// always have bugs;)
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

class Fetcher {
  static int? testingCrashIn;

  static final OouVerifier _verifier = OouVerifier();

  // (I've lost track of the reasoning behind having a final VoidCallback for this.)
  static final VoidCallback changeNotify = clearDistincterCache;

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
  // TODO: Make cloud and non-cloud path use _cached similary ({distinct, revoked}).
  List<Statement>? _cached;
  String? _lastToken;

  static void clear() => _fetchers.clear();

  // I've lost track a little, but...
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
    changeNotify();
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
    if (_revokeAt == revokeAt) return;

    _revokeAt = revokeAt;
    _revokeAtTime = null;
    _cached = null;
    changeNotify();
  }

  String? get revokeAt => _revokeAt;

  DateTime? get revokeAtTime => _revokeAtTime;

  bool get isCached => b(_cached);

  static const Map fetchParamsProto = {
    // "checkPrevious": true,
    "distinct": true,
    "omit": ['statement', 'I'],
    "orderStatements": "false",
    "includeId": true,
    // EXPERIMENTAL: "includeId": true,
    // EXPERIMENTAL: "omit": ['statement', 'I', 'signature', 'previous']
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
          assert(statements.first['id'] == _revokeAt, '${statements.first['id']} == $_revokeAt');
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
      // Be like clouddistinct
      if (fetchParamsProto.containsKey('distinct')) {
        _cached = distinct(_cached!);
      }
    }

    if (_cached!.isNotEmpty) _lastToken = _cached!.first.token;
  }

  List<Statement> get statements => _cached!;

  // Side effects: add 'previous', 'signature'
  Future<Statement> push(Json json, StatementSigner? signer) async {
    assert(_revokeAt == null);
    changeNotify();

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

    _cached!.insert(0, Statement.make(jsonish));
    _lastToken = jsonish.token;

    final fireStatements = fire.collection(token).doc('statements').collection('statements');
    // DEFER: Don't 'await'.. Ajax!.. Bad idea now that others call this, like tests.
    await fireStatements.doc(jsonish.token).set(jsonish.json).then((doc) {}, onError: (e) {
      throw e;
    });

    // Now fetch to verify our optimistic concurrency.
    Query<Json> query = fireStatements.orderBy('time', descending: true);
    QuerySnapshot<Json> snapshots = await query.get();
    final docSnapshot0 = snapshots.docs.elementAt(0);
    if (docSnapshot0.id != jsonish.token) {
      String error =
          'Optimistic concurrency failed, corruption possible: ${docSnapshot0.id} != ${jsonish.token}';
      print(error);
      throw Exception(error);
    }
    if (previous != null) {
      final docSnapshot1 = snapshots.docs.elementAt(1);
      if (docSnapshot1.id != previous.token) {
        String error =
            'Optimistic concurrency failed, corruption possible: ${docSnapshot1.id} != ${previous.token}';
        print(error);
        throw Exception(error);
      }
    }

    Statement statement = Statement.make(jsonish);
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
