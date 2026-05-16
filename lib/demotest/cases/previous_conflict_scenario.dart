import 'package:flutter/foundation.dart';
import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:oneofus_common/oou_signer.dart';

/// Verifies that the server rejects a write whose 'previous' token is stale —
/// i.e., another write already advanced the stream head since this client fetched.
///
/// Two channels are used: channelA (distinct: true) and channelB (distinct: false).
/// They have separate roots and separate push queues, so they can race.
/// Both fetch the same initial head. channelA writes first, advancing the server head.
/// channelB then tries to write with its cached (now-stale) previous — the server rejects it.
Future<void> previousConflictScenario() async {
  DemoKey.reset();

  final alice = await DemoDelegateKey.create('alice-pc');
  final iJson = await alice.publicKey.json;
  final issuerToken = getToken(iJson);
  final signer = await OouSigner.make(alice.keyPair);

  // Two channels backed by separate roots (different cache keys due to distinct flag).
  final channelA = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements');
  final channelB = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements', distinct: false);

  // Both observe the same initial head.
  await channelA.fetch({issuerToken: null});
  await channelB.fetch({issuerToken: null});

  // channelA writes first — server head advances.
  final DateTime t0 = DateTime.now().toUtc();
  final Json jsonA = DismissStatement.make(iJson, createTestSubject(title: 'PC-A'), 'forever');
  jsonA['time'] = t0.toIso8601String();
  await channelA.push(jsonA, signer);

  // channelB still holds the old head. Its push sends a stale 'previous' — server must reject.
  final DateTime t1 = t0.add(const Duration(milliseconds: 1));
  final Json jsonB = DismissStatement.make(iJson, createTestSubject(title: 'PC-B'), 'forever');
  jsonB['time'] = t1.toIso8601String();

  String? conflictError;
  try {
    await channelB.push(jsonB, signer);
  } catch (e) {
    conflictError = e.toString();
  }
  check(conflictError != null, 'expected previous conflict rejection, got no error');
  debugPrint('previous conflict: stale previous rejection verified ($conflictError)');
}
