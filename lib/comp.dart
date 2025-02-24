import 'package:flutter/foundation.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/value_waiter.dart';

///
///
abstract mixin class Comp {
  final List<Comp> supporters = <Comp>[];
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);
  int _waitingCount = 0;
  bool _processing = false;
  bool _invalidProcess = false;
  Object? _exception;

  // Would be nice to have a common listen method and automatically listen to supporters, 
  // but that'd require ChangeNotifier mixin both for addListener and notifyListeners.
  void addSupporter(Comp supporter) {
    supporters.add(supporter);
  }

  Future<void> process();

  bool get ready => _ready.value;

  bool get invalidProcess => _invalidProcess;

  setDirty() {
    // I don't understand this completely, but ignoring setDirty if we're dirty breaks things.
    // Don't: if (!ready) { .. }
    if (_processing) {
      assert(!ready);
      _invalidProcess = true;
      print('_invalidProcess = true;');
    }
    _ready.value = false;
  }

  static bool compsReady(Iterable<Comp> comps) {
    return comps.where((s) => !s.ready).isEmpty;
  }

  bool get supportersReady => compsReady(supporters);

  static Future<void> waitOnComps(Iterable<Comp> comps) async {
    while (true) {
      Iterable<Future> futures = comps.map((c) => c.waitUntilReady());
      await Future.wait(futures);
      if (compsReady(comps)) {
        break;
      }
      // print('looping: !ready: ${comps.where((s) => !s.ready).map((c) => c.runtimeType)}');
      // for (Comp comp in comps.where((s) => !s.ready)) {
      //   print('!ready comp:${comp.runtimeType}, _waitingCount:${comp._waitingCount}');
      // }
    }
    assert(compsReady(comps));
  }

  Future<void> waitOnSupporters() async {
    await waitOnComps(supporters);
  }

  Future<void> waitUntilReady() async {
    try {
      _waitingCount++;
      // I'm new to this, but I'm learning.
      // In particular it appears that anything goes during async gaps; for example, 
      // I might wait using ValueNotifier for ready and immediately after not be ready.
      // And so, there are while loops where I though ifs would be sufficient.
      while (!ready) {
        if (_waitingCount == 1) {
          try {
            while (!ready) {
              await waitOnSupporters();

              _processing = true;
              _invalidProcess = false;
              _exception = null;
              await process();
              _processing = false;

              if (_invalidProcess) {
                _invalidProcess = false;
                assert(!ready);
                continue;
              }

              assert(supportersReady); // QUESTIONABLE
              _ready.value = true;
            }
          } catch (e) {
            _exception = e;
            print('Rethrowing: $_exception');
            rethrow;
          } finally {
            _processing = false;
            _ready.value = true;
          }
          assert(ready);
        } else {
          // calling process has been initiated; just wait..
          await ValueWaiter(_ready, true).untilReady();
          // Note: This fires: assert(ready || b(_exception));
          if (b(_exception)) {
            // print('Throwing _exception: $_exception');
            print('Throwing _exception: $_exception'); // TEMP:
            throw _exception!;
          }
        }
      }
      assert(ready);
    } finally {
      _waitingCount--;
    }
  }
}
