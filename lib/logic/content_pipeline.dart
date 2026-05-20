import 'dart:collection';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement_source.dart';

class ContentPipeline {
  /// Full stream source (content + dis) — used for the signed-in user's own delegate keys.
  final StatementSource<ContentStatement> myDelegateSource;

  /// Content-only source (excludes dis statements at the CF) — used for peer delegate keys.
  final StatementSource<ContentStatement> peerDelegateSource;

  ContentPipeline({
    required this.myDelegateSource,
    required this.peerDelegateSource,
  });

  /// Fetches delegate content. [myDelegateKeys] are fetched via the full stream source;
  /// [peerDelegateKeys] are fetched via the content-only source.
  Future<Map<DelegateKey, List<ContentStatement>>> fetchDelegateContent(
    Iterable<DelegateKey> myDelegateKeys,
    Iterable<DelegateKey> peerDelegateKeys, {
    required DelegateResolver delegateResolver,
    required TrustGraph graph,
  }) async {
    final allKeys = [...myDelegateKeys, ...peerDelegateKeys];
    final Set<DelegateKey> knownDelegateKeys = allKeys.toSet();

    Map<String, String?> fetchMap(Iterable<DelegateKey> keys) => {
      for (final DelegateKey key in keys)
        key.value: delegateResolver.getConstraintForDelegate(key),
    };

    final myMap = fetchMap(myDelegateKeys);
    final peerMap = fetchMap(peerDelegateKeys);

    final rawContent = <String, List<ContentStatement>>{};
    if (myMap.isNotEmpty) rawContent.addAll(await myDelegateSource.fetch(myMap));
    if (peerMap.isNotEmpty) rawContent.addAll(await peerDelegateSource.fetch(peerMap));

    for (final String keyStr in rawContent.keys) {
      if (!knownDelegateKeys.contains(DelegateKey(keyStr))) {
        throw 'Pipeline Error: Delegate Source returned content from unauthorized key: $keyStr';
      }
      final IdentityKey? identityKey = delegateResolver.getIdentityForDelegate(DelegateKey(keyStr));
      if (identityKey != null && graph.blocked.contains(identityKey)) {
        throw 'Pipeline Error: Source returned content from blocked identity: ${identityKey.value}';
      }
    }

    final Map<DelegateKey, List<ContentStatement>> delegateContent = {
      for (final DelegateKey key in allKeys)
        key: UnmodifiableListView(rawContent[key.value] ?? []),
    };

    return delegateContent;
  }
}
