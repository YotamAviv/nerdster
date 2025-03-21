import 'dart:async';

import 'package:flutter/foundation.dart';

/// 1) Instrumentation to investigate what's slow. 
/// Fire fetching is what's slow, and the performance seems to vary depending on cloud functions
/// number of calls, ?after=<after>, ?distinct, etc...
/// (I don't think computing takes time, just loading)
///
/// 2) A fancy progress bar
/// We don't know how long it will take, and so it won't be 0-100%.
/// Would be nice:
/// - Allow skipping/cancelling whatever it's doing:
///   - while loading network, see how many degrees and which tokens, cancel any time
///   - while loading content, see how many oneofus and delegates have been fetched, cancel any time
///
/// Related: Network limits
/// - Possibilities: 
///   - 'limit': say, 100, rate statements per network member
///   - Cloud functions could support stuff like including all ['censor', 'relate', 'equate']
///   - 'recent'
///   - 'after' (for refresh only)
///   - 'contentType'  (books, movies, ..)
/// * We should always load all of the signed-in user's statements (for prefilling the dialog, for example)


/// Intervals (OneofusNet, FollowNet), activities (Fire fetch, verify)
/// total time could be broken up meaningfully
/// When does total time start or end?
        //  try {
        //   Measure.reset();
        //   _CenterDropdown.measure.start();

        //   signInState.center = .. // or whatever

        //   await Comp.waitOnComps([contentBase, keyLabels]);
        // } catch (e, stackTrace) {
        //   await alertException(context, e, stackTrace: stackTrace);
        // } finally {
        //   _CenterDropdown.measure.stop();
        //   Measure.dump();
        // }
 

/// Probably not: Stack push / pop?
/// I believe that only Fire fetching is slow.
/// Would be nice to know more about that. Oneofus costs, FollowNet costs, per user or token costs..
/// Future work on fetch?after=<time> or fetch?limit=<limit> would be affected by the ability to measure.
/// 
/// Both of these:
/// - Data structure output (probably JSON)
/// - Progress dialog
/// 

/// DEFER: Look for someone else's one of these instead of working on this one more.
/// DEFER: Consider doing something smart when 2 timers are running, like maybe suspend the outer
/// ones which inner ones are running; this would allow measure OneofusNet time minus Fire time.
class Measure with ChangeNotifier {
  static final List<Measure> _instances = <Measure>[];

  factory Measure(String name) {
    Measure out = Measure._internal(name);
    _instances.add(out);
    return out;
  }

  static void dump() {
    print('Measures:');
    for (Measure m in _instances) {
      print('- ${m._name}: ${m.elapsed}');
    }
  }

  static void reset() {
    for (Measure m in _instances) {
      m._reset();
    }
  }

  Measure._internal(this._name);

  final Stopwatch _stopwatch = Stopwatch();
  final String _name;

  void _reset() {
    _stopwatch.reset();
  }

  void start() {
    _stopwatch.start();
    notifyListeners();
  }

  void stop() {
    _stopwatch.stop();
    notifyListeners();
  }

  Duration get elapsed => _stopwatch.elapsed;

  bool get isRunning => _stopwatch.isRunning;

  Future mAsync(func) async {
    try {
      assert(!_stopwatch.isRunning);
      _stopwatch.start();
      final out = await func();
      return out;
    } finally {
      _stopwatch.stop();
    }
  }

  dynamic mSync(func) {
    try {
      assert(!_stopwatch.isRunning);
      _stopwatch.start();
      final out = func();
      return out;
    } finally {
      _stopwatch.stop();
    }
  }
}
