import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';

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
