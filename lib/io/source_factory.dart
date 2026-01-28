import 'package:oneofus_common/statement.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:oneofus_common/fire_factory.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:nerdster/config.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/io.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';

class SourceFactory {
  static StatementSource<T> get<T extends Statement>(String domain) =>
      (fireChoice == FireChoice.fake)
          ? DirectFirestoreSource<T>(
              FireFactory.find(domain),
              skipVerify: Setting.get<bool>(SettingType.skipVerify),
            )
          : CloudFunctionsSource<T>(
              baseUrl: FirebaseConfig.getUrl(domain)!,
              verifier: OouVerifier(),
              skipVerify: Setting.get<bool>(SettingType.skipVerify),
            );

  static StatementWriter getWriter(String domain) {
    return DirectFirestoreWriter(FireFactory.find(domain));
  }
}
