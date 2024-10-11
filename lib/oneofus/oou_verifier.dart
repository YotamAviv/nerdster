import 'crypto/crypto.dart';
import 'jsonish.dart';
import 'util.dart';

class OouVerifier implements StatementVerifier {
  @override
  Future<bool> verify(Map<String, dynamic> json, String string, signature) async {
    OouPublicKey author = await crypto.parsePublicKey(json['I']!);
    bool out = await author.verifySignature(string, signature);
    return out;
  }
}
