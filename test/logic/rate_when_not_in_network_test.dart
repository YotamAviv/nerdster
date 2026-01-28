import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/demotest/cases/rate_when_not_in_network.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  test('Rate When Not In Network Scenario', () async {
    await rateWhenNotInNetwork();
  });
}
