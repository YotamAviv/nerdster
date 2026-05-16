import 'package:flutter/foundation.dart';
import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/statement.dart';

/// Verifies that the push queue serializes simultaneous pushes from the same
/// issuer into a valid previous chain with no conflicts.
///
/// All writes are expected to succeed.
Future<void> concurrentWriteScenario() async {
  DemoKey.reset();

  final alice = await DemoDelegateKey.create('alice-cw');
  final iJson = await alice.publicKey.json;
  final issuerToken = getToken(iJson);
  final signer = await OouSigner.make(alice.keyPair);

  final subjectA = createTestSubject(title: 'Article A');
  final subjectB = createTestSubject(title: 'Article B');
  final subjectC = createTestSubject(title: 'Article C');

  // The push queue serializes writes per issuer, so despite Future.wait
  // submitting all three before any completes, they execute one at a time.
  // Timestamps are staggered by 1ms to satisfy the server's strict time-ordering check.
  final disSource = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements');
  await disSource.fetch({issuerToken: null});

  final DateTime disNow = DateTime.now().toUtc();
  final Json disJsonA = DismissStatement.make(iJson, subjectA, 'forever');
  disJsonA['time'] = disNow.toIso8601String();
  final Json disJsonB = DismissStatement.make(iJson, subjectB, 'snooze');
  disJsonB['time'] = disNow.add(const Duration(milliseconds: 1)).toIso8601String();
  final Json disJsonC = DismissStatement.make(iJson, subjectC, null);
  disJsonC['time'] = disNow.add(const Duration(milliseconds: 2)).toIso8601String();

  await Future.wait([
    disSource.push(disJsonA, signer),
    disSource.push(disJsonB, signer),
    disSource.push(disJsonC, signer),
  ]);
  debugPrint('concurrent dis: all 3 writes succeeded');

  final contentSource = channelFactory.getChannel<ContentStatement>(kNerdsterExportUrl, 'statements');
  await contentSource.fetch({issuerToken: null});

  final DateTime contentNow = DateTime.now().toUtc();
  final Json contentJsonA = ContentStatement.make(iJson, ContentVerb.rate, subjectA, recommend: true);
  contentJsonA['time'] = contentNow.toIso8601String();
  final Json contentJsonB = ContentStatement.make(iJson, ContentVerb.rate, subjectB, comment: 'great');
  contentJsonB['time'] = contentNow.add(const Duration(milliseconds: 1)).toIso8601String();
  final Json contentJsonC = ContentStatement.make(iJson, ContentVerb.rate, subjectC, censor: true);
  contentJsonC['time'] = contentNow.add(const Duration(milliseconds: 2)).toIso8601String();

  await Future.wait([
    contentSource.push(contentJsonA, signer),
    contentSource.push(contentJsonB, signer),
    contentSource.push(contentJsonC, signer),
  ]);
  debugPrint('concurrent content: all 3 writes succeeded');

  // Verify the full chain is intact on the server.
  // distinct=false gives the unfiltered chain; distinct=true collapses by subject
  // which would break previous-pointer verification.
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
