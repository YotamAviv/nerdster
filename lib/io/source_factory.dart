import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/keys.dart' show FedKey, IdentityKey, kNativeUrl;
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/statement_writer.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/models/content_statement.dart';

class SourceFactory {
  /// Trust pipeline: URL comes from the FedKey registry.
  /// Asserts if the token has no registered FedKey (caller's bug).
  static StatementSource<TrustStatement> forIdentity(IdentityKey token) {
    if (fireChoice == FireChoice.fake) {
      return DirectFirestoreSource<TrustStatement>(
        FireFactory.find(kOneofusDomain),
        skipVerify: Setting.get<bool>(SettingType.skipVerify),
      );
    }
    final FedKey? fedKey = FedKey.find(token);
    assert(fedKey != null, 'No FedKey registered for token $token');
    final String url = FirebaseConfig.resolveUrl((fedKey?.endpoint['url'] as String?) ?? kNativeUrl);
    return CloudFunctionsSource<TrustStatement>(
      baseUrl: url,
      verifier: OouVerifier(),
      skipVerify: Setting.get<bool>(SettingType.skipVerify),
    );
  }

  /// Content pipeline: always export.nerdster.org (or its emulator redirect).
  static StatementSource<ContentStatement> forContent() {
    if (fireChoice == FireChoice.fake) {
      return DirectFirestoreSource<ContentStatement>(
        FireFactory.find(kNerdsterDomain),
        skipVerify: Setting.get<bool>(SettingType.skipVerify),
      );
    }
    return CloudFunctionsSource<ContentStatement>(
      baseUrl: FirebaseConfig.contentUrl,
      verifier: OouVerifier(),
      skipVerify: Setting.get<bool>(SettingType.skipVerify),
    );
  }

  static StatementWriter<T> getWriter<T extends Statement>(String domain) {
    return DirectFirestoreWriter(FireFactory.find(domain));
  }
}
