import 'package:cloud_firestore/cloud_firestore.dart';
import 'jsonish.dart';

import 'util.dart';

Future<List> checkWrite(FirebaseFirestore fire, String collection) async {
  List out = [];
  final CollectionReference<Json> fireStatements = fire.collection(collection);
  final now = DateTime.now();
  final Json json = {'time': formatIso(now)};
  await fireStatements.doc('id-${formatIso(now)}').set(json).then((doc) => out.add(now),
      onError: (e) {
    out.add(e);
  });
  print(out);
  return out;
}

Future<List> checkRead(FirebaseFirestore fire, String collection) async {
  List out = [];
  final CollectionReference<Json> fireStatements = fire.collection(collection);
  QuerySnapshot<Map<String, dynamic>> snapshots =
      await fireStatements.orderBy('time', descending: true).limit(2).get().catchError((e) {
    out.add(e);
  });
  for (var docSnapshot in snapshots.docs) {
    var data = docSnapshot.data();
    DateTime time = parseIso(data['time']);
    out.add(time);
  }
  print(out);
  return out;
}
