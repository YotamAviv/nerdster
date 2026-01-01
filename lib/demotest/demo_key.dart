import 'dart:collection';

import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/block_replaced_key.dart';
import 'package:nerdster/demotest/cases/decapitate.dart';
import 'package:nerdster/demotest/cases/delegate_merge.dart';
import 'package:nerdster/demotest/cases/deletions.dart';
import 'package:nerdster/demotest/cases/egos.dart';
import 'package:nerdster/demotest/cases/equivalent_keys_state_conflict.dart';
import 'package:nerdster/demotest/cases/loner.dart';
import 'package:nerdster/demotest/cases/large_graph.dart';
import 'package:nerdster/demotest/cases/multiple_blocks.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/cases/simpsons_relate_demo.dart';
import 'package:nerdster/demotest/cases/stress.dart';
import 'package:nerdster/demotest/cases/trust_block_conflict.dart';
import 'package:nerdster/demotest/cases/v2_verification.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/crypto/crypto2559.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// For testing, development, and maybe demo.
///
/// Goal
/// - Simpsons with lots going on:
///   - replaced keys
///   - bad actor (Sideshow)
///   - labels: wife, boy, boss, staff, ...
/// - sign in as or re-center around any one of them
///
/// Persistence / Flutter web / phone / emulator challenges:
/// - emulator eventually forgets
/// - in memory forgets with every hot reload
/// - tests can't output files
///
/// CONSIDER: Use a fake clock to load the demo, but then reset back to a regular one.
const OouCryptoFactory _crypto = CryptoFactoryEd25519();

/// Represents a key pair for testing/demo purposes.
///
/// A [DemoKey] instance should be used EITHER as an Identity Key (issuing [TrustStatement]s)
/// OR as a Delegate Key (issuing [ContentStatement]s), but never both.
/// This is enforced by [_checkUsage].
class DemoKey {
  static final LinkedHashMap<String, DemoKey> _name2key = LinkedHashMap<String, DemoKey>();
  static final Map<String, DemoKey> _token2key = <String, DemoKey>{};
  static final Map<String, Json> _exports = {};

  static final dynamic demos = {
    'largeGraph': largeGraph,
    'simpsonsDemo': simpsonsDemo,
    'simpsonsRelateDemo': simpsonsRelateDemo,
    'basicScenario': testBasicScenario,
    'egosCorrupt': egosCorrupt,
    'lonerCorrupt': lonerCorrupt,
    'lonerBadDelegate': lonerBadDelegate,
    'lonerClearDelegate': lonerClearDelegate,
    'lonerRevokeDelegate': lonerRevokeDelegate,
    'simpsons': simpsons,
    'loner': loner,
    'trustBlockConflict': trustBlockConflict,
    'egos': egos,
    'egosCircle': egosCircle,
    'delegateMerge': delegateMerge,
    'delete3': deletions3,
    'blockReplacedKey': blockReplacedKey,
    'multipleBlocks': multipleBlocks,
    'equivalentKeysStateConflict': equivalentKeysStateConflict,
    'lonerEquate': lonerEquate,
    'decap': decap,
    'decap2': decap2,
    'blockDecap': blockDecap,
    'stress': stress,
  };

  static void reset() {
    _name2key.clear();
    _token2key.clear();
    _exports.clear();
  }

  final String name;
  final OouKeyPair keyPair;
  final OouPublicKey publicKey;
  final String token;

  static Iterable<DemoKey> get all => _name2key.values;

  static DemoKey? findByName(String name) => _name2key[name];

  static DemoKey? findByToken(String token) => _token2key[token];

  static Future<DemoKey> create(String name) async {
    return findOrCreate(name);
  }

  static Future<DemoKey> findOrCreate(String name) async {
    if (!_name2key.containsKey(name)) {
      final OouKeyPair keyPair = await _crypto.createKeyPair();
      final OouPublicKey publicKey = await keyPair.publicKey;
      final Json json = await publicKey.json;
      final String token = Jsonish(json).token;
      DemoKey out = DemoKey._internal(name, keyPair, publicKey, token);
      _name2key[name] = out;
      _token2key[token] = out;
      _exports[name] = json;
    }
    return _name2key[name]!;
  }

  DemoKey._internal(this.name, this.keyPair, this.publicKey, this.token);

  // --- Outbox / Local Cache ---

  bool get isIdentity => _localStatements.isNotEmpty && _localStatements.first is TrustStatement;
  bool get isDelegate => _localStatements.isNotEmpty && _localStatements.first is ContentStatement;

