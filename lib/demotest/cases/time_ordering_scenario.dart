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

  final source = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements');
  await source.fetch({issuerToken: null});

  final DateTime t0 = DateTime.now().toUtc();
  final Json json0 = DismissStatement.make(iJson, createTestSubject(title: 'TO-first'), 'forever');
  json0['time'] = t0.toIso8601String();
  await source.push(json0, signer);

  // Same timestamp — server must reject.
  final Json jsonSame = DismissStatement.make(iJson, createTestSubject(title: 'TO-same'), 'forever');
  jsonSame['time'] = t0.toIso8601String();
  String? sameError;
  try {
    await source.push(jsonSame, signer);
  } catch (e) {
    sameError = e.toString();
  }
  check(sameError != null && sameError.contains('time ordering'),
      'expected time ordering rejection for same timestamp, got: $sameError');
  debugPrint('time ordering: same-timestamp rejection verified');

  // Earlier timestamp — server must reject.
  final DateTime tEarlier = t0.subtract(const Duration(milliseconds: 1));
  final Json jsonEarlier = DismissStatement.make(iJson, createTestSubject(title: 'TO-earlier'), 'forever');
  jsonEarlier['time'] = tEarlier.toIso8601String();
  String? earlierError;
  try {
    await source.push(jsonEarlier, signer);
  } catch (e) {
    earlierError = e.toString();
  }
  check(earlierError != null && earlierError.contains('time ordering'),
      'expected time ordering rejection for earlier timestamp, got: $earlierError');
  debugPrint('time ordering: earlier-timestamp rejection verified');
}
