import 'package:cloud_firestore/cloud_firestore.dart';
import 'jsonish.dart';

import 'util.dart';

Future<void> checkWrite(String collection, FirebaseFirestore fire) async {
  final fireStatements = fire.collection(collection);
  final now = DateTime.now();
  final Json json = {'time': formatUiDatetime(now)};
  await fireStatements.doc('id-${formatIso(now)}').set(json).then(
      (doc) => print("Wrote to:$collection: $json"),
      onError: (e) => print("Error: $e"));
}

Future<void> checkRead(String collection, FirebaseFirestore fire) async {
  final CollectionReference<Json> fireStatements = fire.collection(collection);
  QuerySnapshot<Map<String, dynamic>> snapshots = await fireStatements
      .limit(2)
      .get()
      .catchError((e) => print("Error completing: $e"));
  for (var docSnapshot in snapshots.docs) {
    var data = docSnapshot.data();
    print('Read from:$collection: $data');
  }
}

/// write then read and report success
Future<bool> fireCheck(FirebaseFirestore fire) async {
  throw ('unimplemented');
}
