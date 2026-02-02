import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';

/// BUG: Totally broken.
/// DirectFirestoreSource does not expose a way to fetch all statements for a given identity token.
/// Futhermore, it skips past problems.
/// This could/should use CloudFunctionsSource.
///
class CorruptionCheck {
  static final OouVerifier _oouVerifier = OouVerifier();

  // TODO: Restore iteration over all keys when key discovery is available.
  static Future<void> make(List<String> keysToCheck) async {
    print('Checking ${keysToCheck.length} keys...');

    for (String token in keysToCheck) {
      // TODO: Determine correct domain/type for each key.
      // For now, checking both domains as both types.
      await check<TrustStatement>(token, kOneofusDomain);
      await check<ContentStatement>(token, kNerdsterDomain);
    }
  }

  static Future<void> check<T extends Statement>(String token, String domain) async {
    // Use DirectFirestoreSource to fetch raw statements without verification
    // We temporarily disable verification in settings to get raw data
    final bool originalSkipVerify = Setting.get<bool>(SettingType.skipVerify).value;
    Setting.get<bool>(SettingType.skipVerify).value = true;

    try {
      final fire = FireFactory.find(domain);
      final source = DirectFirestoreSource<T>(fire);

      final Map<String, List<T>> results = await source.fetch({token: null});
      final List<T> statements = results[token]!;

      await _validateStatements(statements, token, domain);
    } catch (e) {
      print('Fetch failed for $token on $domain: $e');
    } finally {
      Setting.get<bool>(SettingType.skipVerify).value = originalSkipVerify;
    }
  }

  static Future<void> _validateStatements(
      List<Statement> statements, String identityToken, String domain) async {
    String? previousToken;
    DateTime? previousTime;

    for (Statement s in statements) {
      String token = s.token;
      DateTime time = s.time;

      // Validate notary chain, decending order
      if (previousTime == null) {
        // no check for first (newest) statement
      } else {
        if (s.token != previousToken) {
          String error = '$identityToken $time !notary: $token != $previousToken';
          print(error);
        }
        if (!time.isBefore(previousTime)) {
          String error = '$identityToken $time !desc: $time >= $previousTime';
          print(error);
        }
      }
      previousToken = s['previous'];
      previousTime = time;

      // Validate signature
      final Json ordered = Jsonish.order(s.json);
      final String ppJson = encoder.convert(ordered);
      final String token2 = sha1.convert(utf8.encode(ppJson)).toString();
      assert(token == token2, 'computed by Jsonish the same way');
      String signature = ordered['signature']!;
      var orderedWithoutSig = Map.from(ordered)..remove('signature');
      String ppJsonWithoutSig = encoder.convert(orderedWithoutSig);
      bool verified = await _oouVerifier.verify(ordered, ppJsonWithoutSig, signature);
      if (!verified) {
        String error = '!verified';
        print(error);
      }

      // Validate verb (Well, we have a Statement, and so something up the chain should have crashed with a bad verb)
      if (domain == kOneofusDomain) {
        if (s is! TrustStatement) {
          print('!type: Expected TrustStatement, got ${s.runtimeType}');
        }
      } else if (domain == kNerdsterDomain) {
        if (s is! ContentStatement) {
          print('!type: Expected ContentStatement, got ${s.runtimeType}');
        }
      } else {
        assert(false, domain);
      }

      print(',');
    }
    print('.');
  }
}
