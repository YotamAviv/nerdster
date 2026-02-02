import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:jwk/jwk.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:flutter_test/flutter_test.dart';

final OouCryptoFactory factory = crypto;

void main() {
  test('keyPair json', () async {
    OouKeyPair keyPair = await factory.createKeyPair();
    Json keyPairJson = await keyPair.json;
    Jsonish keyPairJsonish = Jsonish(keyPairJson);

    OouKeyPair keyPair2 = await factory.parseKeyPair(keyPairJson);
    Json keyPairJson2 = await keyPair2.json;
    Jsonish keyPairJsonish2 = Jsonish(keyPairJson2);

    expect(keyPairJsonish, keyPairJsonish2);
  });

  test('publicKey json', () async {
    OouKeyPair keyPair = await factory.createKeyPair();
    OouPublicKey publicKey = await keyPair.publicKey;
    Json publicKeyJson = await publicKey.json;
    Jsonish publicKeyJsonish = Jsonish(publicKeyJson);

    OouPublicKey publicKey2 = await factory.parsePublicKey(publicKeyJson);
    Json publicKeyJson2 = await publicKey2.json;
    Jsonish publicKeyJsonish2 = Jsonish(publicKeyJson2);

    expect(publicKeyJsonish, publicKeyJsonish2);
  });

  test('sign, verify', () async {
    OouKeyPair keyPair = await factory.createKeyPair();

    const String cleartext = "It's really me!";
    String signature = await keyPair.sign(cleartext);

    OouPublicKey publicKey = await keyPair.publicKey;
    bool verified = await publicKey.verifySignature(cleartext, signature);

    expect(verified, true);

    bool verified2 = await publicKey.verifySignature("something else", signature);
    expect(verified2, false);
  });

  test('encrypt/decrypt for myself', () async {
    OouKeyPair keyPair = await factory.createKeyPair();

    const String cleartext = "It's really me!";
    String cyphertext = await keyPair.encryptForSelf(cleartext);

    String cleartext2 = await keyPair.decryptFromSelf(cyphertext);

    expect(cleartext2, cleartext);
  });

  test('Practice encrypt/decrypt for other', () async {
    const String cleartext = "It's really me!";

    // Generate a key pair for Alice
    final algorithm = X25519();
    final SimpleKeyPair aliceKeyPair = await algorithm.newKeyPair();
    final SimplePublicKey alicePublicKey = await aliceKeyPair.extractPublicKey();

    Jwk alicePublicKeyJwk = Jwk.fromPublicKey(alicePublicKey);
    final Json alicePublicKeyJson = alicePublicKeyJwk.toJson();

    final Jwk alicePublicKeyJwk2 = Jwk.fromJson(alicePublicKeyJson);
    final PublicKey? alicePublicKey2 = alicePublicKeyJwk2.toPublicKey();

    // Generate a key pair for Bob.
    final SimpleKeyPair bobKeyPair = await algorithm.newKeyPair();
    final SimplePublicKey bobPublicKey = await bobKeyPair.extractPublicKey();

    // We can now calculate a shared secret.
    final SecretKey sharedSecret1 = await algorithm.sharedSecretKey(
      keyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey,
    );
    final List<int> sharedSecretBytes1 = await sharedSecret1.extractBytes();
    String sharedSecretHex1 = hex.encode(sharedSecretBytes1);

    // We can now calculate a shared secret.
    final SecretKey sharedSecret2 = await algorithm.sharedSecretKey(
      keyPair: bobKeyPair,
      remotePublicKey: alicePublicKey2!,
    );
    final List<int> sharedSecretBytes2 = await sharedSecret2.extractBytes();
    String sharedSecretHex2 = hex.encode(sharedSecretBytes2);

    expect(sharedSecretHex1 == sharedSecretHex2, true);

    // Encrypt
    final secretBox = await aesGcm256.encryptString(
      cleartext,
      secretKey: sharedSecret1,
    );
    assert(secretBox.nonce.length == nonceLength,
        'Unexpected: secretBox.nonce.length = ${secretBox.nonce.length}.');
    assert(secretBox.mac.bytes.length == macLength,
        'Unexpected: secretBox.mac.bytes.length = ${secretBox.mac.bytes.length}');

    // If you are sending the secretBox somewhere, you can concatenate all parts of it:
    final concatenatedBytes = secretBox.concatenation();
    // print('concatenatedBytes.length: ${concatenatedBytes.length}');

    String cyphertext = hex.encode(concatenatedBytes);

    // Decrypt
    List<int> concatenatedBytes2 = hex.decode(cyphertext);
    SecretBox secretBox2 = SecretBox.fromConcatenation(concatenatedBytes2,
        nonceLength: nonceLength, macLength: macLength);

    String cleartext2 = await aesGcm256.decryptString(
      secretBox2,
      secretKey: sharedSecret2,
    );

    expect(cleartext == cleartext2, true);
  });

  test('encrypt/decrypt for other', () async {
    const String cleartext = "It's really me!";

    final PkeKeyPair aliceKeyPair = await factory.createPke();
    final PkePublicKey alicePublicKey = await aliceKeyPair.publicKey;
    final Json alicePublicKeyJson = await alicePublicKey.json;

    final PkeKeyPair bobKeyPair = await factory.createPke();
    final PkePublicKey bobPublicKey = await bobKeyPair.publicKey;
    final Json bobPublicKeyJson = await bobPublicKey.json;

    // Bob encrypts for Alice using his own private key and her JSON decoded public key.
    final String cyphertext =
        await bobKeyPair.encrypt(cleartext, await factory.parsePkePublicKey(alicePublicKeyJson));
    expect(cyphertext != cleartext, true); // (Yup, it's encrypted;)

    // Alice decrypts using her own key pair and Bob's JSON decoded public key.
    final String cleartext2 =
        await aliceKeyPair.decrypt(cyphertext, await factory.parsePkePublicKey(bobPublicKeyJson));
    expect(cleartext == cleartext2, true);
  });
}
