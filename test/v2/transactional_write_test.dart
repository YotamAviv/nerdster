import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/crypto/crypto2559.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/content/content_statement.dart';

void main() {
  group('DirectFirestoreWriter Transactional Tests', () {
    late FakeFirebaseFirestore firestore;
    late DirectFirestoreWriter writer;
    late OouSigner signer;
    late Json publicKeyJson;

    setUp(() async {
      ContentStatement.init();
      firestore = FakeFirebaseFirestore();
      writer = DirectFirestoreWriter(firestore);
      
      final keyPair = await CryptoFactoryEd25519().createKeyPair();
      signer = await OouSigner.make(keyPair);
      publicKeyJson = await (await keyPair.publicKey).json;
    });

    test('Sequential writes should maintain the notary chain', () async {
      final issuerToken = getToken(publicKeyJson);

      // 1. First write (no previous)
      final json1 = ContentStatement.make(
        publicKeyJson,
        ContentVerb.rate,
        'subject1',
        recommend: true,
      );
      final s1 = await writer.push(json1, signer);
      expect(s1.json['previous'], isNull);

      // 2. Second write (should automatically pick up s1 as previous)
      final json2 = ContentStatement.make(
        publicKeyJson,
        ContentVerb.rate,
        'subject2',
        recommend: true,
      );
      final s2 = await writer.push(json2, signer);
      expect(s2.json['previous'], equals(s1.token));

      // Verify in Firestore
      final statements = await firestore
          .collection(issuerToken)
          .doc('statements')
          .collection('statements')
          .orderBy('time')
          .get();
      
      expect(statements.docs.length, 2);
      expect(statements.docs[0].id, s1.token);
      expect(statements.docs[1].id, s2.token);
      expect(statements.docs[1].data()['previous'], s1.token);

      // Verify head document
      final headDoc = await firestore.collection(issuerToken).doc('statements').get();
      expect(headDoc.data()?['head'], s2.token);
    });

    test('Writes with invalid timestamps should be rejected', () async {
      // 1. Write Statement A
      final jsonA = ContentStatement.make(
        publicKeyJson,
        ContentVerb.rate,
        'subjectA',
        recommend: true,
      );
      await writer.push(jsonA, signer);

      // 2. Attempt to write Statement B with an OLD timestamp
      final jsonB = ContentStatement.make(
        publicKeyJson,
        ContentVerb.rate,
        'subjectB',
        recommend: true,
      );
      // Set time to 1 hour ago
      jsonB['time'] = formatIso(DateTime.now().subtract(const Duration(hours: 1)));

      expect(
        () => writer.push(jsonB, signer),
        throwsA(predicate((e) => e.toString().contains('Timestamp must be after previous statement'))),
      );
    });
  });
}
