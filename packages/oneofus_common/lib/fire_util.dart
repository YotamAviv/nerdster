import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/clock.dart';
import 'jsonish.dart';

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
  try {
    QuerySnapshot<Json> snapshots =
        await fireStatements.orderBy('time', descending: true).limit(2).get();
    for (var docSnapshot in snapshots.docs) {
      var data = docSnapshot.data();
      DateTime time = parseIso(data['time']);
      out.add(time);
    }
  } catch (e) {
    out.add(e);
  }
  print(out);
  return out;
}
