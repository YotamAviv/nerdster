import 'package:flutter/foundation.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/demotest/cases/verification.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/config.dart';

/// Evaluates the basic graph verification logic across the core trust
/// permutations securely decoupled from any UI binding context.
Future<void> runCloudSourceVerification() async {
  debugPrint("Starting Cloud Source Verification...");
  TrustStatement.init();
  
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
        
        final source = CloudFunctionsSource<TrustStatement>(
          baseUrl: url,
          paramsOverride: p.params,
          verifier: OouVerifier(),
        );

        await basicScenario(source: source, description: '${p.name} (skipVerify: $skipVerify)');
        debugPrint('Permutation ${p.name} Verified!');
      }
    }
    
    debugPrint('PASS');
  } catch (e, stack) {
    debugPrint('ERROR: $e');
    debugPrint('STACK: $stack');
    debugPrint('FAIL');
  }
}
