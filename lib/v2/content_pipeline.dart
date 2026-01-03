import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/keys.dart';

class ContentPipeline {
  final StatementSource<ContentStatement> delegateSource;

  ContentPipeline({
    required this.delegateSource,
  });

  /// Fetches delegate content for specific delegate keys.
  Future<Map<DelegateKey, List<ContentStatement>>> fetchDelegateContent(
    Iterable<DelegateKey> keys, {
    required DelegateResolver delegateResolver,
    required TrustGraph graph,
  }) async {
    final Map<String, String?> delegateFetchMap = {};
    final Set<DelegateKey> knownDelegateKeys = {};

    for (final DelegateKey key in keys) {
      // We need to find the constraint for this delegate.
      // The DelegateResolver stores constraints by key.
      delegateFetchMap[key.value] = delegateResolver.getConstraintForDelegate(key.value);
      knownDelegateKeys.add(key);
    }

    // 3. Fetch Content
    final Map<String, List<ContentStatement>> rawDelegateContent =
        await delegateSource.fetch(delegateFetchMap);

    // 4. Verify
    final Map<DelegateKey, List<ContentStatement>> delegateContent = {};

    for (final String keyStr in rawDelegateContent.keys) {
      if (!knownDelegateKeys.contains(DelegateKey(keyStr))) {
        throw 'Pipeline Error: Delegate Source returned content from unauthorized key: $keyStr';
      }

      final String? identity = delegateResolver.getIdentityForDelegate(keyStr);
      if (identity != null && graph.blocked.contains(identity)) {
        throw 'Pipeline Error: Source returned content from blocked identity: $identity';
      }

      delegateContent[DelegateKey(keyStr)] = rawDelegateContent[keyStr]!;
    }
    
    return delegateContent;
  }
}
