import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/demotest/cases/predecessor_delegate.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  test('Predecessor delegate content is visible from peer PoV', () async {
    await predecessorDelegate();
  });
}
