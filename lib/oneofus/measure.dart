import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nerdster/oneofus/util.dart';

/// I had ambitions but did not achieve them. This is not well planned, well documented, or well
/// excuted. See both Measure and Progress.

/// 1) Instrumentation to investigate what's slow, how slow, ...
/// Fire fetching is what's slow, and the performance seems to vary depending on cloud functions
/// number of calls, ?after=<after>, ?distinct, etc...
/// (I don't think computing takes time, just loading)

/// Progress dialog is related to this, and I was optimistic about combining the 2, but didn't.

/// Probably not: Stack push / pop?
/// I believe that only Fire fetching is slow.
/// Would be nice to know more about that. Oneofus costs, FollowNet costs, per user or token costs..
/// Future work on fetch?after=<time> or fetch?limit=<limit> would be affected by the ability to measure.
///
/// Both of these:
/// - Data structure output (probably JSON)
/// - Progress dialog

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
  final List<(String, Duration)> token2time = [];

  void _dump() {
    print('- ${_name}: ${elapsed}');
    for (var pair in token2time) { // .sorted((e1, e2) => e1.value < e2.value ? 1 : -1)) {
      print('  ${pair.$1} (${pair.$2})');
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

  Future mAsync(func, {String? note}) async {
    Duration d = _stopwatch.elapsed;
    try {
      assert(!_stopwatch.isRunning);
      d = _stopwatch.elapsed;
      _stopwatch.start();
      final out = await func();
      return out;
    } finally {
      _stopwatch.stop();
      if (b(note)) {
        Duration dd = _stopwatch.elapsed - d;
        // BUG: FIRES and is really hard to find in stack trace in Chrome assert(!token2time.containsKey(token));
        // Fetcher fetches once to find revokedAtTime and then again to get all earlier statements.
        token2time.add((note!, dd));
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
