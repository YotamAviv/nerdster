import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

// CONSIDER: TEST: Say, on simpsons for exmaple
class CorruptionCheck {
  static final OouVerifier _oouVerifier = OouVerifier();
  static Future<void> make() async {
    await Comp.waitOnComps([oneofusNet, oneofusLabels]);

    print('oneofus');
    for (String oneofus in oneofusNet.network.keys) {
      Fetcher fetcher = Fetcher(oneofus, kOneofusDomain);
      assert(fetcher.token == oneofus);
      await check(fetcher);
    }

    print('delegates');
    followNet.fcontext = kOneofusContext;
    await Comp.waitOnComps([followNet, keyLabels]);
    for (String delegate in followNet.delegate2oneofus.keys) {
      Fetcher fetcher = Fetcher(delegate, kNerdsterDomain);
      assert(fetcher.token == delegate);
      await check(fetcher);
    }

    print('out');
  }

  static Future<void> check(Fetcher fetcher) async {
    String? previousToken;
    DateTime? previousTime;
    for (Statement s in await fetcher.fetchAllNoVerify()) {
      String token = s.token;
      DateTime time = s.time;

      // Validate notary chain, decending order
      if (previousTime == null) {
        // no check
      } else {
        if (s.token != previousToken) {
          String error =
              '${keyLabels.labelKey(fetcher.token)} $time !notary: $token != $previousToken';
          print(error);
        }
        if (!time.isBefore(previousTime)) {
          String error = '${keyLabels.labelKey(fetcher.token)} $time !desc: $time >= $previousTime';
          print(error);
        }
      }
      previousToken = s['previous'];
      previousTime = time;

      // Validate signature
      final Json ordered = Jsonish.order(s.json);
      final String ppJson = encoder.convert(ordered);
      final String token2 = sha1.convert(utf8.encode(ppJson)).toString();
      assert(token == token2, 'computed by Jsonish the same way');
      String signature = ordered['signature']!;
      var orderedWithoutSig = Map.from(ordered)..remove('signature');
      String ppJsonWithoutSig = encoder.convert(orderedWithoutSig);
      bool verified = await _oouVerifier.verify(ordered, ppJsonWithoutSig, signature);
      if (!verified) {
        String error = '!verified';
        print(error);
      }

      // Validate verb
      // If Statement (s) succeeded so far, then there's nothing to check regarding
      if (fetcher.domain == kOneofusDomain) {
        TrustStatement s2 = s as TrustStatement;
        // print(s2.verb);
      } else if (fetcher.domain == kNerdsterDomain) {
        ContentStatement s2 = s as ContentStatement;
        // print(s2.verb);
      } else {
        assert(false, fetcher.domain);
      }

      print(',');
    }
    print('.');
  }
}
