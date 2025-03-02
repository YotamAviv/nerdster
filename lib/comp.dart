import 'package:flutter/foundation.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/value_waiter.dart';

///
/// Exceptions and semantics of 'ready':
/// 
/// Should a single exception be thrown at all those waiting?
/// - they should stop waiting, right?
/// - the broken Comp shouldn't be "ready", right?
/// - that'd mean throwing the same exception at every thing waiting. 
/// I don't like it
/// 
/// My reasoning is as follows
/// - No waiter should be left waiting
/// - The Comp that threw the exception should not be 'ready'
/// - At least one waiter should get the source exception. 
/// I remain conflicted about throwing the same exception at multiple waiters, but that's what I'm currently doing.
///
/// I'm not actually trying to build a generic Comp framework; I just need to satisfy my own requirements.
/// In case of an exception, I really just want to show it to the user. 
/// I'm not really sure beyond that.. I'm okay with crashing.
///
/// TEST: My tests don't test this effectively, see documented bug in trustBlockConflict, 
/// (the bug's been fixed, but the tests have not been updated).
abstract mixin class Comp {
  final List<Comp> supporters = <Comp>[];
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);
  bool _processing = false;
  bool _invalidProcess = false;
  Object? _exception;

  static void dumpComps() {
    for (Comp comp in [oneofusNet, oneofusEquiv, followNet, keyLabels, contentBase]) {
      comp.compDump();
    }
  }

  void compDump() {
    print('$this ready:$ready processing:$_processing invalidProcess:$_invalidProcess');
  }

  // Would be nice to have a common listen method and automatically listen to supporters,
  // but that'd require ChangeNotifier mixin both for addListener and notifyListeners.
  void addSupporter(Comp supporter) => supporters.add(supporter);

  Future<void> process();

  bool get ready => _ready.value;

  bool get invalidProcess => _invalidProcess;

  setDirty() {
    // Ignoring setDirty() if we're already dirty breaks things; maybe the gratuitous notification
    // helps move thigs along.
    // So DON'T do this: if (!ready) return;
    if (_processing) {
      assert(!ready);
      _invalidProcess = true;
      // print('_invalidProcess = true;');
    }
    _ready.value = false;
  }

  static bool compsReady(Iterable<Comp> comps) => comps.where((s) => !s.ready).isEmpty;

  bool get supportersReady => compsReady(supporters);

  // I have (or had) issues (consider the bug identified in trustBlockConflict.)
  // I don't know if this is better, but it feels more organized.
  void thowIfSupportersNotReady() {
    if (!supportersReady) throw Exception('!supportersReady');
  }

  static Future<void> waitOnComps(Iterable<Comp> comps) async {
    while (true) {
      Iterable<Future> futures = comps.map((c) => c.waitUntilReady());
      await Future.wait(futures);
      if (compsReady(comps)) break;
    }
    assert(compsReady(comps));
  }

  Future<void> waitOnSupporters() async {
    await waitOnComps(supporters);
  }

  Future<void> waitUntilReady() async {
    while (!_ready.value && !_processing) {
      await waitOnSupporters();
      if (_processing || _ready.value) break;
      try {
        _invalidProcess = false;
        _exception = null;
        _processing = true;
        await process();
        _processing = false;

        if (_invalidProcess) {
          _invalidProcess = false;
          assert(!ready);
          continue;
        }

        _ready.value = true;
      } catch (e) {
        _exception = e;
        _processing = false;
        _ready.value = true; // necessary to end the waiting below
        _ready.value = false; // single thread, no "critical section" required.
        rethrow;
      }
      assert(ready);
    }
    // calling process has been initiated; just wait..
    await ValueWaiter(_ready, true).untilReady();
    if (b(_exception)) {
      _ready.value = false; // See docs at top about semantics of 'ready'.
      throw _exception!;
    }
  }
}
