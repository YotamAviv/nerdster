import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/demotest/cases/follow_not_in_network.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  test('Follow Not In Network Scenario', () async {
    await followNotInNetwork();
  });
}
