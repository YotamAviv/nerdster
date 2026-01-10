import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/demotest/cases/notifications_gallery.dart';

void main() {
  setUp(() async {
    setUpTestRegistry();
  });

  test('Gallery of Notifications', () async {
    await notificationsGallery();
  });
}
