import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/demotest/cases/v2_verification.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  test('Basic Scenario: Marge sees Bart and Lisa', () async {
    await basicScenario();
  });
}
