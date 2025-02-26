import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

class CorruptionCheck {
  static Future<void> make() async {
    await Comp.waitOnComps([oneofusNet, keyLabels]);

    for (String oneofus in oneofusNet.network.keys) {
      Fetcher fetcher = Fetcher(oneofus, kOneofusDomain);
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
            String error = '${keyLabels.labelKey(oneofus)} $time !notary: $token != $previousToken';
            print(error);
          }

          if (!time.isBefore(previousTime)) {
            String error = '${keyLabels.labelKey(oneofus)} $time !desc: $time >= $previousTime';
            print(error);
          }
        }

        previousToken = s['previous'];
        previousTime = time;
      }
    }
    print('out');
  }
}
