import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';

void main() {
  group('CachedSource concurrent writes', () {
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

    test('concurrent writes on empty stream all succeed without errors', () async {
      final disSource = channelFactory.getChannel<DismissStatement>(
          'https://export.nerdster.org', 'statements');
      await disSource.fetch({issuerToken: null});

      final results = await Future.wait([
        disSource.push(DismissStatement.make(iJson, createTestSubject(title: 'A'), 'snooze'), signer),
        disSource.push(DismissStatement.make(iJson, createTestSubject(title: 'B'), 'snooze'), signer),
        disSource.push(DismissStatement.make(iJson, createTestSubject(title: 'C'), 'snooze'), signer),
      ]);

      expect(results.length, 3);
      expect(results[1].json['previous'], equals(results[0].token));
      expect(results[2].json['previous'], equals(results[1].token));
    });

    test('concurrent writes on existing stream all succeed without errors', () async {
      final disSource = channelFactory.getChannel<DismissStatement>(
          'https://export.nerdster.org', 'statements');
      await disSource.fetch({issuerToken: null});
      await disSource.push(
          DismissStatement.make(iJson, createTestSubject(title: 'Prime'), 'forever'), signer);

      // Simulate a new session: clear the channel cache, same underlying Firestore data.
      channelFactory.clearCache();
      final disSource2 = channelFactory.getChannel<DismissStatement>(
          'https://export.nerdster.org', 'statements');
      await disSource2.fetch({issuerToken: null});

      final results = await Future.wait([
        disSource2.push(DismissStatement.make(iJson, createTestSubject(title: 'A'), 'snooze'), signer),
        disSource2.push(DismissStatement.make(iJson, createTestSubject(title: 'B'), 'snooze'), signer),
        disSource2.push(DismissStatement.make(iJson, createTestSubject(title: 'C'), 'snooze'), signer),
      ]);

      expect(results.length, 3);
      expect(results[1].json['previous'], equals(results[0].token));
      expect(results[2].json['previous'], equals(results[1].token));
    });
  });
}
