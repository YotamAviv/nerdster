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

  // --- Sequential writes with queued previous-pointer chaining ---
  // The CachedSource serialises pushes per issuer, so these execute one after
  // another. Each write must reference the current head as its 'previous'.
  // Timestamps are staggered by 1 ms so the server's time-ordering check never
  // fires — we want to exercise the previous-chain logic, not timestamp rejection.
  final disSource = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements');
  await disSource.fetch({issuerToken: null});
  await disSource.push(DismissStatement.make(iJson, createTestSubject(title: 'Prime'), 'forever'), signer);

  final DateTime disNow = DateTime.now().toUtc();
  final Json disJsonA = DismissStatement.make(iJson, subjectA, 'forever');
  final Json disJsonB = DismissStatement.make(iJson, subjectB, 'snooze');
  disJsonB['time'] = disNow.add(const Duration(milliseconds: 1)).toIso8601String();
  final Json disJsonC = DismissStatement.make(iJson, subjectC, null);
  disJsonC['time'] = disNow.add(const Duration(milliseconds: 2)).toIso8601String();

  final disResults = (await Future.wait([
    disSource.push(disJsonA, signer).then<DismissStatement?>((v) => v).catchError((_) => null),
    disSource.push(disJsonB, signer).then<DismissStatement?>((v) => v).catchError((_) => null),
    disSource.push(disJsonC, signer).then<DismissStatement?>((v) => v).catchError((_) => null),
  ])).whereType<DismissStatement>().length;
  check(disResults == 3, 'dis writes: expected all 3 to succeed, got $disResults');
  debugPrint('concurrent dis: ok ($disResults/3 writes succeeded)');

  // --- Concurrent content writes (thumbs up, comment, censor) ---
  final contentSource = channelFactory.getChannel<ContentStatement>(kNerdsterExportUrl, 'statements');
  await contentSource.fetch({issuerToken: null});
  await contentSource.push(
      ContentStatement.make(iJson, ContentVerb.rate, createTestSubject(title: 'Prime'), recommend: true), signer);

  final DateTime contentNow = DateTime.now().toUtc();
  final Json contentJsonA = ContentStatement.make(iJson, ContentVerb.rate, subjectA, recommend: true);
  final Json contentJsonB = ContentStatement.make(iJson, ContentVerb.rate, subjectB, comment: 'great');
  contentJsonB['time'] = contentNow.add(const Duration(milliseconds: 1)).toIso8601String();
  final Json contentJsonC = ContentStatement.make(iJson, ContentVerb.rate, subjectC, censor: true);
  contentJsonC['time'] = contentNow.add(const Duration(milliseconds: 2)).toIso8601String();

  final contentResults = (await Future.wait([
    contentSource.push(contentJsonA, signer).then<ContentStatement?>((v) => v).catchError((_) => null),
    contentSource.push(contentJsonB, signer).then<ContentStatement?>((v) => v).catchError((_) => null),
    contentSource.push(contentJsonC, signer).then<ContentStatement?>((v) => v).catchError((_) => null),
  ])).whereType<ContentStatement>().length;
  check(contentResults == 3, 'content writes: expected all 3 to succeed, got $contentResults');
  debugPrint('concurrent content: ok ($contentResults/3 writes succeeded)');

  // --- Verify the mixed stream is intact on the server ---
  // Use distinct=false so the server returns the full unfiltered chain.
  // distinct=true collapses by subject (ignoring statement type), which drops
  // statements and breaks the previous-pointer chain — not useful here.
  final fullSource = channelFactory.getChannel<Statement>(kNerdsterExportUrl, 'statements', distinct: false);
  final Map<String, List<Statement>> freshFetch = await fullSource.fetch({issuerToken: null});
  if (fullSource.errors.isNotEmpty) debugPrint('fullSource.errors: ${fullSource.errors}');
  assert(freshFetch.containsKey(issuerToken));
  final List<Statement> freshAll = freshFetch[issuerToken]!;
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
