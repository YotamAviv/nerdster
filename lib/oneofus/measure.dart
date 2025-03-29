import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

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

/// Progress dialog
/// OneofusNet:
/// We know that we're going from 1 to 5 degrees, and so exponention 1-5
/// We don't know how many edges we'll have.
///
///
/// FollowNet (Content):
/// We know how many tokens are in the network, not sure how many statements in each, but linear'ish.

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
      m._dump();
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
  final Map<String, Duration> token2time = {};

  void _dump() {
    print('- ${_name}: ${elapsed}');
    for (MapEntry e in token2time.entries.sorted((e1, e2) => e1.value < e2.value ? 1 : -1)) {
      print('  ${e.value.toString()} (${keyLabels.labelKey(e.key)})');
    }
  }

  void _reset() {
    _stopwatch.reset();
    token2time.clear();
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

  Future mAsync(func, {String? token}) async {
    Duration d = _stopwatch.elapsed;
    try {
      assert(!_stopwatch.isRunning);
      d = _stopwatch.elapsed;
      _stopwatch.start();
      final out = await func();
      return out;
    } finally {
      _stopwatch.stop();
      if (b(token)) {
        Duration dd = _stopwatch.elapsed - d;
        // BUG: FIRES and is really hard to find in stack trace in Chrome assert(!token2time.containsKey(token));
        // Fetcher fetches once to find revokedAtTime and then again to get all earlier statements.
        token2time[token!] = dd;
      }
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
