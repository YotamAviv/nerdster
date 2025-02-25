import 'package:flutter/foundation.dart';
import 'package:nerdster/oneofus/util.dart';

import 'crypto/crypto.dart';
import 'jsonish.dart';

class OouSigner implements StatementSigner {
  final OouKeyPair _keyPair;
  final Json _publicKeyJson;

  static Future<OouSigner> make(OouKeyPair keyPair) async {
    OouPublicKey publicKey = await keyPair.publicKey;
    Json publicKeyJson = await publicKey.json;
    return OouSigner._internal(keyPair, publicKeyJson);
  }
  
  OouSigner._internal(this._keyPair, this._publicKeyJson);

  @override
  Future<String> sign(Map<String, dynamic> json, String string) async {
    xssert(mapEquals(json['I'], _publicKeyJson));
    String out = await _keyPair.sign(string);
    return out;
  }
}

