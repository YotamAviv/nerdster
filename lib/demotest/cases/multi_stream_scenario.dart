import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/oou_verifier.dart';

/// Verifies multi-stream support in the cloud export function:
/// 1. subcollection param: writes land in the correct stream
/// 2. cross-stream revokeAt: server resolves revokeAt token across streams
Future<void> multiStreamScenario({required String url}) async {
  DemoKey.reset();

  final alice = await DemoIdentityKey.create('alice-ms');
  final bob = await DemoIdentityKey.create('bob-ms');
  final charlie = await DemoIdentityKey.create('charlie-ms');
  final dave = await DemoIdentityKey.create('dave-ms');

  // S1: alice trusts bob → statements stream (time T1)
  final s1 = await alice.trust(bob, moniker: 'bob');
  await Future.delayed(const Duration(milliseconds: 20));

  // D1: alice trusts charlie → dis stream (time T2, T2 > T1)
  final disWriter = DirectFirestoreWriter<TrustStatement>(
    channelFactory.firestoreFor(kOneofusDomain)!,
    streamId: 'dis',
  );
  final d1Json = TrustStatement.make(
    await alice.publicKey.json,
    await charlie.publicKey.json,
    TrustVerb.trust,
    moniker: 'charlie',
  );
  final signer = await OouSigner.make(alice.keyPair);
  final d1 = await disWriter.push(d1Json, signer);
  await Future.delayed(const Duration(milliseconds: 20));

  // S2: alice trusts dave → statements stream (time T3, T3 > T2)
  await alice.trust(dave, moniker: 'dave');

  // Test A: fetch statements stream (no revokeAt) → S1 + S2
  final sourceStatements = CloudFunctionsSource<TrustStatement>(
    baseUrl: url,
    streamId: 'statements',
    allStreams: ['statements', 'dis'],
    verifier: OouVerifier(),
  );
  final resultA = await sourceStatements.fetch({alice.token: null});
  final statementsA = resultA[alice.token] ?? [];
  check(statementsA.length == 2,
      'multiStream A: statements stream should have 2 results, got ${statementsA.length}');

  // Test B: fetch dis stream (no revokeAt) → D1
  final sourceDis = CloudFunctionsSource<TrustStatement>(
    baseUrl: url,
    streamId: 'dis',
    allStreams: ['statements', 'dis'],
    verifier: OouVerifier(),
  );
  final resultB = await sourceDis.fetch({alice.token: null});
  final statementsB = resultB[alice.token] ?? [];
  check(statementsB.length == 1,
      'multiStream B: dis stream should have 1 result, got ${statementsB.length}');

  // Test C: cross-stream revokeAt — revokeAt=D1 (in dis), fetch statements → only S1
  // Server must find D1 in dis stream, use its time T2, filter out S2 (T3 > T2)
  final sourceRevokeAt = CloudFunctionsSource<TrustStatement>(
    baseUrl: url,
    streamId: 'statements',
    allStreams: ['statements', 'dis'],
    verifier: OouVerifier(),
  );
  final resultC = await sourceRevokeAt.fetch({alice.token: d1.token});
  final statementsC = resultC[alice.token] ?? [];
  check(statementsC.length == 1,
      'multiStream C: revokeAt from dis stream should yield 1 statement, got ${statementsC.length}');
  check(statementsC.first.token == s1.token,
      'multiStream C: only S1 (bob) should survive, got ${statementsC.first.token}');
}
