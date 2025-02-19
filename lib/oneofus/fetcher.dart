import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // You have to add this manually, for some reason it cannot be added automatically
import 'package:flutter/material.dart';
import 'package:nerdster/progress.dart';
import '../prefs.dart'; // CODE: Kludgey way to include, but might work for phone codebase.

import 'distincter.dart';
import 'fire_factory.dart';
import 'jsonish.dart';
import 'oou_verifier.dart';
import 'statement.dart';
import 'util.dart';

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

  List<Statement>? _cached;

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

  // Oneofus trust does not allow 2 different keys replace a key. That's a conflict.
  // It does allow anyone to block a key, and so multiple keys could block the same key.
  // Fetcher isn't responsible for implementing that, but I am going to assume that
  // something else does and I'll rely on that and not implement code to update
  // revokeAt. So:
  // - okay to block a revoked (replaced) key.
  // - okay to block a blocked key.
  // - okay to revoke (replace) a blocked key.
  // - not okay to revoke (replace) a revoked (replaced) key.
  void setRevokeAt(String revokeAt) {
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
    bool first = true;
    String? previousToken;
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
      if (first) {
        first = false; // no check
      } else {
        if (jsonish.token != previousToken) {
          // DEFER: Something.
          print(
              'Blockchain notarization violation: ($domain/$token): ${jsonish.token} != $previousToken');
          continue;
        }
      }
      previousToken = data['previous'];

      _cached!.add(Statement.make(jsonish));
    }
    // print('fetched: $fire, $token');
  }

  List<Statement> get statements {
    if (b(_revokeAt)) {
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
      DateTime prevTime = parseIso(previous.json['time']!);
      DateTime thisTime = parseIso(json['time']!);
      assert(thisTime.isAfter(prevTime));

      if (json.containsKey('previous')) {
        // for load dump
        assert(json['previous'] == previous.token);
      }
      json['previous'] = previous.token;
    }

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
