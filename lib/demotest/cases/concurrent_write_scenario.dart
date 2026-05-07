import 'package:flutter/foundation.dart';
import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/statement.dart';

/// Fires multiple writes concurrently from the same issuer.
///
/// Uses the shared CachedSource instances from channelFactory, matching real app behavior.
/// Some writes may fail due to optimistic concurrency conflicts (server-side previous mismatch);
/// the scenario only requires that at least one write succeeds per stream.
Future<void> concurrentWriteScenario() async {
  DemoKey.reset();

  final alice = await DemoDelegateKey.create('alice-cw');
  final iJson = await alice.publicKey.json;
  final issuerToken = getToken(iJson);
  final signer = await OouSigner.make(alice.keyPair);

  final subjectA = createTestSubject(title: 'Article A');
  final subjectB = createTestSubject(title: 'Article B');
  final subjectC = createTestSubject(title: 'Article C');

  // --- Concurrent dis writes (simulates 3 simultaneous thumbs-down swipes) ---
  final disSource = channelFactory.getChannel<DismissStatement>(kNerdsterDomain, 'dis', allStreams: ['statements', 'dis']);
  await disSource.fetch({issuerToken: null});
  await disSource.push(DismissStatement.make(iJson, createTestSubject(title: 'Prime'), 'forever'), signer);
  final disResults = (await Future.wait([
    disSource.push(DismissStatement.make(iJson, subjectA, 'forever'), signer).then<DismissStatement?>((v) => v).catchError((_) => null),
    disSource.push(DismissStatement.make(iJson, subjectB, 'snooze'), signer).then<DismissStatement?>((v) => v).catchError((_) => null),
    disSource.push(DismissStatement.make(iJson, subjectC, null), signer).then<DismissStatement?>((v) => v).catchError((_) => null),
  ])).whereType<DismissStatement>().length;
  check(disResults >= 1, 'concurrent dis: expected at least 1 success, got $disResults');
  debugPrint('concurrent dis: ok ($disResults/3 writes succeeded)');

  // --- Concurrent content writes (thumbs up, comment, censor) ---
  final contentSource = channelFactory.getChannel<ContentStatement>(kNerdsterDomain, 'statements', allStreams: ['statements', 'dis']);
  await contentSource.fetch({issuerToken: null});
  await contentSource.push(
      ContentStatement.make(iJson, ContentVerb.rate, createTestSubject(title: 'Prime'), recommend: true), signer);
  final contentResults = (await Future.wait([
    contentSource.push(ContentStatement.make(iJson, ContentVerb.rate, subjectA, recommend: true), signer).then<ContentStatement?>((v) => v).catchError((_) => null),
    contentSource.push(ContentStatement.make(iJson, ContentVerb.rate, subjectB, comment: 'great'), signer).then<ContentStatement?>((v) => v).catchError((_) => null),
    contentSource.push(ContentStatement.make(iJson, ContentVerb.rate, subjectC, censor: true), signer).then<ContentStatement?>((v) => v).catchError((_) => null),
  ])).whereType<ContentStatement>().length;
  check(contentResults >= 1, 'concurrent content: expected at least 1 success, got $contentResults');
  debugPrint('concurrent content: ok ($contentResults/3 writes succeeded)');

  // --- Verify both streams are intact on the server ---
  final Map<String, List<DismissStatement>> cachedFetchDis = await disSource.fetch({issuerToken: null});
  assert(cachedFetchDis.containsKey(issuerToken));
  final int cachedDisLength = cachedFetchDis[issuerToken]!.length;
  disSource.clear();
  final Map<String, List<DismissStatement>> freshFetchDis = await disSource.fetch({issuerToken: null});
  if (disSource.errors.isNotEmpty) debugPrint('disSource.errors: ${disSource.errors}');
  assert(freshFetchDis.containsKey(issuerToken));
  final List<DismissStatement> freshDis = freshFetchDis[issuerToken]!;
  check(freshDis.length == cachedDisLength,
      'dis stream length: server=${freshDis.length}, cache=$cachedDisLength');
  _checkChain(freshDis);

  final Map<String, List<ContentStatement>> cachedFetchContent = await contentSource.fetch({issuerToken: null});
  assert(cachedFetchContent.containsKey(issuerToken));
  final int cachedContentLength = cachedFetchContent[issuerToken]!.length;
  contentSource.clear();
  final Map<String, List<ContentStatement>> freshFetchContent = await contentSource.fetch({issuerToken: null});
  assert(freshFetchContent.containsKey(issuerToken));
  final List<ContentStatement> freshContent = freshFetchContent[issuerToken]!;
  check(freshContent.length == cachedContentLength,
      'content stream length: server=${freshContent.length}, cache=$cachedContentLength');
  _checkChain(freshContent);

  debugPrint('concurrent write: stream integrity verified');
}

void _checkChain(List<Statement> statements) {
  for (int i = 0; i < statements.length; i++) {
    final String? prev = statements[i]['previous'];
    if (i + 1 < statements.length) {
      check(prev == statements[i + 1].token,
          'chain broken at index $i: previous=$prev, expected=${statements[i + 1].token}');
    } else {
      check(prev == null || prev.isEmpty,
          'genesis statement should have no previous, got $prev');
    }
  }
}
