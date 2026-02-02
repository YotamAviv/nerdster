import 'package:flutter_test/flutter_test.dart';
import 'package:oneofus_common/trust_statement.dart';

var statementJson = {
  "statement": "net.one-of-us",
  "time": "2024-05-01T07:10:00.000Z",
  "I": {"crv": "Ed25519", "kty": "OKP", "x": "UYB3b66cl4JFkKy3REWI2TvBNc6q2z9-ghrFoneM9eg"},
  "trust": {"crv": "Ed25519", "kty": "OKP", "x": "aPRsLNIDmJeXOjpo30dFTsz3FiJAsLVxnqF6G1V9LQw"},
  "with": {"moniker": "key2"}
};

void main() {
  setUpAll(() {
    TrustStatement.init();
  });

  test('some identity==, mostly Jsonish', () async {
    Jsonish.wipeCache();
    Jsonish jsonish = Jsonish(statementJson);
    TrustStatement stat1 = TrustStatement(jsonish);
    TrustStatement stat2 = TrustStatement(jsonish);
    expect(stat1 == stat2, true);
    expect(stat1.token == jsonish.token, true);

    // Statement instances can be constructed from a Jsonish, which helps with identity==.
    // Or they can use the static make method, which returns Json, not a Statement
    // instance, and so we still have ==.
    Json i = Jsonish.find(stat1.iToken)!.json;
    Json him = Jsonish.find(stat1.subjectToken)!.json;
    Json json3 = TrustStatement.make(i, him, TrustVerb.trust, moniker: stat1.moniker);
    json3['time'] = stat1.time.toUtc().toIso8601String(); // fudge the time
    Jsonish jsonish3 = Jsonish(json3);
    TrustStatement stat3 = TrustStatement(jsonish3);
    expect(stat1 == stat3, true);
  });
}
