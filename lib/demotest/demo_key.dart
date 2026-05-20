import 'dart:collection';

import 'package:nerdster/demotest/cases/egos.dart';
import 'package:nerdster/demotest/cases/equivalence_bug.dart';
import 'package:nerdster/demotest/cases/loner.dart';
import 'package:nerdster/demotest/cases/notifications_gallery.dart';
import 'package:nerdster/demotest/cases/rate_when_not_in_network.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/cases/simpsons_relate_demo.dart';
import 'package:nerdster/demotest/cases/stress.dart';
import 'package:nerdster/demotest/cases/verification.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';

/// For testing, development, and maybe demo.
const OouCryptoFactory _crypto = crypto;

/// A Namespace for the demos and shared static state.
abstract class DemoKey {
  String get name;
  String get token;
  OouKeyPair get keyPair;
  OouPublicKey get publicKey;

  static final Map<String, Json> _exports = {};

  static final dynamic demos = {
    'notificationsGallery': notificationsGallery,
    'simpsonsDemo': simpsonsDemo,
    'simpsonsRelateDemo': simpsonsRelateDemo,
    'basicScenario': basicScenario,
    'egosCorrupt': egosCorrupt,
    'lonerCorrupt': lonerCorrupt,
    'lonerBadDelegate': lonerBadDelegate,
    'lonerClearDelegate': lonerClearDelegate,
    'lonerRevokeDelegate': lonerRevokeDelegate,
    'simpsons': simpsons,
    'loner': loner,
    'egos': egos,
    'egosCircle': egosCircle,
    'equivalenceBug': equivalenceBug,
    'rateWhenNotInNetwork': rateWhenNotInNetwork,
    'stress': stress,
  };

  static void reset() {
    DemoIdentityKey.reset();
    DemoDelegateKey.reset();
    _exports.clear();
  }

  bool get isDelegate;

  static void export(String name, Json value) => _exports[name] = value;

  static Json getExports() => _exports;

  static String getExportsJson() {
    return encoder.convert(_exports);
  }

  static Future<String> getPrivateKeysJson() async {
    Json x = {};
    for (MapEntry e in DemoIdentityKey._name2key.entries) {
      x[e.key] = await e.value.toJson();
    }
    for (MapEntry e in DemoDelegateKey._name2key.entries) {
      x[e.key] = await e.value.toJson();
    }
    return encoder.convert(x);
  }

  static void dumpDemoCredentials() async {
    print(await getPrivateKeysJson());
  }
}

class DemoIdentityKey implements DemoKey {
  static final LinkedHashMap<String, DemoIdentityKey> _name2key =
      LinkedHashMap<String, DemoIdentityKey>();
  static final Map<String, DemoIdentityKey> _token2key = <String, DemoIdentityKey>{};

  final String name;
  final OouKeyPair keyPair;
  final OouPublicKey publicKey;
  final String token;
  final Map<String, dynamic> endpoint;

  bool get isDelegate => false;

  IdentityKey get id => IdentityKey(token);

  static Iterable<DemoIdentityKey> get all => _name2key.values;

  static DemoIdentityKey? findByName(String name) => _name2key[name];
  static DemoIdentityKey? findByToken(String token) => _token2key[token];

  static void reset() {
    _name2key.clear();
    _token2key.clear();
  }

  static Future<DemoIdentityKey> create(String name) async {
    return findOrCreate(name);
  }

  static Future<DemoIdentityKey> findOrCreate(String name,
      {Map<String, dynamic>? endpoint}) async {
    if (!_name2key.containsKey(name)) {
      final OouKeyPair keyPair = await _crypto.createKeyPair();
      final OouPublicKey publicKey = await keyPair.publicKey;
      final Json json = await publicKey.json;
      final String token = Jsonish(json).token;
      final resolved = endpoint ?? kNativeEndpoint;
      if (endpoint != null) FedKey(json, endpoint);
      DemoIdentityKey out = DemoIdentityKey._internal(name, keyPair, publicKey, token, resolved);
      _name2key[name] = out;
      _token2key[token] = out;
      DemoKey._exports[name] = json;
    }
    return _name2key[name]!;
  }

  DemoIdentityKey._internal(this.name, this.keyPair, this.publicKey, this.token, this.endpoint);

  final List<TrustStatement> _localStatements = [];
  List<TrustStatement> get trustStatements => List.unmodifiable(_localStatements);

  // --- Identity Operations ---

  /// Creates a generic Identity Key (User) trust statement json
  Future<Json> makeTrust(TrustVerb verb, DemoIdentityKey other,
      {String? moniker, String? comment, String? domain, String? revokeAt}) async {
    final endpoint = FedKey.find(IdentityKey(other.token))?.endpoint;
    return TrustStatement.make(
      await publicKey.json,
      await other.publicKey.json,
      verb,
      domain: domain,
      moniker: moniker,
      comment: comment,
      revokeAt: revokeAt,
      endpoint: endpoint,
    );
  }

