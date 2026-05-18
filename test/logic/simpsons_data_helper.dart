import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';

class SimpsonsDataHelper {
  static Future<void> populate(
      FakeFirebaseFirestore nerdsterFire, FakeFirebaseFirestore oneofusFire) async {
    channelFactory = ChannelFactory(FireChoice.fake);
    channelFactory.register('nerdster.org', firestore: nerdsterFire);
    channelFactory.register('one-of-us.net', firestore: oneofusFire);

    DemoKey.reset();

    await simpsons();
  }
}
