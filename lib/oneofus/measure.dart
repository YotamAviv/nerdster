import 'dart:async';

import 'package:flutter/foundation.dart';

/// I'm thinking about 2 things:
///
/// 1) Instrumentation to investigate what's slow. My time would probably be better spent learning about the tools.
/// Some progress made, see [Measure] uses
///
/// 2) A fancy progress bar
/// We don't know how long it will take, and so it won't be 0-100%.
/// Would be nice:
/// - All skipping/cancelling whatever it's doing:
///   - while loading network, see how many degrees and which tokens, cancel any time?
///   - while loading content, see how many oneofus and delegates have been fetched, cancel any time?
/// (I don't think computing takes time, just loading)
///

/// DEFER: Look for someone else's one of these instead of working on this one more.
/// DEFER: Consider doing something smart when 2 timers are running, like maybe suspend the outer
/// ones which inner ones are running; this would allow measure OneofusNet time minus Fire time.
class Measure with ChangeNotifier {
  static List<Measure> _instances = <Measure>[];

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
