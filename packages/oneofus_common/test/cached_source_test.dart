import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';

/// A writer that blocks until [release] is called. Used to prove that push()
/// completes (via local inject) before the network write finishes.
class _BlockingWriter implements StatementWriter<Statement> {
  final _gate = Completer<void>();
  bool callStarted = false;

  void release() => _gate.complete();

  @override
  Future<Statement> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) async {
    callStarted = true;
    await _gate.future;
    throw StateError('_BlockingWriter: released but no real write');
  }
}

const String _kExportUrl = 'https://export.example.com';

void main() {
  late FakeFirebaseFirestore firestore;
  late OouSigner issuerSigner;
  late Map<String, dynamic> issuerKeyJson;
  late String issuerToken;
  late Map<String, dynamic> subjectAKeyJson;
  late Map<String, dynamic> subjectBKeyJson;

  setUp(() async {
    TrustStatement.init();
    firestore = FakeFirebaseFirestore();

    final issuerPair = await crypto.createKeyPair();
    issuerSigner = await OouSigner.make(issuerPair);
    issuerKeyJson = await (await issuerPair.publicKey).json;
    issuerToken = getToken(issuerKeyJson);

    final subjectAPair = await crypto.createKeyPair();
    subjectAKeyJson = await (await subjectAPair.publicKey).json;

    final subjectBPair = await crypto.createKeyPair();
    subjectBKeyJson = await (await subjectBPair.publicKey).json;

    channelFactory = ChannelFactory(FireChoice.fake);
    channelFactory.register('example.com', firestore: firestore);
  });

  tearDown(() {
    TrustStatement.clearCache();
  });

  Future<TrustStatement> push(StatementChannel<TrustStatement> channel, Map<String, dynamic> subjectKeyJson,
      {TrustVerb verb = TrustVerb.trust, required DateTime time}) async {
    final json = TrustStatement.make(issuerKeyJson, subjectKeyJson, verb);
    json['time'] = time.toUtc().toIso8601String();
    return channel.push(json, issuerSigner);
  }

  group('optimistic write semantics', () {
    test('push() completes after inject but before network write', () async {
      // This test would hang if completer.complete() were moved to after await _writer.push(),
      // because the blocking writer never resolves until release() is called.
      final writer = _BlockingWriter();
      channelFactory.testWriterOverride = writer;
      channelFactory.onWriteError = (_, __) async {}; // _BlockingWriter throws after release

      final channel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
      await channel.fetch({issuerToken: null});

      final s = await push(channel, subjectAKeyJson, time: DateTime(2024, 1, 1));

      // push() returned: inject happened (we got a valid statement back).
      // The write is still blocked — the writer's gate has not been released.
      expect(writer.callStarted, isTrue, reason: 'writer.push must have been called');
      expect(writer._gate.isCompleted, isFalse, reason: 'write must still be in-flight when push() returns');
      expect(s.iToken, equals(issuerToken));

      // The statement is already in the cache.
      final result = await channel.fetch({issuerToken: null});
      expect(result[issuerToken]!.any((stmt) => stmt.token == s.token), isTrue,
          reason: 'injected statement must be in cache while write is still in-flight');

      writer.release(); // unblock so tearDown is clean
    });

    test('push result is in cache immediately — no re-fetch needed', () async {
      final channel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
      await channel.fetch({issuerToken: null});

      final s = await push(channel, subjectAKeyJson, time: DateTime(2024, 1, 1));

      // Fetch again without clearing — must be served from cache, not from source.
      // Verify by deleting the Firestore doc and confirming fetch still returns s.
      await firestore
          .collection(issuerToken)
          .doc('statements')
          .collection('statements')
          .doc(s.token)
          .delete();

      final result = await channel.fetch({issuerToken: null});
      expect(result[issuerToken]!.any((stmt) => stmt.token == s.token), isTrue,
          reason: 'pushed statement must be served from cache, not re-fetched from source');
    });

    test('clear() drains pending writes before wiping cache', () async {
      final channel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
      await channel.fetch({issuerToken: null});

      final s = await push(channel, subjectAKeyJson, time: DateTime(2024, 1, 1));

      // clear() must drain the pending write so Firestore is current when cache is gone.
      await channel.clear();

      // Re-fetch via a fresh channel (empty cache) — must find s in Firestore.
      final freshChannel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
      final result = await freshChannel.fetch({issuerToken: null});
      expect(result[issuerToken]!.any((stmt) => stmt.token == s.token), isTrue,
          reason: 'pushed statement must be in Firestore after clear()');
    });

    test('clearCache() drains all pending writes and clears all channel caches', () async {
      final ch1 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
      final ch2 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements', distinct: false);

      await ch1.fetch({issuerToken: null});
      await ch2.fetch({issuerToken: null});

      final s = await push(ch1, subjectAKeyJson, time: DateTime(2024, 1, 1));

      await channelFactory.clearCache();

      // Verify the write was drained to Firestore before caches were wiped.
      final doc = await firestore
          .collection(issuerToken)
          .doc('statements')
          .collection('statements')
          .doc(s.token)
          .get();
      expect(doc.exists, isTrue, reason: 'write must be in Firestore after clearCache()');

      // Delete from Firestore to prove subsequent fetches go to the server (not cache).
      await doc.reference.delete();

      final result1 = await ch1.fetch({issuerToken: null});
      expect(result1[issuerToken]!.any((e) => e.token == s.token), isFalse,
          reason: 'ch1 cache cleared — re-fetch from server finds nothing');

      final result2 = await ch2.fetch({issuerToken: null});
      expect(result2[issuerToken]!.any((e) => e.token == s.token), isFalse,
          reason: 'ch2 cache cleared — re-fetch from server finds nothing');
    });

    test('inject fans out to sibling root — visible without re-fetch', () async {
      final ch1 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
      final ch2 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements',
          excludeTypes: ['org.example.something']);

      // Both roots must have the issuer in cache for fanout to inject.
      await ch1.fetch({issuerToken: null});
      await ch2.fetch({issuerToken: null});

      final s = await push(ch1, subjectAKeyJson, time: DateTime(2024, 1, 1));

      // Delete the Firestore doc to prove ch2 reads from cache (fanout), not from source.
      await firestore
          .collection(issuerToken)
          .doc('statements')
          .collection('statements')
          .doc(s.token)
          .delete();

      final result = await ch2.fetch({issuerToken: null});
      expect(result[issuerToken]!.any((stmt) => stmt.token == s.token), isTrue,
          reason: 'inject fanned out to sibling root; visible without re-fetch');
    });
  });

  group('fanout between distinct variants', () {
    test('write through distinct=true root fans out to distinct=false root', () async {
      final ch1 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements', distinct: true);
      final ch2 = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements', distinct: false);

      await ch1.fetch({issuerToken: null});
      await ch2.fetch({issuerToken: null});

      final s = await push(ch1, subjectAKeyJson, time: DateTime(2024, 1, 1));

      // Delete from Firestore to prove ch2 reads from fanout inject, not from server.
      await firestore
          .collection(issuerToken)
          .doc('statements')
          .collection('statements')
          .doc(s.token)
          .delete();

      final result = await ch2.fetch({issuerToken: null});
      expect(result[issuerToken]!.any((stmt) => stmt.token == s.token), isTrue,
          reason: 'write through distinct=true fanned out to distinct=false root');
    });
  });

  group('fake backend parity', () {
    test('excludeTypes is applied at source — not a local filter', () async {
      final fullChannel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');
      final filteredChannel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements',
          excludeTypes: [Statement.type<TrustStatement>()]);

      await fullChannel.fetch({issuerToken: null});
      await filteredChannel.fetch({issuerToken: null});

      final s = await push(fullChannel, subjectAKeyJson, time: DateTime(2024, 1, 1));

      // Clear both caches so the next fetch goes to Firestore — tests the source filter.
      await channelFactory.clearCache();

      final fullResult = await fullChannel.fetch({issuerToken: null});
      expect(fullResult[issuerToken]!.any((stmt) => stmt.token == s.token), isTrue,
          reason: 'full channel must see the statement in Firestore');

      final filteredResult = await filteredChannel.fetch({issuerToken: null});
      expect(filteredResult[issuerToken]!.any((stmt) => stmt.token == s.token), isFalse,
          reason: 'excludeTypes channel must not receive the excluded type from Firestore');
    });
  });

  group('distinct: true (default) — cache evicts superseded statements', () {
    test('push superseding statement removes the old one', () async {
      final channel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements');

      await channel.fetch({issuerToken: null});

      final t0 = DateTime(2024, 1, 1);
      final t1 = DateTime(2024, 1, 2);
      final t2 = DateTime(2024, 1, 3);

      await push(channel, subjectAKeyJson, time: t0); // trust A
      await push(channel, subjectBKeyJson, time: t1); // trust B
      await push(channel, subjectAKeyJson, verb: TrustVerb.block, time: t2); // block A — supersedes trust A

      final result = await channel.fetch({issuerToken: null});
      final statements = result[issuerToken]!;

      expect(statements.length, 2);
      expect(statements[0].verb, TrustVerb.block);
      expect(statements[0].subjectToken, getToken(subjectAKeyJson));
      expect(statements[1].verb, TrustVerb.trust);
      expect(statements[1].subjectToken, getToken(subjectBKeyJson));
    });
  });

  group('distinct: false — cache accumulates all statements', () {
    test('push superseding statement keeps the old one', () async {
      final channel = channelFactory.getChannel<TrustStatement>(_kExportUrl, 'statements', distinct: false);

      await channel.fetch({issuerToken: null});

      final t0 = DateTime(2024, 1, 1);
      final t1 = DateTime(2024, 1, 2);
      final t2 = DateTime(2024, 1, 3);

      await push(channel, subjectAKeyJson, time: t0);               // trust A
      await push(channel, subjectBKeyJson, time: t1);               // trust B
      await push(channel, subjectAKeyJson, verb: TrustVerb.block, time: t2); // block A

      final result = await channel.fetch({issuerToken: null});
      final statements = result[issuerToken]!;

      expect(statements.length, 3);
      expect(statements[0].verb, TrustVerb.block);
      expect(statements[0].subjectToken, getToken(subjectAKeyJson));
      expect(statements[1].verb, TrustVerb.trust);
      expect(statements[1].subjectToken, getToken(subjectBKeyJson));
      expect(statements[2].verb, TrustVerb.trust);
      expect(statements[2].subjectToken, getToken(subjectAKeyJson));
    });
  });
}
