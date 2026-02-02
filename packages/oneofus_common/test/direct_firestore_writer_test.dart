import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/statement_writer.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/jsonish.dart';

class TestStatement extends Statement {
  TestStatement(Jsonish jsonish) : super(jsonish, jsonish['subject'] ?? 'default');

  @override
  String getDistinctSignature(
          {Transformer? iTransformer, Transformer? sTransformer}) =>
      'test_sig';

  @override
  bool get isClear => true;

  static Map<String, dynamic> template(Map<String, dynamic> i, String subject) {
    return {
      'statement': 'test',
      'I': i,
      'time': DateTime.now().toUtc().toIso8601String(),
      'subject': subject,
    };
  }
}

class TestFactory implements StatementFactory {
  const TestFactory();

  @override
  Statement make(Jsonish j) => TestStatement(j);
}

void main() {
  group('DirectFirestoreWriter (with FakeFirestore)', () {
    late FakeFirebaseFirestore firestore;
    late DirectFirestoreWriter<TestStatement> writer;
    late OouSigner signer;
    late Map<String, dynamic> publicKeyJson;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      writer = DirectFirestoreWriter(firestore);

      final keyPair = await crypto.createKeyPair();
      signer = await OouSigner.make(keyPair);
      publicKeyJson = await (await keyPair.publicKey).json;

      Statement.registerFactory('test', const TestFactory(), TestStatement);
    });

    test('Sequential writes (Optimistic Queue) should maintain chain and order',
        () async {
      final issuerToken = getToken(publicKeyJson);

      // Pre-calculate chain to allow simultaneous firing
      // We need to ensure timestamps are fixed so signatures match
      final time1 = DateTime.now().toUtc().toIso8601String();
      final time2 = DateTime.now().add(const Duration(seconds: 1)).toUtc().toIso8601String();
      final time3 = DateTime.now().add(const Duration(seconds: 2)).toUtc().toIso8601String();

      // 1. Prepare Data
      final json1 = TestStatement.template(publicKeyJson, 'subject1')..['time'] = time1;
      final json2 = TestStatement.template(publicKeyJson, 'subject2')..['time'] = time2;
      final json3 = TestStatement.template(publicKeyJson, 'subject3')..['time'] = time3;

      // 2. Pre-calc tokens (Simulating what the client expects)
      final jsonish1 = await Jsonish.makeSign(Map.from(json1), signer);
      final token1 = jsonish1.token;

      final jsonish2 = await Jsonish.makeSign(Map.from(json2)..[ 'previous'] = token1, signer);
      final token2 = jsonish2.token;

      // 3. Fire writes simultaneously
      // Note: We don't await the result of the first before starting the second.
      // This stresses the synchronous queueing logic in DirectFirestoreWriter.
      
      final future1 = writer.push(json1, signer,
          previous: const ExpectedPrevious(null), // First one has no previous
          optimisticConcurrencyFailed: () => fail('Concurreny 1 failed'));
      
      final future2 = writer.push(json2, signer,
          previous: ExpectedPrevious(token1),
          optimisticConcurrencyFailed: () => fail('Concurreny 2 failed'));
      
      final future3 = writer.push(json3, signer,
          previous: ExpectedPrevious(token2),
          optimisticConcurrencyFailed: () => fail('Concurreny 3 failed'));

      // 4. Wait for all to complete
      final results = await Future.wait([future1, future2, future3]);
      final s1 = results[0];
      final s2 = results[1];
      final s3 = results[2];

      // Verifications
      expect(s1.token, token1);
      expect(s2.token, token2);
      expect(s2['previous'], s1.token);
      expect(s3['previous'], s2.token);

      // Allow background queue to process (The futures above return after signing, not writing)
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify Firestore state
      final snapshot = await firestore
          .collection(issuerToken)
          .doc('statements')
          .collection('statements')
          .orderBy('time')
          .get();

      expect(snapshot.docs.length, 3);
      expect(snapshot.docs[0].id, s1.token);
      expect(snapshot.docs[1].id, s2.token);
      expect(snapshot.docs[2].id, s3.token);

      expect(snapshot.docs[1].data()['previous'], s1.token);
      expect(snapshot.docs[2].data()['previous'], s2.token);
    });

    test('Optimistic failure callback is triggered on concurrency error', () async {
      final writer2 = DirectFirestoreWriter(firestore); // Second writer sharing same DB
      final issuerToken = getToken(publicKeyJson);
      bool failureCallbackTriggered = false;

      // 1. Writer 1 writes S1 (Standard write to ensure it's in DB)
      final json1 = TestStatement.template(publicKeyJson, 'subject1');
      final s1 = await writer.push(json1, signer);

      // 2. Writer 2 tries to write S2 optimistically, *expecting* it to be the first (Genesis)
      // This mimics a device that hasn't synced yet and doesn't know about S1.
      final json2 = TestStatement.template(publicKeyJson, 'subject2');

      // We expect S2 to be returned successfully initially...
      await writer2.push(json2, signer,
          previous: const ExpectedPrevious(null), // Expecting no previous
          optimisticConcurrencyFailed: () => failureCallbackTriggered = true);

      // ... but the background write should fail.

      // Give the background queue a moment to run and fail
      await Future.delayed(const Duration(milliseconds: 100));

      expect(failureCallbackTriggered, isTrue);

      // Verify S2 is NOT in Firestore
      final snapshot = await firestore
          .collection(issuerToken)
          .doc('statements')
          .collection('statements')
          .get();

      expect(snapshot.docs.length, 1); // Only S1
      expect(snapshot.docs.first.id, s1.token);
    });
  });
}
