import 'dart:collection';

import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';

// Goal: Test every kind of rejection / notification
// - Attempt to block your key.
// - Attempt to replace your key.
// - Attempt to block trusted key.
// - Attempt to trust blocked key.
// - Attempt to replace a replaced key.
// - DEFER: Attempt to replace a blocked key.
// - Web-of-trust key equivalence rejected: Replaced key not in network. ('simpsons, degrees=2')
// - TO-DO: Web-of-trust key equivalence rejected: Replacing key not in network.
//   I don't think this can happen, not sure.. CONSIDER
// - TO-DO: Web-of-trust key equivalence rejected: Equivalent key already replaced.
//   I don't think this can happen, not sure.. CONSIDER


class Notifications implements Corruptor {
  static final Notifications singleton = Notifications._internal();
  factory Notifications() => singleton;
  Notifications._internal();

  // Where/when to call this isn't clear, probably OneofusNet.process, some tests, too. 
  void clear() {
    _rejected.clear();
    _warned.clear();
    _corrupted.clear();
  }

  final LinkedHashMap<String, String> _rejected = LinkedHashMap<String, String>();
  Map<String, String> get rejected => UnmodifiableMapView(_rejected);
  void reject(String token, String problem) {
    assert(Jsonish.find(token) != null);
    _rejected[token] = problem;
  }

  final LinkedHashMap<String, String> _warned = LinkedHashMap<String, String>();
  Map<String, String> get warned => UnmodifiableMapView(_warned);
  void warn(String token, String problem) {
    assert(Jsonish.find(token) != null);
    _warned[token] = problem;
  }

  final LinkedHashMap<String, String> _corrupted = LinkedHashMap<String, String>();
  Map<String, String> get corrupted => UnmodifiableMapView(_corrupted);
  @override
  void corrupt(String token, String error) {
    // TEMP: Might be null when I'm loading with ?oneofus=token. // assert(Jsonish.find(token) != null);
    // BUG: I think that if ?oneofus=token leads to an error, then we never even see it because maybe nothing fires a listen().
    _corrupted[token] = error;
  }
}