  /// Returns all trust statements issued by this key, newest first.
  ///
  /// Note: Only Identity Keys should have trust statements.
  List<TrustStatement> get trustStatements {
    if (_localStatements.isNotEmpty) {
      assert(_localStatements.first is TrustStatement,
          'Key "$name" is a Delegate Key (has content statements), but trustStatements was requested.');
    }
    return _localStatements.cast<TrustStatement>().toList();
  }

  /// Returns all content statements issued by this key, newest first.
  ///
  /// Note: Only Delegate Keys should have content statements.
  List<ContentStatement> get contentStatements {
    if (_localStatements.isNotEmpty) {
      assert(_localStatements.first is ContentStatement,
          'Key "$name" is an Identity Key (has trust statements), but contentStatements was requested.');
    }
    return _localStatements.cast<ContentStatement>().toList();
  }

  final List<Statement> _localStatements = [];

  void _checkUsage(Statement newStatement) {
    if (_localStatements.isEmpty) return;

    final bool hasTrust = _localStatements.any((s) => s is TrustStatement);
    final bool hasContent = _localStatements.any((s) => s is ContentStatement);

    if (newStatement is TrustStatement && hasContent) {
      throw 'DemoKey Usage Error: Key "$name" ($token) is being used for both Trust and Content statements. '
          'It should be either an Identity Key (Trust) or a Delegate Key (Content), not both.';
    }
    if (newStatement is ContentStatement && hasTrust) {
      throw 'DemoKey Usage Error: Key "$name" ($token) is being used for both Trust and Content statements. '
          'It should be either an Identity Key (Trust) or a Delegate Key (Content), not both.';
    }
  }

  // --- Content Statement Helpers (Make, then Do) ---

  Future<Json> makeRate(
      {required dynamic subject,
      ContentVerb verb = ContentVerb.rate,
      String? comment,
      bool? recommend,
      bool? dismiss,
      bool? censor,
      dynamic other}) async {
    return ContentStatement.make(await publicKey.json, verb, subject,
        comment: comment, recommend: recommend, dismiss: dismiss, censor: censor, other: other);
  }

  Future<Json> makeFollow(dynamic subject, Json contexts,
      {ContentVerb verb = ContentVerb.follow}) async {
    return ContentStatement.make(
        await publicKey.json, verb, subject is DemoKey ? await subject.publicKey.json : subject,
        contexts: contexts);
  }

  Future<Json> makeRelate(ContentVerb verb, dynamic subject, dynamic other) async {
    return ContentStatement.make(
      await publicKey.json,
      verb,
      subject is DemoKey ? await subject.publicKey.json : subject,
      other: other is DemoKey ? await other.publicKey.json : other,
    );
  }

  Future<ContentStatement> doRate(
      {dynamic subject,
      ContentVerb verb = ContentVerb.rate,
      String? title,
      String? comment,
      bool? recommend,
      bool? dismiss,
      bool? censor,
      String? export}) async {
    assert(i(title) + i(subject) == 1);
    if (b(title)) {
      subject = {'contentType': 'article', 'title': title, 'url': 'u1'};
    }

    final Json json = await makeRate(
      subject: subject is DemoKey ? await subject.publicKey.json : subject!,
      verb: verb,
      comment: comment,
      recommend: recommend,
      dismiss: dismiss,
      censor: censor,
    );

    final ContentStatement statement = await _pushContent(json);
    if (export != null) _exports[export] = statement.json;
    return statement;
  }

  Future<ContentStatement> doFollow(dynamic subject, Json contexts,
      {ContentVerb verb = ContentVerb.follow, String? export}) async {
    final Json json = await makeFollow(subject, contexts, verb: verb);
    final ContentStatement statement = await _pushContent(json);
    if (export != null) _exports[export] = statement.json;
    return statement;
  }

  Future<ContentStatement> doRelate(
    ContentVerb verb, {
    dynamic subject,
    String? title,
    dynamic other,
    String? otherTitle,
    String? export,
  }) async {
    assert(i(subject) + i(title) == 1);
    assert(i(other) + i(otherTitle) == 1);
    if (b(title)) {
      subject = {'contentType': 'article', 'title': title, 'url': 'u1'};
    }
    if (b(otherTitle)) {
      other = {'contentType': 'article', 'title': otherTitle, 'url': 'u1'};
    }

    final Json json = await makeRelate(verb, subject!, other!);
    final ContentStatement statement = await _pushContent(json);
    if (export != null) _exports[export] = statement.json;
    return statement;
  }

