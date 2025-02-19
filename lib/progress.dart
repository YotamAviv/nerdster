import 'dart:async';

/// I'm thinking about 2 things:
///
/// 1) Instrumentation to investigate what's slow. My time would probably be better spent learning about the tools.
///
/// TODO: Looks like I'm slow, not just Firebase (Fetcher.elapsed showed ~ 1/3 of total)
/// - Instrument Jsonish
/// - Next..? Instrument other Firebase calls in Fetcher?
///
/// 2) A fancy progress bar
/// We don't know how long it will take, and so it won't be 0-100%.
/// Would be nice:
/// - All skipping/cancelling whatever it's doing:
///   - while loading network, see how many degrees and which tokens, cancel any time?
///   - while loading content, see how many oneofus and delegates have been fetched, cancel any time?
/// (I don't think computing takes time, just loading)
///
class Progress {}

class Measure {
  final stopwatch = Stopwatch();

  void reset() {
    stopwatch.reset();
  }

  Duration get elapsed => stopwatch.elapsed;

  Future make(func) async {
    assert(!stopwatch.isRunning);
    stopwatch.start();
    final out = await func();
    stopwatch.stop();
    return out;
  }
}
