import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// I haven't found the technology to make unit tests work against the emulator (or live).
class FireFactory {
  static final Map<String, (FirebaseFirestore, FirebaseFunctions?)> domain2fire = {};

  static register(String domain, FirebaseFirestore fire, FirebaseFunctions? functions) {
    domain2fire[domain] = (fire, functions);
  }

  static FirebaseFirestore find(String domain) {
    return domain2fire[domain]!.$1;
  }

  static FirebaseFunctions? findFunctions(String domain) {
    return domain2fire[domain]!.$2;
  }

  static Future<void> clearPersistence() async {
    for ((FirebaseFirestore, FirebaseFunctions?) pair in domain2fire.values) {
      await pair.$1.clearPersistence();
    }
  }
}