  Future<ContentStatement> _pushContent(Json json) async {
    final Fetcher fetcher = Fetcher(token, kNerdsterDomain);
    final OouSigner signer = await OouSigner.make(keyPair);
    final Statement statement = await fetcher.push(json, signer);
    final ContentStatement content = statement as ContentStatement;
    _checkUsage(content);
    _localStatements.insert(0, content);
    return content;
  }

  // --- Trust Statement Helpers (Make, then Do) ---

  Future<Json> makeTrust(TrustVerb verb, DemoKey other,
      {String? moniker, String? comment, String? domain, String? revokeAt}) async {
    return TrustStatement.make(
      await publicKey.json,
      await other.publicKey.json,
      verb,
      domain: domain,
      moniker: moniker,
      comment: comment,
      revokeAt: revokeAt,
    );
  }

  Future<TrustStatement> trust(DemoKey other,
      {required String moniker, String? comment, String? export}) async {
    return await doTrust(TrustVerb.trust, other,
        moniker: moniker, comment: comment, export: export);
  }

  Future<TrustStatement> block(DemoKey other, {String? comment, String? export}) async {
    return await doTrust(TrustVerb.block, other, comment: comment, export: export);
  }

  Future<TrustStatement> replace(DemoKey other,
      {Statement? lastGoodToken, String? comment, String? export}) async {
    return await doTrust(TrustVerb.replace, other,
        comment: comment, revokeAt: lastGoodToken?.token, export: export);
  }

  Future<TrustStatement> delegate(DemoKey other,
      {required String domain, String? comment, String? export}) async {
    return await doTrust(TrustVerb.delegate, other,
        comment: comment, domain: domain, export: export);
  }

  Future<TrustStatement> clear(DemoKey other) async {
    return await doTrust(TrustVerb.clear, other);
  }

  Future<TrustStatement> doTrust(
    TrustVerb verb,
    DemoKey other, {
    String? moniker,
    String? comment,
    String? domain,
    String? revokeAt,
    String? export,
  }) async {
    switch (verb) {
      case TrustVerb.trust:
        moniker ??= other.name;
      case TrustVerb.block:
        assert(!b(moniker));
        comment ??= 'blocking demo ${other.name}';
      case TrustVerb.replace:
        assert(!b(moniker));
        comment ??= 'replacing demo ${other.name}';
      case TrustVerb.delegate:
        assert(!b(moniker));
      case TrustVerb.clear:
    }

    final Json json = await makeTrust(verb, other,
        moniker: moniker, comment: comment, domain: domain, revokeAt: revokeAt);
    final Fetcher fetcher = Fetcher(token, kOneofusDomain);
    final OouSigner signer = await OouSigner.make(keyPair);
    final Statement statement = await fetcher.push(json, signer);
    final TrustStatement trust = statement as TrustStatement;
    _checkUsage(trust);
    _localStatements.insert(0, trust);
    if (export != null) _exports[export] = trust.json;
    return trust;
  }

  Future<DemoKey> makeDelegate({String? export}) async {
    assert(_name2key.containsKey(name));
    int i = 0;
    String delegateKeyName;
    while (true) {
      delegateKeyName = '$name-nerdster$i';
      if (!_name2key.containsKey(delegateKeyName)) {
        break;
      }
      i++;
    }

    DemoKey delegateKey = await DemoKey.findOrCreate(delegateKeyName);
    // It would be nice to have this returned (to revoke at it or to verify its rejection)
    Statement statement = await doTrust(TrustVerb.delegate, delegateKey, domain: kNerdsterDomain);
    if (export != null) _exports[export] = statement.json;
    return delegateKey;
  }

  Future<Json> toJson() async {
    return {'token': token, 'keyPair': await keyPair.json};
  }

  static void dumpDemoCredentials() async {
    Json x = {};
    for (MapEntry e in _name2key.entries) {
      x[e.key] = await e.value.toJson();
    }
    var z = encoder.convert(x);
    print(z);
  }

  static Json getExports() => _exports;

  static String getExportsString() {
    return '''// NOTE TO AI AGENT:
// Do not add dummy data to this file.
// This file is generated by running the app connected to the production database.
// Adding dummy data here will cause the app to fail when it tries to verify the data against the database.
const demoData = ${encoder.convert(_exports)};''';
  }
}
