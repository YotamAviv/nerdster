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
  final disSource = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements');
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
  final contentSource = channelFactory.getChannel<ContentStatement>(kNerdsterExportUrl, 'statements');
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

  // --- Verify the mixed stream is intact on the server ---
  // Dis and content now share a single stream, so chain integrity must be
  // checked on the unfiltered full stream. Filtered results have non-null
  // 'previous' pointers where adjacent statements of the other type were
  // skipped — that is correct behaviour, not a chain violation.
  final fullSource = channelFactory.getChannel<Statement>(kNerdsterExportUrl, 'statements');
  final int cachedTotalLength = (await fullSource.fetch({issuerToken: null}))[issuerToken]!.length;
  fullSource.clear();
  final Map<String, List<Statement>> freshFetch = await fullSource.fetch({issuerToken: null});
  if (fullSource.errors.isNotEmpty) debugPrint('fullSource.errors: ${fullSource.errors}');
  assert(freshFetch.containsKey(issuerToken));
  final List<Statement> freshAll = freshFetch[issuerToken]!;
  check(freshAll.length == cachedTotalLength,
      'stream length: server=${freshAll.length}, cache=$cachedTotalLength');
  _checkChain(freshAll);

  debugPrint('concurrent write: stream integrity verified (${freshAll.length} statements)');
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
