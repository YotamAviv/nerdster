import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/cloud_functions_source.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/io.dart';

class SourceFactory {
  static StatementSource<T> get<T extends Statement>(String domain) {
    final url = V2Config.getUrl(domain);
    
    if (url != null) {
      String type;
      if (domain == kOneofusDomain) {
        type = kOneofusType;
      } else if (domain == kNerdsterDomain) {
        type = kNerdsterType;
      } else {
        // Fallback or throw? For now default to oneofus type or just use domain as type?
        // The legacy code map was strict.
        type = 'unknown'; 
      }
      
      return CloudFunctionsSource<T>(baseUrl: url, statementType: type);
    }
    
    return DirectFirestoreSource<T>(domain);
  }
}
