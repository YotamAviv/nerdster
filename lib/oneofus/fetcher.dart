import 'dart:collection';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../prefs.dart'; // CODE: Kludgey way to include, but works with phone codebase.
import 'distincter.dart';
import 'fire_factory.dart';
import 'jsonish.dart';
import 'measure.dart';
import 'oou_verifier.dart';
import 'statement.dart';
import 'util.dart';
import 'value_waiter.dart';

/// PERFORMANCE: CONSIDER: Cloud copy everything to static and fetch from there.

/// Now that Nerdster loads Oneofus data over HTTPS, not Firebase Cloud Functions,
/// OneofusFire is only there for development (direct Firebase queries) and is rarely used.
///
/// Brief history:
/// - Fetcher used direct Firebase queries
///   - testing and development used FakeFirebase
/// - I found Cloud Functions and used them to fetch distinct
///   - That had to be optional to all for testing/FakeFirebase to continue
/// - Cloud Functions don't support chuncked reading in Dart on the client side (I  don't think),
///   and so I moved to HTTPS functions.
/// - HTTPS functions with paralel reads on the server side and chuncked reading on the client
///   seem ideal, almost
///   - fastest
///   - Nerdster should no longer need a back door to Oneofus
///   - Can't be tested on Linux without emulator (dough!)
///
/// I'd like to settle on HTTPS functions only, but I need to keep
/// - FakeFirebase working for unit testing.
/// - Oneofus backdoor on emulator for "integration testing" (see menu DEV->Integration tests)

/// Keep in mind:
/// - distinct:
/// Cloud functions do it to reduce traffic, which makes sense.
/// That doesn't eliminate the need for Distincter (equilvalent keys, multiple delegates).
/// Make sure that https use / and direct Firebase queries provide same semantics.
/// - verify, checkPrevious
/// It's optional and can't be done if we don't ask the cloud for the required data
/// ['statement', 'I', 'signature', 'previous']

/// CONSIDER: resetRevokeAt: Do a different way.
///   - OneofusNet should unlock that ability and then lock it again.
/// TRUE: Fetched JSON remains the same. Fetchers can cache it even if it's passed revoked and
/// they can use too much cache when revoked.

/// CONSIDER: refresh fetchers (fetch newer statements only), maybe.
/// CONS:
/// - complexity
/// - probably not much faster. I think I measured something like this and that it didn't seem to be worth the hassle.
/// PROS:

/// Integration Testing:
/// With non-trivial code in JavaScript cloud functions, integration testing is required.
/// As Firebase does not support Linux, this necessarily requires running in Chrome or Android (emulator).
/// I'm partway there with some tests implemented in demotest/cases. I don't want to re-implement
/// a test framework, and so I expect to end up somewhere in the middle (and yes, I have and will
/// always have bugs;)

/// This class combines much functionality, which is messy, but it was even messier with multiple classes:
/// - Firestore fetch/push, cache
/// - revokeAt (part of trust algorithm)
/// - notary chain maintenance and verification (previous token)
/// - signature maintenance and verification

final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);

abstract class Corruptor {
  void corrupt(String token, String error, String? details);
}

class Fetcher {
  static final OouVerifier _verifier = OouVerifier();
  static final Measure mVerify = Measure('mVerify');
  static final Map<String, Fetcher> _fetchers = <String, Fetcher>{};
  static const Json _paramsProto = {
    "distinct": true,
    "omit": ["statement", "I"],
    "orderStatements": false,

    "checkPrevious": true,
    "includeId": true, // includeId required for checkPrevious, not needed but tested and liked.
  };

  final FirebaseFirestore _fire;
  final String domain;
  final String token;
  String? _revokeAt; // set by others to let this object know
  DateTime? _revokeAtTime; // set by this object after querying the db
  List<Statement>? _cached;
  String? _lastToken;

  static void clear() {
    _fetchers.clear();
  }

  // If we ever fetched a statement for {domain, token}, then that statement remains correct forever.
  // But if we change center (PoV) or learn about a new trust or block, then that might change revokeAt.
  static void resetRevokeAt() {
    for (Fetcher f in _fetchers.values) {
      if (f._revokeAt != null) {
        f._cached = null;
        f._revokeAt = null;
        f._revokeAtTime = null;
      }
    }
  }

  factory Fetcher(String token, String domain) {
    String key = _key(token, domain);
    FirebaseFirestore fire = FireFactory.find(domain);
    Fetcher out;
    if (_fetchers.containsKey(key)) {
      out = _fetchers[key]!;
      assert(out._fire == fire);
    } else {
      out = Fetcher.internal(token, domain, fire);
      _fetchers[key] = out;
    }
    return out;
  }

  static String _key(String token, String domain) => '$token:$domain';

  Fetcher.internal(this.token, this.domain, this._fire);

  List<Statement> get statements => _cached!;

  String? get revokeAt => _revokeAt;

  DateTime? get revokeAtTime => _revokeAtTime;

