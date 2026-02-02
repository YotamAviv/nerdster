import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
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

  static Future<void> storeKeys(OouPublicKey oneofusPublicKey, OouKeyPair? nerdsterKeyPair) async {
    await _storage.write(key: kOneofusDomain, value: _encoder.convert(await oneofusPublicKey.json));
    if (nerdsterKeyPair != null) {
      await _storage.write(
          key: kNerdsterDomain, value: _encoder.convert(await nerdsterKeyPair.json));
    }
  }

  static Future<void> wipeKeys() async {
    await _storage.delete(key: kOneofusDomain);
    await _storage.delete(key: kNerdsterDomain);
  }

  static Future<(OouPublicKey? oneofusPublicKey, OouKeyPair? nerdsterKeyPair)> readKeys() async {
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
    return (oneofusPublicKey, nerdsterKeyPair);
  }
}
