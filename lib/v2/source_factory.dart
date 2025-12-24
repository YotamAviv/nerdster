import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/cloud_functions_source.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/io.dart';

class SourceFactory {
  static StatementSource<T> get<T extends Statement>(String domain) {
    // TODO(AI): Refactor to use FireChoice/Settings instead of guessing by URL presence.
    // The source selection should be explicit and fail loudly if the requested
    // environment (prod/emulator/fake) is not properly configured.
    final String? url = V2Config.getUrl(domain);

    if (url != null) {
      final String type;
      if (T == TrustStatement) {
        type = kOneofusType;
      } else if (T == ContentStatement) {
        type = kNerdsterType;
      } else {
        throw ArgumentError('Unsupported statement type: $T');
      }

      return CloudFunctionsSource<T>(baseUrl: url, statementType: type);
    }

    return DirectFirestoreSource<T>(domain);
  }
}
