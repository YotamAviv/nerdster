import 'package:flutter/foundation.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/demotest/cases/concurrent_write_scenario.dart';
import 'package:nerdster/demotest/cases/time_ordering_scenario.dart';
import 'package:nerdster/demotest/cases/verification.dart';
import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';

// Passed to channelFactory.rawSourceForTesting() as proof of caller identity.
// Any production caller would have to import this dev file to obtain it — that
// import is the intended barrier.
final Object _testOnlyToken = Object();

/// Evaluates the basic graph verification logic across the core trust
/// permutations securely decoupled from any UI binding context.
Future<void> runCloudSourceVerification() async {
  debugPrint("Starting Cloud Source Verification...");
  TrustStatement.init();
  ContentStatement.init();
  DismissStatement.init();

  final url = FirebaseConfig.resolveUrl('https://export.one-of-us.net');

  final permutations = [
    (name: 'Default', params: null),
    (name: 'No Optimization', params: {'omit': <String>[]}),
    (name: 'Full Optimization', params: {'omit': ['statement', 'I']}),
    (name: 'Omit Statement Only', params: {'omit': ['statement']}),
    (name: 'Omit I Only', params: {'omit': ['I']}),
    (name: 'Check Previous True', params: {'checkPrevious': 'true'}),
    (name: 'Check Previous False', params: {'checkPrevious': 'false'}),
  ];

  try {
    for (final skipVerify in [true, false]) {
      Setting.get<bool>(SettingType.skipVerify).value = skipVerify;
      debugPrint('\n=== Testing with skipVerify: $skipVerify ===');

      for (final p in permutations) {
        debugPrint('--- Testing Permutation: ${p.name} (skipVerify: $skipVerify) ---');

        final source = channelFactory.rawSourceForTesting<TrustStatement>(
          _testOnlyToken,
          baseUrl: url,
          statementType: Statement.type<TrustStatement>(),
          paramsOverride: p.params,
        );

        await basicScenario(source: source, description: '${p.name} (skipVerify: $skipVerify)');
        debugPrint('Permutation ${p.name} Verified!');
      }
    }

    debugPrint('--- Testing Concurrent Write Scenario ---');
    await concurrentWriteScenario();
    debugPrint('Concurrent Write Scenario Verified!');

    debugPrint('--- Testing Time Ordering Scenario ---');
    await timeOrderingScenario();
    debugPrint('Time Ordering Scenario Verified!');

    debugPrint('PASS');
  } catch (e, stack) {
    debugPrint('ERROR: $e');
    debugPrint('STACK: $stack');
    debugPrint('FAIL');
  }
}
