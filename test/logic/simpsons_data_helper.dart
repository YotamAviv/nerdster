import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/trust_statement.dart';

class SimpsonsDataHelper {
  static Future<void> populate(
      FakeFirebaseFirestore nerdsterFire, FakeFirebaseFirestore oneofusFire) async {
    channelFactory = ChannelFactory(FireChoice.fake);
    channelFactory.register(kNerdsterDomain,
        exportUrl: '', functionsUrl: '', firestore: nerdsterFire);
    channelFactory.register(kOneofusDomain,
        exportUrl: '', functionsUrl: '', firestore: oneofusFire);

    DemoKey.reset();

    await simpsons();
  }
}
