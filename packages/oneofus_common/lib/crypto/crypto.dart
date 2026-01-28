// For performance: https://pub.dev/packages/cryptography_flutter .
// $ flutter pub add cryptography_flutter

import 'package:oneofus_common/jsonish.dart';

/// Requirements:
/// Bridge to libraries
/// - generate public/private key pairs
/// - encode/decode (bonus: comply to some accepted standartd if one exists, JWK?)
///   - keyPair
///   - publicKey
/// - sign/verify statements (strings)
/// - encrypt/decrypt for myself (use my own keyPair)
/// - encrypt/decrypt for some other nerd (my keyPair, their publicKey)

abstract class OouCryptoFactory {
  //------------ Public Key Signing --------------------//
  Future<OouKeyPair> createKeyPair();
  Future<OouKeyPair> parseKeyPair(Json json);
  Future<OouPublicKey> parsePublicKey(Json json);

  //------------ Public Key Encryption (PKE) --------------------//
  Future<PkeKeyPair> createPke();
  Future<PkeKeyPair> parsePkeKeyPair(Json json);
  Future<PkePublicKey> parsePkePublicKey(Json json);
}

abstract class OouKeyPair {
  Future<Json> get json;

  Future<OouPublicKey> get publicKey;

  // Return value might Json instead.
  Future<String> sign(String cleartext);

  // Return value might Json instead.
  Future<String> encryptForSelf(String cleartext);
  Future<String> decryptFromSelf(String ciphertext);

  Future<String> encrypt(String cleartext, OouPublicKey otherPublicKey);
  Future<String> decrypt(String ciphertext);
}

// CONSIDER: cache json and token; they're useful without 'await'
abstract class OouPublicKey {
  Future<Json> get json;

  Future<bool> verifySignature(String cleartext, String signature);
}

abstract class PkeKeyPair {
  Future<PkePublicKey> get publicKey;
  Future<Json> get json;
  Future<String> encrypt(String cleartext, PkePublicKey otherPublicKey);
  Future<String> decrypt(String ciphertext, PkePublicKey otherPublicKey);
}

abstract class PkePublicKey {
  Future<Json> get json;
}
