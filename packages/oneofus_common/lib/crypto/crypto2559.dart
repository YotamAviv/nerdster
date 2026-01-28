// TODO: import 'package:cryptography_flutter/cryptography_flutter.dart';
// Or maybe: https://github.com/emz-hanauer/dart-cryptography, cryptography_flutter_plus..
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:jwk/jwk.dart';

import 'package:oneofus_common/jsonish.dart';
import 'crypto.dart';

const OouCryptoFactory crypto = CryptoFactoryEd25519();

final ed25519 = Ed25519(); // Ed25519, a popular signature algorithm:
final x25519 = X25519(); // Key exchange algorithm
final aesGcm256 = AesGcm.with256bits();

/*
  from: https://pub.dev/documentation/cryptography/latest/cryptography/AesGcm-class.html
  In our implementation, the random part is 96 bits by default... 
  AES-GCM standard specifies a MAC algorithm ("GCM"). The output is a 128-bit Mac...
*/
const nonceLength = 12;
const macLength = 16;

class _PublicKey implements OouPublicKey {
  final PublicKey _publicKey;

  _PublicKey(this._publicKey);

  @override
  Future<Json> get json async {
    final Jwk jwk = Jwk.fromPublicKey(_publicKey);
    final json = jwk.toJson();
    return json;
  }

  @override
  Future<bool> verifySignature(String cleartext, String signatureHex) async {
    Signature signature = Signature(hex.decode(signatureHex), publicKey: _publicKey);
    // Signature signature =
    bool out = await ed25519.verifyString(cleartext, signature: signature);
    return out;
  }
}

class _KeyPair implements OouKeyPair {
  final SimpleKeyPair _keyPair;

  _KeyPair(this._keyPair);

  @override
  Future<Json> get json async {
    Jwk jwk = await Jwk.fromKeyPair(_keyPair);
    final json = jwk.toJson();
    return json;
  }

  @override
  Future<OouPublicKey> get publicKey async {
    PublicKey publicKey = await _keyPair.extractPublicKey();
    OouPublicKey out = _PublicKey(publicKey);
    return out;
  }

  @override
  Future<String> sign(String cleartext) async {
    final signature = await ed25519.signString(
      cleartext,
      keyPair: _keyPair,
    );
    final signatureHex = hex.encode(signature.bytes);
    return signatureHex;
  }

  @override
  Future<String> encryptForSelf(String cleartext) async {
    final secretBytes = await _keyPair.extractPrivateKeyBytes();
    SecretKey secretKey = SecretKey(secretBytes);

    // Encrypt
    final secretBox = await aesGcm256.encryptString(
      cleartext,
      secretKey: secretKey,
    );
    // print('secretBox.nonce.length: ${secretBox.nonce.length}'); // Randomly generated nonce
    // print('secretBox.cipherText.length: ${secretBox.cipherText.length}'); // Encrypted message
    // print('secretBox.mac.bytes.length: ${secretBox.mac.bytes.length}'); // Message authentication code

    assert(secretBox.nonce.length == nonceLength,
        'Unexpected: secretBox.nonce.length = ${secretBox.nonce.length}.');
    assert(secretBox.mac.bytes.length == macLength,
        'Unexpected: secretBox.mac.bytes.length = ${secretBox.mac.bytes.length}');

    // If you are sending the secretBox somewhere, you can concatenate all parts of it:
    final concatenatedBytes = secretBox.concatenation();
    // print('concatenatedBytes.length: ${concatenatedBytes.length}');

    return hex.encode(concatenatedBytes);
  }

  @override
  Future<String> decryptFromSelf(String ciphertext) async {
    List<int> bytes = hex.decode(ciphertext);
    SecretBox secretBox =
        SecretBox.fromConcatenation(bytes, nonceLength: nonceLength, macLength: macLength);

    final secretBytes = await _keyPair.extractPrivateKeyBytes();
    SecretKey secretKey = SecretKey(secretBytes);

    String cleartext = await aesGcm256.decryptString(
      secretBox,
      secretKey: secretKey,
    );

    return cleartext;
  }

