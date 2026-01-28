import 'dart:collection';
import 'package:nerdster/content/content_statement.dart';
import 'package:oneofus_common/io.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:oneofus_common/keys.dart';

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
      delegateFetchMap[key.value] = delegateResolver.getConstraintForDelegate(key);
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

      final IdentityKey? identityKey = delegateResolver.getIdentityForDelegate(DelegateKey(keyStr));
      if (identityKey != null && graph.blocked.contains(identityKey)) {
        throw 'Pipeline Error: Source returned content from blocked identity: ${identityKey.value}';
      }

      delegateContent[DelegateKey(keyStr)] = UnmodifiableListView(rawDelegateContent[keyStr]!);
    }

    return delegateContent;
  }
}