  bool get isCached => b(_cached);

  // Oneofus trust does not allow 2 different keys replace a key (that's a conflict).
  // Fetcher isn't responsible for implementing that, but I am going to assume that
  // something else does and I'll rely on that, assert that, and not implement code to update
  // revokeAt.
  //
  // Changing PoV is encouraged, and we'd like to make that fast (without re-fetching too much).
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

  // SUSPECT: BUG: I think I batchFetch over and over when nothing's changed. Note that to re-compute BFS,
  // cached Fetchers work, but there is no "cached batch fetcher". The different BFS layers
  // will pre-fetch different tokens, and so considering only the last one won't help.
  //
  // Skip cached fetchers?
  // - or make that the caller's responsibility?
  // Futhermore, I think that I batch fetch everyone when I'm just missing Amotz.
  static Future<List<Fetcher>> batchFetch(Map<String, String?> token2revokeAt, String domain,
      {String? mName}) async {
    if (fireChoice == FireChoice.fake || !Prefs.batchFetch.value) {
      // serial fetch
      for (MapEntry e in token2revokeAt.entries) {
        Fetcher f = Fetcher(e.key, domain);
        if (b(e.value)) f.setRevokeAt(e.value);
        await f.fetch();
      }
    } else {
      // skip cached fetchers
      LinkedHashMap<String, String?> tmp = LinkedHashMap.of(token2revokeAt)
        ..removeWhere((k, v) => Fetcher(k, domain).isCached && Fetcher(k, domain).revokeAt == v);
      if (tmp.isNotEmpty) {
        Map<String, List<Json>> batchFetched = {};
        var client = http.Client();
        // specs are "token" or {"token": "revokeAt"};
        List specs = List.from(tmp.entries.map((e) => e.value == null ? e.key : {e.key: e.value}));
        try {
          final Uri uri = _makeUri(domain, specs);
          final http.Request request = http.Request('GET', uri);
          final http.StreamedResponse response = await client.send(request);
          assert(response.statusCode == 200, 'Request failed with status: ${response.statusCode}');
          ValueNotifier<bool> done = ValueNotifier(false);
          response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
            Json jsonToken2Statements = jsonDecode(line);
            assert(jsonToken2Statements.length == 1);
            String token = jsonToken2Statements.keys.first;
            List statements = jsonToken2Statements.values.first;
            batchFetched[_key(token, domain)] = List<Json>.from(statements);
            // print('batchFetched ${_key(token, revokeAt, domain)} #:${statements.length} uri=$uri');
          }, onError: (error) {
            // DEFER: Corrupt the collection. Left as is, fetch() should "miss" and do it.
            print('Error in stream: $specs $domain');
          }, onDone: () {
            client.close();
            done.value = true;
          });
          await ValueWaiter(done, true).untilReady();

          // process the rest (_cache, _revokeAt, _revokeAtTime..)
          for (MapEntry<String, String?> e in tmp.entries) {
            String? revokedAt = tmp[e.key];
            Fetcher fetcher = Fetcher(e.key, domain);
            fetcher._cached = null;
            if (b(revokedAt)) fetcher.setRevokeAt(revokedAt!);
            List<Json> jsons = batchFetched[_key(e.key, domain)]!;
            await fetcher._fetch(jsons: jsons);
          }
        } catch (e, stackTrace) {
          print('Error: $e');
          print(stackTrace);
        }
      }
    }
    // return fetchers
    List<Fetcher> out = [];
    for (MapEntry<String, String?> e in token2revokeAt.entries) {
      String? revokedAt = token2revokeAt[e.key];
      Fetcher f = Fetcher(e.key, domain);
      assert(f.isCached);
      assert(revokedAt == f.revokeAt, '$revokedAt == ${f.revokeAt}');
      out.add(f);
    }
    assert(out.length == token2revokeAt.length);
    return out;
  }

  Future<void> fetch() => _fetch();

  Future<void> _fetch({List<Json>? jsons}) async {
    if (b(_cached)) return;
    try {
      DateTime? time;
      if (fireChoice != FireChoice.fake && Prefs.httpFetch.value) {
        _cached = <Statement>[];
        if (jsons == null) {
          if (Prefs.batchFetch.value) print('batcher miss $domain $token');
          jsons = await _httpFetchJsons();
        }

        if (_revokeAt != null) {
          if (jsons.isNotEmpty) {
            assert(jsons.first['id'] == _revokeAt, '${jsons.first['id']} == $_revokeAt');
            // without includeId, this might work: assert(getToken(statements.first) == _revokeAt);
            _revokeAtTime = parseIso(jsons.first['time']);
          } else {
            _revokeAtTime = date0; // "since always" (or any unknown token);
          }
        }

        for (Json j in jsons) {
          DateTime jTime = parseIso(j['time']);
          if (time != null) assert(jTime.isBefore(time));
          time = jTime;
          j['statement'] = domain2statementType[domain]!;
          j['I'] = Jsonish.find(token)!.json;
          j.remove('id'); // No problem, unless we end up here twice (which we shouldn't).

          Jsonish jsonish;
          if (Prefs.skipVerify.value) {
            jsonish = Jsonish(j);
          } else {
            jsonish = await mVerify.mAsync(() => Jsonish.makeVerify(j, _verifier));
          }
          Statement statement = Statement.make(jsonish);
          _cached!.add(statement);
        }
      } else {
        final CollectionReference<Map<String, dynamic>> collectionRef =
            _fire.collection(token).doc('statements').collection('statements');
        // query _revokeAtTime
        if (_revokeAt != null && _revokeAtTime == null) {
          DocumentReference<Json> doc = collectionRef.doc(_revokeAt);
          final DocumentSnapshot<Json> docSnap = await doc.get();
          if (b(docSnap.data())) {
            final Json data = docSnap.data()!;
            _revokeAtTime = parseIso(data['time']);
          } else {
            _revokeAtTime = date0; // "since always" (or any unknown token)
          }
        }

        List<Statement> statements2 = <Statement>[];
        Query<Json> query = collectionRef.orderBy('time', descending: true);
        if (_revokeAtTime != null) {
          query = query.where('time', isLessThanOrEqualTo: formatIso(_revokeAtTime!));
        }
        QuerySnapshot<Json> snapshots = await query.get();
        bool first = true;
        String? previousToken;
        DateTime? previousTime;
        for (final docSnapshot in snapshots.docs) {
          final Json json = docSnapshot.data();
          Jsonish jsonish;
          if (Prefs.skipVerify.value) {
            jsonish = Jsonish(json);
          } else {
            jsonish = await mVerify.mAsync(() => Jsonish.makeVerify(json, _verifier));
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
          previousToken = json['previous'];
          previousTime = time;

          statements2.add(Statement.make(jsonish));
        }
        // Maintain Cloud Functions or not behave similarly.
        assert(_paramsProto.containsKey('distinct'));
        _cached = distinct(statements2);
      }
      _lastToken = _cached!.isNotEmpty ? _cached!.first.token : null;
    } catch (e, stackTrace) {
      // print(stackTrace);
      corruptor.corrupt(token, e.toString(), stackTrace.toString());
    }
  }

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
      assert(thisTime.isAfter(prevTime), '$thisTime !.isAfter($prevTime)');

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

    final fireStatements = _fire.collection(token).doc('statements').collection('statements');
    // Transaction!
    // TODO: TEST: Testing might be easier after the change away from the factory CTOR.
    await _fire.runTransaction((_) async {
      Query<Json> query = fireStatements.orderBy('time', descending: true);
      QuerySnapshot<Json> snapshots = await query.get();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snapshots.docs;
      if (docs.isEmpty) {
        if (jsonish.containsKey('previous')) {
          String error = 'Your data was stale. Reload. previous=(${jsonish['previous']})';
          throw Exception(error);
        }
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

  Future<List<Json>> _httpFetchJsons() async {
    var client = http.Client();
    final Uri uri = _makeUri(domain, {token: _revokeAt});
    final http.Response response = await client.get(uri);
    assert(response.statusCode == 200, 'Request failed with status: ${response.statusCode}');
    final Json jsonToken2Statements = jsonDecode(response.body);
    assert(jsonToken2Statements.length == 1);
    assert(token == jsonToken2Statements.keys.first);
    final List statements = jsonToken2Statements.values.first;
    return List<Json>.from(statements);
  }

  static Uri _makeUri(String domain, var spec) {
    final String host = exportUrl[fireChoice]![domain]!.$1;
    final String path = exportUrl[fireChoice]![domain]!.$2;
    Json params = Map.of(_paramsProto);
    params['spec'] = spec;
    params = params.map((k, v) => MapEntry(k, Uri.encodeComponent(JsonEncoder().convert(v))));
    // DEFER: Wierd: only http works on emulator, only https works on PROD
    final Uri uri = (fireChoice == FireChoice.prod)
        ? Uri.https(host, path, params)
        : Uri.http(host, path, params);
    return uri;
  }

  @override
  String toString() => 'Fetcher: $domain $token';
}

// EXPERIMENTAL: "EXPERIMENTAL" tagged where the code allows us to not compute the tokens
// but just use the stored values, which allows us to not ask for [signature, previous].
// The changes worked, but the performance hardly changed. And with this, we wouldn't have
// [signature, previous] locally, couldn't verify statements, and there'd be more code
// paths. So, no.
//
// String serverToken = j['id'];
// Jsonish jsonish = Jsonish(j, serverToken);
// j.remove('id');
// assert(jsonish.token == serverToken);
//
// static const Json paramsProto = {
//   "includeId": true,
//   "distinct": true,
//   "checkPrevious": true,
//   "omit": ['statement', 'I', 'signature', 'previous']
//   "orderStatements": false,
// };