  @override
  Future<String> encrypt(String cleartext, OouPublicKey otherPublicKey) {
    throw UnimplementedError();
  }

  @override
  Future<String> decrypt(String ciphertext) {
    throw UnimplementedError();
  }
}

class CryptoFactoryEd25519 implements OouCryptoFactory {
  const CryptoFactoryEd25519();

  @override
  Future<OouKeyPair> createKeyPair() async {
    SimpleKeyPair keyPair = await ed25519.newKeyPair();
    return _KeyPair(keyPair);
  }

  @override
  Future<OouKeyPair> parseKeyPair(Json json) async {
    final jwk = Jwk.fromJson(json);
    final SimpleKeyPair keyPair = jwk.toKeyPair() as SimpleKeyPair;
    return _KeyPair(keyPair);
  }

  @override
  Future<OouPublicKey> parsePublicKey(Json json) async {
    final jwk = Jwk.fromJson(json);
    final PublicKey? publicKey = jwk.toPublicKey();
    _PublicKey out = _PublicKey(publicKey!);
    return out;
  }

  //------------ PKE Public Key Encryption --------------------//

  @override
  Future<PkeKeyPair> createPke() async {
    final SimpleKeyPair keyPair = await x25519.newKeyPair();
    return _PkeKeyPair(keyPair);
  }

  @override
  Future<PkeKeyPair> parsePkeKeyPair(Json json) async {
    throw UnimplementedError();
  }

  @override
  Future<PkePublicKey> parsePkePublicKey(Json json) async {
    final Jwk jwk = Jwk.fromJson(json);
    final PublicKey? publicKey = jwk.toPublicKey();
    return _PkePublicKey(publicKey!);
  }
}

class _PkeKeyPair implements PkeKeyPair {
  final SimpleKeyPair keyPair;

  _PkeKeyPair(this.keyPair);

  @override
  Future<String> encrypt(String cleartext, PkePublicKey otherPublicKey) async {
    final SecretKey sharedSecret1 = await x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: (otherPublicKey as _PkePublicKey).publicKey,
    );
    final secretBox = await aesGcm256.encryptString(
      cleartext,
      secretKey: sharedSecret1,
    );
    assert(secretBox.nonce.length == nonceLength,
        'Unexpected: secretBox.nonce.length = ${secretBox.nonce.length}.');
    assert(secretBox.mac.bytes.length == macLength,
        'Unexpected: secretBox.mac.bytes.length = ${secretBox.mac.bytes.length}');
    final concatenatedBytes = secretBox.concatenation();

    String ciphertext = hex.encode(concatenatedBytes);
    return ciphertext;
  }

  @override
  Future<String> decrypt(String ciphertext, PkePublicKey otherPublicKey) async {
    final SecretKey sharedSecret2 = await x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: (otherPublicKey as _PkePublicKey).publicKey,
    );

    List<int> bytes = hex.decode(ciphertext);
    SecretBox secretBox2 =
        SecretBox.fromConcatenation(bytes, nonceLength: nonceLength, macLength: macLength);

    String cleartext2 = await aesGcm256.decryptString(
      secretBox2,
      secretKey: sharedSecret2,
    );

    return cleartext2;
  }

  @override
  Future<Json> get json async {
    Jwk jwk = await Jwk.fromKeyPair(keyPair);
    return jwk.toJson();
  }

  @override
  Future<PkePublicKey> get publicKey async {
    SimplePublicKey simplePublicKey = await keyPair.extractPublicKey();
    return _PkePublicKey(simplePublicKey);
  }
}

class _PkePublicKey implements PkePublicKey {
  final PublicKey publicKey;

  _PkePublicKey(this.publicKey);

  @override
  Future<Json> get json async {
    Jwk jwk = Jwk.fromPublicKey(publicKey);
    return jwk.toJson();
  }
}
