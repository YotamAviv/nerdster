import 'package:flutter/foundation.dart';
import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:oneofus_common/oou_signer.dart';

/// Verifies that the server enforces strict time ordering:
/// a new statement's timestamp must be strictly greater than the previous one's.
Future<void> timeOrderingScenario() async {
  DemoKey.reset();

  final alice = await DemoDelegateKey.create('alice-to');
  final iJson = await alice.publicKey.json;
  final issuerToken = getToken(iJson);
  final signer = await OouSigner.make(alice.keyPair);

  // Capture write rejections via the factory callback.
  Object? capturedError;
  final savedOnWriteError = channelFactory.onWriteError;
  channelFactory.onWriteError = (e) async { capturedError = e; };

  final source = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements');
  await source.fetch({issuerToken: null});

  final DateTime t0 = DateTime.now().toUtc();
  final Json json0 = DismissStatement.make(iJson, createTestSubject(title: 'TO-first'), 'forever');
  json0['time'] = t0.toIso8601String();
  await source.push(json0, signer);
  await source.clear(); // drain: json0 lands in Firestore (write succeeds, no error)
  await source.fetch({issuerToken: null}); // repopulate cache for next push

  // Same timestamp — server must reject.
  capturedError = null;
  final Json jsonSame = DismissStatement.make(iJson, createTestSubject(title: 'TO-same'), 'forever');
  jsonSame['time'] = t0.toIso8601String();
  await source.push(jsonSame, signer);
  await source.clear(); // drain: write rejected, capturedError set, caches cleared
  final sameError = capturedError?.toString();
  await source.fetch({issuerToken: null});

  check(sameError != null && sameError.contains('time ordering'),
      'expected time ordering rejection for same timestamp, got: $sameError');
  debugPrint('time ordering: same-timestamp rejection verified');

  // Earlier timestamp — server must reject.
  capturedError = null;
  final DateTime tEarlier = t0.subtract(const Duration(milliseconds: 1));
  final Json jsonEarlier = DismissStatement.make(iJson, createTestSubject(title: 'TO-earlier'), 'forever');
  jsonEarlier['time'] = tEarlier.toIso8601String();
  await source.push(jsonEarlier, signer);
  await source.clear();
  final earlierError = capturedError?.toString();

  channelFactory.onWriteError = savedOnWriteError;

  check(earlierError != null && earlierError.contains('time ordering'),
      'expected time ordering rejection for earlier timestamp, got: $earlierError');
  debugPrint('time ordering: earlier-timestamp rejection verified');
}
