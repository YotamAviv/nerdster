import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/block_old_key.dart';
import 'package:nerdster/demotest/cases/decapitate.dart';
import 'package:nerdster/demotest/cases/delegate_merge.dart';
import 'package:nerdster/demotest/cases/deletions.dart';
import 'package:nerdster/demotest/cases/egos.dart';
import 'package:nerdster/demotest/cases/equivalent_keys_state_conflict.dart';
import 'package:nerdster/demotest/cases/loner.dart';
import 'package:nerdster/demotest/cases/multiple_blocks.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';
import 'package:nerdster/demotest/cases/stress.dart';
import 'package:nerdster/demotest/cases/trust_block_conflict.dart';
import 'package:nerdster/demotest/cases/yotam.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/crypto/crypto2559.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
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

class DemoKey {
  static final Map<String, DemoKey> _name2key = <String, DemoKey>{};
  static final Map<String, DemoKey> _token2key = <String, DemoKey>{};

  static final dynamic demos = {
    'loner': loner,
    'egos': egos,
    'simpsons': simpsons,
    'delegateMerge': delegateMerge,
    'delete3': deletions3,
    'blockOldKey': blockOldKey,
    'multipleBlocks': multipleBlocks,
    'trustBlockConflict': trustBlockConflict,
    'equivalentKeysStateConflict': equivalentKeysStateConflict,
    'lonerEquate': lonerEquate,
    'decap2': decap2,
    'decap': decap,
    'stress': stress,
    'yotam': yotam,
  };

  static clear() {
    _name2key.clear();
    _token2key.clear();
  }

  final String name;
  final OouKeyPair keyPair;
  final OouPublicKey publicKey;
  final String token;

  static Iterable<DemoKey> get all => _name2key.values;

  static DemoKey? findByName(String name) => _name2key[name];

  static DemoKey? findByToken(String token) => _token2key[token];

  static Future<DemoKey> findOrCreate(String name) async {
    if (!_name2key.containsKey(name)) {
      final OouKeyPair keyPair = await _crypto.createKeyPair();
      final OouPublicKey publicKey = await keyPair.publicKey;
      final String token = Jsonish(await publicKey.json).token;
      DemoKey out = DemoKey._internal(name, keyPair, publicKey, token);
      _name2key[name] = out;
      _token2key[token] = out;
    }
    return _name2key[name]!;
  }

  DemoKey._internal(this.name, this.keyPair, this.publicKey, this.token);

  Future<Jsonish> doRate(
      {Json? subject,
      String? title,
      String? comment,
      bool? recommend,
      ContentVerb? verb}) async {
    assert(i(title) + i(subject) == 1);
    if (b(title)) {
      subject = {'contentType': 'article', 'title': title, 'url': 'u1'};
    }
    ContentVerb useVerb = verb ?? ContentVerb.rate;
    Json json = ContentStatement.make(await publicKey.json, useVerb, subject!,
        comment: comment, recommend: recommend);
    Fetcher fetcher = Fetcher(token, kNerdsterDomain);
    OouSigner signer = await OouSigner.make(keyPair);
    Jsonish statement = await fetcher.push(json, signer);
    return statement;
  }

  Future<Jsonish> doFollow(DemoKey other, Json contexts, {ContentVerb? verb}) async {
    ContentVerb useVerb = verb ?? ContentVerb.follow;
    Json json = ContentStatement.make(await publicKey.json, useVerb, await (other.publicKey).json,
        contexts: contexts);
    Fetcher fetcher = Fetcher(token, kNerdsterDomain);
    OouSigner signer = await OouSigner.make(keyPair);
    Jsonish statement = await fetcher.push(json, signer);
    return statement;
  }

  Future<Jsonish> doCensor({Json? subject, String? title}) async {
    assert(i(title) + i(subject) == 1);
    if (b(title)) {
      subject = {'contentType': 'article', 'title': title, 'url': 'u1'};
    }
    Json json =
        ContentStatement.make(await publicKey.json, ContentVerb.censor, Jsonish(subject!).token);
    Fetcher fetcher = Fetcher(token, kNerdsterDomain);
    OouSigner signer = await OouSigner.make(keyPair);
    Jsonish statement = await fetcher.push(json, signer);
    return statement;
  }

  Future<Jsonish> doRelate(ContentVerb verb,
      {Json? subject, String? title, Json? other, String? otherTitle}) async {
    assert(i(subject) + i(title) == 1);
    assert(i(other) + i(otherTitle) == 1);
    if (b(title)) {
      subject = {'contentType': 'article', 'title': title, 'url': 'u1'};
    }
    if (b(otherTitle)) {
      other = {'contentType': 'article', 'title': otherTitle, 'url': 'u1'};
    }
    Json json = ContentStatement.make(await publicKey.json, verb, subject, other: other);
    Fetcher fetcher = Fetcher(token, kNerdsterDomain);
    OouSigner signer = await OouSigner.make(keyPair);
    Jsonish statement = await fetcher.push(json, signer);
    return statement;
  }

  Future<Jsonish> doTrust(TrustVerb verb, DemoKey other,
      {String? moniker, String? comment, String? domain, String? revokeAt}) async {
    switch (verb) {
      case TrustVerb.trust:
        moniker ??= other.name;
      case TrustVerb.block:
        comment ??= 'blocking demo ${other.name}';
      case TrustVerb.replace:
        comment ??= 'replacing demo ${other.name}';
      case TrustVerb.delegate:
        assert(!b(moniker));
      case TrustVerb.clear:
    }

    Json json = TrustStatement.make(
        await (await keyPair.publicKey).json, await (other.publicKey).json, verb,
        domain: domain, moniker: moniker, comment: comment, revokeAt: revokeAt);

    Fetcher fetcher = Fetcher(token, kOneofusDomain);
    OouSigner signer = await OouSigner.make(keyPair);
    Jsonish statement = await fetcher.push(json, signer);
    return statement;
  }

  Future<DemoKey> makeDelegate() async {
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
    // It would be nice to have this returned (so that we can revoke at it)
    Jsonish jsonish = await doTrust(TrustVerb.delegate, delegateKey, domain: kNerdsterDomain);

    return delegateKey;
  }
}

Future<void> printDemoCredentials(DemoKey oneofus, DemoKey? delegate) async {
  print(oneofus.token);
  var credentials = {
    kOneofusDomain: await oneofus.keyPair.json,
    if (b(delegate)) kNerdsterDomain: await delegate!.keyPair.json,
  };
  print(Jsonish.encoder.convert(credentials));
}
