import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
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
  static const String _kSignInMethod = 'signInMethod';

  static Future<void> storeKeys(
    OouPublicKey oneofusPublicKey,
    OouKeyPair? nerdsterKeyPair, {
    Map<String, dynamic> endpoint = kNativeEndpoint,
    SignInMethod? method,
  }) async {
    await _storage.write(key: kOneofusDomain, value: _encoder.convert(await oneofusPublicKey.json));
    await _storage.write(key: _kFedKeyKey, value: _encoder.convert(endpoint));
    
    if (method != null) {
      await _storage.write(key: _kSignInMethod, value: method.name);
    } else {
      await _storage.delete(key: _kSignInMethod);
    }
    if (nerdsterKeyPair != null) {
      await _storage.write(
          key: kNerdsterDomain, value: _encoder.convert(await nerdsterKeyPair.json));
    } else {
      await _storage.delete(key: kNerdsterDomain);
    }
  }

  static Future<void> wipeKeys() async {
    await _storage.delete(key: kOneofusDomain);
    await _storage.delete(key: kNerdsterDomain);
    await _storage.delete(key: _kFedKeyKey);
    await _storage.delete(key: _kSignInMethod);
  }

  static Future<(OouPublicKey? oneofusPublicKey, OouKeyPair? nerdsterKeyPair, Map<String, dynamic> endpoint, SignInMethod? method)>
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

    SignInMethod? method;
    final String? methodString = await _storage.read(key: _kSignInMethod);
    if (methodString != null) {
      try {
        method = SignInMethod.values.byName(methodString);
      } catch (e) {
        // Fallback gracefully if the stored enum name is invalid or obsolete
      }
    }

    return (oneofusPublicKey, nerdsterKeyPair, endpoint, method);
  }
}
