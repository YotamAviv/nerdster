import 'package:cloud_firestore/cloud_firestore.dart';

/// I haven't found the technology to make unit tests work against the emulator (or live).
class FireFactory {
  static final Map<String, FirebaseFirestore> domain2fire = {};

  static registerFire(String domain, FirebaseFirestore fire) {
    domain2fire[domain] = fire;
  }

  static FirebaseFirestore find(String domain) {
    return domain2fire[domain]!;
  }
}