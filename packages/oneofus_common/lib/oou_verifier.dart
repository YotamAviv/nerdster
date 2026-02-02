import 'crypto/crypto25519.dart';
import 'crypto/crypto.dart';
import 'jsonish.dart';

class OouVerifier implements StatementVerifier {
  @override
  Future<bool> verify(Json json, String string, signature) async {
    try {
      OouPublicKey author = await crypto.parsePublicKey(json['I']!);
      bool out = await author.verifySignature(string, signature);
      return out;
    } catch (e) {
      return false;
    }
  }
}
