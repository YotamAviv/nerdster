import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:oneofus_common/cached_source.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';

void main() {
  group('CachedSource concurrent writes', () {
    late FakeFirebaseFirestore firestore;
    late OouSigner signer;
    late Map<String, dynamic> iJson;
    late String issuerToken;
    late CachedSource<DismissStatement> disSource;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      setUpTestRegistry(firestore: firestore);

      final keyPair = await crypto.createKeyPair();
      signer = await OouSigner.make(keyPair);
      iJson = await (await keyPair.publicKey).json;
      issuerToken = getToken(iJson);

      final source = DirectFirestoreSource<DismissStatement>(firestore, streamId: 'dis');
      final writer = DirectFirestoreWriter<DismissStatement>(firestore, streamId: 'dis');
      disSource = CachedSource(source, writer);
    });

    test('concurrent writes on empty stream all succeed without errors', () async {
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
      // Write one statement to establish a chain head.
      await disSource.fetch({issuerToken: null});
      await disSource.push(DismissStatement.make(iJson, createTestSubject(title: 'Prime'), 'forever'), signer);

      // Simulate a new session: fresh CachedSource but same underlying Firestore data.
      final source2 = DirectFirestoreSource<DismissStatement>(firestore, streamId: 'dis');
      final writer2 = DirectFirestoreWriter<DismissStatement>(firestore, streamId: 'dis');
      final disSource2 = CachedSource<DismissStatement>(source2, writer2);
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