  Future<TrustStatement> trust(DemoIdentityKey other,
      {required String moniker, String? comment, String? export}) async {
    return await doTrust(TrustVerb.trust, other,
        moniker: moniker, comment: comment, export: export);
  }

  Future<TrustStatement> block(DemoIdentityKey other, {String? comment, String? export}) async {
    return await doTrust(TrustVerb.block, other, comment: comment, export: export);
  }

  Future<TrustStatement> replace(DemoIdentityKey other,
      {Statement? lastGoodToken, String? comment, String? export}) async {
    return await doTrust(TrustVerb.replace, other,
        comment: comment, revokeAt: lastGoodToken?.token ?? kSinceAlways, export: export);
  }

  Future<TrustStatement> delegate(DemoDelegateKey other,
      {required String domain, String? comment, String? revokeAt, String? export}) async {
    // Note: We are delegating TO a delegate key.
    // The TrustStatement expects a key as subject.
    // We pass the delegate's public key info.

    // We reuse doTrust logic but need to handle DelegateKey type for 'other'.
    // doTrust below takes DemoIdentityKey. We need a version that takes DemoDelegateKey for delegation.

    return await _doDelegateTrust(other,
        domain: domain, comment: comment, revokeAt: revokeAt, export: export);
  }

  Future<TrustStatement> clear(DemoIdentityKey other) async {
    return await doTrust(TrustVerb.clear, other);
  }

  Future<TrustStatement> doTrust(
    TrustVerb verb,
    DemoIdentityKey other, {
    String? moniker,
    String? comment,
    String? domain,
    String? revokeAt,
    String? export,
  }) async {
    // Assertions for identity verbs
    switch (verb) {
      case TrustVerb.trust:
        moniker ??= other.name;
      case TrustVerb.block:
        assert(!(moniker != null));
        comment ??= 'blocking demo ${other.name}';
      case TrustVerb.replace:
        assert(!(moniker != null));
        comment ??= 'replacing demo ${other.name}';
      case TrustVerb.clear:
        break; // fine
      case TrustVerb.delegate:
        throw "Use delegate() method for delegation";
    }

    final Json json = await makeTrust(verb, other,
        moniker: moniker, comment: comment, domain: domain, revokeAt: revokeAt);
    return _signAndPush(json, export);
  }

  Future<TrustStatement> _doDelegateTrust(DemoDelegateKey other,
      {required String domain, String? comment, String? revokeAt, String? export}) async {
    // Construct trust statement for delegate
    // TrustStatement.make expects 'other' json.
    final Json json = TrustStatement.make(
      await publicKey.json,
      await other.publicKey.json,
      TrustVerb.delegate,
      domain: domain,
      comment: comment,
      revokeAt: revokeAt,
    );
    return _signAndPush(json, export);
  }

  Future<TrustStatement> _signAndPush(Json json, String? export) async {
    final StatementChannel<TrustStatement> source = channelFactory.getChannel<TrustStatement>(endpoint['url'] as String, 'statements');
    final OouSigner signer = await OouSigner.make(keyPair);
    await source.fetch({Jsonish(json['I']).token: null});
    final TrustStatement trust = await source.push(json, signer);
    _localStatements.insert(0, trust);
    if (export != null) DemoKey._exports[export] = trust.json;
    return trust;
  }

  Future<DemoDelegateKey> makeDelegate({String? export}) async {
    // Create a new delegate key derived from this identity's name
    int i = 0;
    String delegateKeyName;
    while (true) {
      delegateKeyName = '$name-nerdster$i';
      if (!DemoDelegateKey._name2key.containsKey(delegateKeyName)) {
        break;
      }
      i++;
    }

    DemoDelegateKey delegateKey = await DemoDelegateKey.findOrCreate(delegateKeyName);
    await delegate(delegateKey, domain: kNerdsterDomain, export: export);
    return delegateKey;
  }

  Future<Json> toJson() async {
    return {'token': token, 'keyPair': await keyPair.json};
  }
}

class DemoDelegateKey implements DemoKey {
  static final LinkedHashMap<String, DemoDelegateKey> _name2key =
      LinkedHashMap<String, DemoDelegateKey>();
  static final Map<String, DemoDelegateKey> _token2key = <String, DemoDelegateKey>{};

  final String name;
  final OouKeyPair keyPair;
  final OouPublicKey publicKey;
  final String token;

  bool get isDelegate => true;

  DelegateKey get id => DelegateKey(token);

  static Iterable<DemoDelegateKey> get all => _name2key.values;
  static DemoDelegateKey? findByName(String name) => _name2key[name];
  static DemoDelegateKey? findByToken(String token) => _token2key[token];

  static void reset() {
    _name2key.clear();
    _token2key.clear();
  }

  static Future<DemoDelegateKey> create(String name) async {
    return findOrCreate(name);
  }

