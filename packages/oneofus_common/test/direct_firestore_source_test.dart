import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';

void main() {
  group('DirectFirestoreSource — multi-stream', () {
    late FakeFirebaseFirestore firestore;
    late OouSigner signer;
    late Map<String, dynamic> publicKeyJson;
    late String issuerToken;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      TrustStatement.init();

      final keyPair = await crypto.createKeyPair();
      signer = await OouSigner.make(keyPair);
      publicKeyJson = await (await keyPair.publicKey).json;
      issuerToken = getToken(publicKeyJson);
    });

    Future<TrustStatement> writeToStream(String streamId, String subject,
        {String? previousToken, DateTime? time}) async {
      final writer = DirectFirestoreWriter<TrustStatement>(firestore, streamId: streamId);
      final json = {
        'statement': Statement.type<TrustStatement>(),
        'I': publicKeyJson,
        'time': (time ?? DateTime.now()).toUtc().toIso8601String(),
        'trust': {'moniker': subject},
      };
      // Note: do NOT set json['previous'] — the writer asserts it's absent and sets it itself.
      return writer.push(json, signer, previous: ExpectedPrevious(previousToken));
    }

    Future<List<TrustStatement>> fetchFromStream(String streamId,
        {String? revokeAt, List<String>? allStreams}) async {
      final source = DirectFirestoreSource<TrustStatement>(
        firestore,
        streamId: streamId,
        allStreams: allStreams ?? [streamId],
        skipVerify: null,
      );
      final result = await source.fetch({issuerToken: revokeAt});
      return result[issuerToken] ?? [];
    }

    // Test 1: independent writes
    test('writes to separate streams are independent', () async {
      await writeToStream('statements', 'Alice');
      await writeToStream('dis', 'Bob');

      final fromStatements = await fetchFromStream('statements');
      final fromDis = await fetchFromStream('dis');

      expect(fromStatements.length, 1);
      expect(fromStatements.first['trust']['moniker'], 'Alice');
      expect(fromDis.length, 1);
      expect(fromDis.first['trust']['moniker'], 'Bob');
    });

    // Test 2: cross-stream isolation
    test('statements stream not visible in dis stream', () async {
      await writeToStream('statements', 'Alice');
      final fromDis = await fetchFromStream('dis');
      expect(fromDis, isEmpty);
    });

    // Test 3: revokeAt within the same stream
    test('revokeAt filters within same stream', () async {
      final t0 = DateTime.now();
      final s1 = await writeToStream('statements', 'Alice', time: t0);
      await writeToStream('statements', 'Bob',
          previousToken: s1.token, time: t0.add(const Duration(seconds: 1)));

      final result = await fetchFromStream('statements',
          revokeAt: s1.token, allStreams: ['statements']);

      expect(result.length, 1);
      expect(result.first['trust']['moniker'], 'Alice');
    });

    // Test 4: revokeAt token in a different stream
    test('revokeAt token from dis stream filters statements stream', () async {
      final t0 = DateTime.now();
      final s1 = await writeToStream('statements', 'Alice', time: t0);
      final d1 = await writeToStream('dis', 'Dismiss',
          time: t0.add(const Duration(seconds: 1)));
      await writeToStream('statements', 'Bob',
          previousToken: s1.token, time: t0.add(const Duration(seconds: 2)));

      // revokeAt = d1 (in dis stream), fetching statements stream
      final result = await fetchFromStream('statements',
          revokeAt: d1.token, allStreams: ['statements', 'dis']);

      // Only Alice is before d1's time; Bob is after
      expect(result.length, 1);
      expect(result.first['trust']['moniker'], 'Alice');
    });

    // Test 5: revokeAt token not found in any stream → []
    test('unknown revokeAt token revokes since genesis', () async {
      await writeToStream('statements', 'Alice');

      final result = await fetchFromStream('statements',
          revokeAt: 'nonexistent_token_abc123',
          allStreams: ['statements', 'dis']);

      expect(result, isEmpty);
    });

    // Test 6: "<since always>" sentinel → []
    test('"<since always>" sentinel revokes since genesis', () async {
      await writeToStream('statements', 'Alice');

      final result = await fetchFromStream('statements',
          revokeAt: '<since always>', allStreams: ['statements', 'dis']);

      expect(result, isEmpty);
    });

    // Test 7: backward compat — no streamId defaults to 'statements'
    test('default streamId reads from statements stream', () async {
      await writeToStream('statements', 'Alice');

      final source = DirectFirestoreSource<TrustStatement>(firestore);
      final result = await source.fetch({issuerToken: null});

      expect(result[issuerToken]?.length, 1);
    });
  });
}
