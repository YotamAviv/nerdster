import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/fire_factory.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/trust_statement.dart';

class SimpsonsDataHelper {
  static Future<void> populate(
      FakeFirebaseFirestore nerdsterFire, FakeFirebaseFirestore oneofusFire) async {
    // 1. Register the fake firestores so DemoKey's push calls go there.
    FireFactory.register(kNerdsterDomain, nerdsterFire, null);
    FireFactory.register(kOneofusDomain, oneofusFire, null);

    // 2. Reset DemoKey state to ensure fresh keys if needed
    DemoKey.reset();

    // 3. Run the simpsons generator.
    // This will call Fetcher.push which will write to the registered fake firestores.
    await simpsons();
  }
}