  static Future<DemoDelegateKey> findOrCreate(String name) async {
    if (!_name2key.containsKey(name)) {
      final OouKeyPair keyPair = await _crypto.createKeyPair();
      final OouPublicKey publicKey = await keyPair.publicKey;
      final Json json = await publicKey.json;
      final String token = Jsonish(json).token;
      DemoDelegateKey out = DemoDelegateKey._internal(name, keyPair, publicKey, token);
      _name2key[name] = out;
      _token2key[token] = out;
      DemoKey._exports[name] = json;
    }
    return _name2key[name]!;
  }

  DemoDelegateKey._internal(this.name, this.keyPair, this.publicKey, this.token);

  final List<ContentStatement> _localStatements = [];
  List<ContentStatement> get contentStatements => List.unmodifiable(_localStatements);

  final List<DismissStatement> _localDisStatements = [];
  List<DismissStatement> get disStatements => List.unmodifiable(_localDisStatements);

  // --- Content Operations ---

  Future<Json> makeRate(
      {required dynamic subject,
      ContentVerb verb = ContentVerb.rate,
      String? comment,
      bool? recommend,
      bool? censor,
      dynamic other}) async {
    return ContentStatement.make(await publicKey.json, verb, subject,
        comment: comment, recommend: recommend, censor: censor, other: other);
  }

  Future<Json> makeFollow(dynamic subject, Json contexts,
      {ContentVerb verb = ContentVerb.follow}) async {
    return ContentStatement.make(await publicKey.json, verb, _resolveSubject(subject),
        contexts: contexts);
  }

  Future<Json> makeRelate(ContentVerb verb, dynamic subject, dynamic other) async {
    return ContentStatement.make(await publicKey.json, verb, subject, other: other);
  }

  static dynamic _resolveSubject(dynamic s) {
    if (s is DemoIdentityKey) return s.token;
    if (s is DemoDelegateKey) return s.token;
    return s;
  }

  Future<ContentStatement> doRate(
      {dynamic subject,
      ContentVerb verb = ContentVerb.rate,
      String? title,
      String? comment,
      bool? recommend,
      bool? censor,
      String? export}) async {
    assert((title != null ? 1 : 0) + (subject != null ? 1 : 0) == 1);
    if (title != null) {
      subject = createTestSubject(title: title);
    }

    final Json json = await makeRate(
      subject: subject!,
      verb: verb,
      comment: comment,
      recommend: recommend,
      censor: censor,
    );

    return _pushContent(json, export);
  }

  Future<DismissStatement> doDismiss(dynamic subject, String? dismiss, {String? export}) async {
    assert(dismiss == null || dismiss == 'forever' || dismiss == 'snooze');
    final Json json = DismissStatement.make(await publicKey.json, subject, dismiss);
    return _pushDis(json, export);
  }

  Future<DismissStatement> _pushDis(Json json, String? export) async {
    final source = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements');
    final signer = await OouSigner.make(keyPair);
    await source.fetch({Jsonish(json['I']).token: null});
    final dis = await source.push(json, signer);
    _localDisStatements.insert(0, dis);
    if (export != null) DemoKey._exports[export] = dis.json;
    return dis;
  }

  Future<ContentStatement> doFollow(dynamic subject, Json contexts,
      {ContentVerb verb = ContentVerb.follow, String? export}) async {
    final Json json = await makeFollow(subject, contexts, verb: verb);
    return _pushContent(json, export);
  }

  Future<ContentStatement> doRelate(
    ContentVerb verb, {
    dynamic subject,
    String? title,
    dynamic other,
    String? otherTitle,
    String? export,
  }) async {
    assert((subject != null ? 1 : 0) + (title != null ? 1 : 0) == 1);
    assert((other != null ? 1 : 0) + (otherTitle != null ? 1 : 0) == 1);
    if (title != null) {
      subject = createTestSubject(title: title);
    }
    if (otherTitle != null) {
      other = createTestSubject(title: otherTitle);
    }

    final Json json = await makeRelate(verb, subject!, other!);
    return _pushContent(json, export);
  }

  Future<ContentStatement> _pushContent(Json json, String? export) async {
    final source = channelFactory.getChannel<ContentStatement>(kNerdsterExportUrl, 'statements');
    final signer = await OouSigner.make(keyPair);
    await source.fetch({Jsonish(json['I']).token: null});
    final content = await source.push(json, signer);
    _localStatements.insert(0, content);
    if (export != null) DemoKey._exports[export] = content.json;
    return content;
  }

  Future<EquivalenceStatement> doEquate(String equivalent, String canonical,
      {bool not = false, String? export}) async {
    final Json json = EquivalenceStatement.make(await publicKey.json, equivalent, canonical, not: not);
    return _pushEquiv(json, export);
  }

  Future<EquivalenceStatement> _pushEquiv(Json json, String? export) async {
    final source = channelFactory.getChannel<EquivalenceStatement>(kNerdsterExportUrl, 'statements');
    final signer = await OouSigner.make(keyPair);
    await source.fetch({Jsonish(json['I']).token: null});
    final stmt = await source.push(json, signer);
    if (export != null) DemoKey._exports[export] = stmt.json;
    return stmt;
  }

  Future<Json> toJson() async {
    return {'token': token, 'keyPair': await keyPair.json};
  }
}
