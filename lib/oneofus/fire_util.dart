import 'package:cloud_firestore/cloud_firestore.dart';
import 'jsonish.dart';

import 'util.dart';

Future<List<String>> checkWrite(FirebaseFirestore fire, String collection) async {
  List<String> out = <String>[];
  final CollectionReference<Json> fireStatements = fire.collection(collection);
  final now = DateTime.now();
  final Json json = {'isoDatetime': formatIso(now)};
  await fireStatements
      .doc('id-${formatIso(now)}')
      .set(json)
      .then((doc) => out.add('Wrote to:$collection: $json'), onError: (e) {
    out.add('checkWrite error: $e');
  });
  print(out);
  return out;
}

Future<List<String>> checkRead(FirebaseFirestore fire, String collection) async {
  List<String> out = <String>[];
  final CollectionReference<Json> fireStatements = fire.collection(collection);
  QuerySnapshot<Map<String, dynamic>> snapshots =
  await fireStatements.orderBy('isoDatetime', descending: true).limit(2).get().catchError((e) {
    out.add('checkRead error: $e');
  });
  for (var docSnapshot in snapshots.docs) {
    var data = docSnapshot.data();
    out.add('Read from:$collection: $data');
  }
  print(out);
  return out;
}
