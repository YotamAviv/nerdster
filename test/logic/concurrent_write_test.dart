import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late OouSigner signer;
  late Map<String, dynamic> iJson;
  late String issuerToken;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);

    final keyPair = await crypto.createKeyPair();
    signer = await OouSigner.make(keyPair);
    iJson = await (await keyPair.publicKey).json;
    issuerToken = getToken(iJson);
  });

  test('push queue serializes simultaneous pushes into a valid previous chain', () async {
    final ch = channelFactory.getChannel<DismissStatement>(
        'https://export.nerdster.org', 'statements');
    await ch.fetch({issuerToken: null});

    // All three pushes are submitted before any completes, but the internal
    // push queue executes them one at a time, each reading the head left by
    // the previous write — so they form a proper chain with no conflicts.
    final results = await Future.wait([
      ch.push(DismissStatement.make(iJson, createTestSubject(title: 'first'), 'snooze'), signer),
      ch.push(DismissStatement.make(iJson, createTestSubject(title: 'second'), 'snooze'), signer),
      ch.push(DismissStatement.make(iJson, createTestSubject(title: 'third'), 'snooze'), signer),
    ]);

    expect(results.length, 3);
    expect(results[1].json['previous'], equals(results[0].token));
    expect(results[2].json['previous'], equals(results[1].token));
  });
}
