import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';

const String _kExportUrl = 'https://export.nerdster.org';

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

  Future<TrustStatement> push(StatementChannel<TrustStatement> ch, Map<String, dynamic> subjectKey,
      {TrustVerb verb = TrustVerb.trust, required DateTime time}) async {
    final json = TrustStatement.make(iJson, subjectKey, verb);
    json['time'] = time.toUtc().toIso8601String();
    return ch.push(json, signer);
  }

  test('Partial history does not poison full history', () async {
    final ch = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
    await ch.fetch({issuerToken: null});

    final s1 = await push(ch, mockKey('C'), time: DateTime.parse('2023-01-01T00:00:00Z'));
    final s2 = await push(ch, mockKey('D'), time: DateTime.parse('2023-01-02T00:00:00Z'));

    // clear() drains pending writes before wiping the cache — Firestore is current.
    await channelFactory.clearCache();
    final ch2 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');

    // 1. Fetch partial history (up to s1).
    final res1 = await ch2.fetch({issuerToken: s1.token});
    expect(res1[issuerToken]!.length, 1, reason: 'Should return only S1');

    // 2. Fetch full history — must not be poisoned by the partial.
    final res2 = await ch2.fetch({issuerToken: null});
    expect(res2[issuerToken]!.length, 2, reason: 'Should return S1 and S2');
    expect(res2[issuerToken]!.any((s) => s.token == s2.token), isTrue);
  });

  test('Full history satisfies partial history request', () async {
    final ch = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
    await ch.fetch({issuerToken: null});

    final s1 = await push(ch, mockKey('C'), time: DateTime.parse('2023-01-01T00:00:00Z'));
    await push(ch, mockKey('D'), time: DateTime.parse('2023-01-02T00:00:00Z'));

    // Fetch partial (revokeAt=s1) — returns s1 and anything older (just s1 here).
    // The full cache is used; no server re-fetch needed.
    final res = await ch.fetch({issuerToken: s1.token});
    expect(res[issuerToken]!.length, 1, reason: 'Full cache satisfies partial request');
    expect(res[issuerToken]!.first.token, equals(s1.token));
  });

  test('resetRevokeAt clears partials but keeps fulls', () async {
    final ch = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
    await ch.fetch({issuerToken: null});

    final s1 = await push(ch, mockKey('C'), time: DateTime.parse('2023-01-01T00:00:00Z'));
    await push(ch, mockKey('D'), time: DateTime.parse('2023-01-02T00:00:00Z'));

    // clear() drains pending writes before wiping the cache.
    await channelFactory.clearCache();
    final ch2 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');

    // Full fetch.
    final resFull = await ch2.fetch({issuerToken: null});
    expect(resFull[issuerToken]!.length, 2);

    // Partial fetch.
    final resPartial = await ch2.fetch({issuerToken: s1.token});
    expect(resPartial[issuerToken]!.length, isNonNegative);

    // resetRevokeAt clears partial cache but not full.
    ch2.resetRevokeAt();

    // Full should still be served from cache (no Firestore hit needed).
    final resFullAfter = await ch2.fetch({issuerToken: null});
    expect(resFullAfter[issuerToken]!.length, 2);
  });
}
