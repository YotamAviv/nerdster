import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show kNativeEndpoint;
import 'package:oneofus_common/trust_statement.dart';

/// UI:
/// Be offered to store keys during sign-in.
/// Load page automatically signs-in if stored keys exist.
/// Sign out clears stored keys.
/// Default Oneofus center used when signed out.
class KeyStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const _encoder = Jsonish.encoder;
  static const OouCryptoFactory _crypto = crypto;
  static const String _kFedKeyKey = 'oneofus_home';

  static Future<void> storeKeys(
    OouPublicKey oneofusPublicKey,
    OouKeyPair? nerdsterKeyPair, {
    Map<String, dynamic> endpoint = kNativeEndpoint,
  }) async {
    await _storage.write(key: kOneofusDomain, value: _encoder.convert(await oneofusPublicKey.json));
    await _storage.write(key: _kFedKeyKey, value: _encoder.convert(endpoint));
    if (nerdsterKeyPair != null) {
      await _storage.write(
          key: kNerdsterDomain, value: _encoder.convert(await nerdsterKeyPair.json));
    }
  }

  static Future<void> wipeKeys() async {
    await _storage.delete(key: kOneofusDomain);
    await _storage.delete(key: kNerdsterDomain);
    await _storage.delete(key: _kFedKeyKey);
  }

  static Future<(OouPublicKey? oneofusPublicKey, OouKeyPair? nerdsterKeyPair, Map<String, dynamic> endpoint)>
      readKeys() async {
    OouPublicKey? oneofusPublicKey;
    String? oneofusString = await _storage.read(key: kOneofusDomain);
    if (oneofusString != null) {
      Json json = jsonDecode(oneofusString);
      oneofusPublicKey = await _crypto.parsePublicKey(json);
    }
    OouKeyPair? nerdsterKeyPair;
    String? nerdsterString = await _storage.read(key: kNerdsterDomain);
    if (nerdsterString != null) {
      Json json = jsonDecode(nerdsterString);
      nerdsterKeyPair = await _crypto.parseKeyPair(json);
    }
    // Read stored endpoint JSON. Old sessions stored a plain hostname string;
    // convert those to {url: 'https://<host>'} for backward compat.
    Map<String, dynamic> endpoint = kNativeEndpoint;
    final String? stored = await _storage.read(key: _kFedKeyKey);
    if (stored != null) {
      final dynamic parsed = jsonDecode(stored);
      if (parsed is Map<String, dynamic>) {
        endpoint = parsed;
      } else if (parsed is String) {
        // Legacy: plain hostname like 'export.one-of-us.net'
        endpoint = {'url': 'https://$parsed'};
      }
    }
    return (oneofusPublicKey, nerdsterKeyPair, endpoint);
  }

  // ── Bootstrap ────────────────────────────────────────────────────────────
  static const _kBootstrapFlag = 'bootstrap_mode';
  static const _kBootstrapIdentity = 'bootstrap_identity_keypair';
  static const _kBootstrapDelegate = 'bootstrap_delegate_keypair';

  /// Persists both bootstrap key pairs and the bootstrap flag.
  static Future<void> storeBootstrapKeys(
      OouKeyPair identityKeyPair, OouKeyPair delegateKeyPair) async {
    await _storage.write(key: _kBootstrapFlag, value: 'true');
    await _storage.write(
        key: _kBootstrapIdentity, value: _encoder.convert(await identityKeyPair.json));
    await _storage.write(
        key: _kBootstrapDelegate, value: _encoder.convert(await delegateKeyPair.json));
  }

  static Future<bool> isBootstrapMode() async {
    return (await _storage.read(key: _kBootstrapFlag)) == 'true';
  }

  /// Returns null if not in bootstrap mode.
  static Future<(OouKeyPair identityKeyPair, OouKeyPair delegateKeyPair)?> readBootstrapKeys() async {
    final flag = await _storage.read(key: _kBootstrapFlag);
    if (flag != 'true') return null;
    final identityStr = await _storage.read(key: _kBootstrapIdentity);
    final delegateStr = await _storage.read(key: _kBootstrapDelegate);
    if (identityStr == null || delegateStr == null) return null;
    final identityKP = await _crypto.parseKeyPair(jsonDecode(identityStr));
    final delegateKP = await _crypto.parseKeyPair(jsonDecode(delegateStr));
    return (identityKP, delegateKP);
  }

  static Future<void> clearBootstrapKeys() async {
    await _storage.delete(key: _kBootstrapFlag);
    await _storage.delete(key: _kBootstrapIdentity);
    await _storage.delete(key: _kBootstrapDelegate);
  }
}
