import 'package:oneofus_common/clock.dart';

/// Would be nice to have this in the test dir, but I couldn't
/// easily make that work.

class TestClock extends Clock {
  // Tests failed when I moved PST to EST (were off by 3 hours).
  // I think that I now both state and dump in local time.
  // Only stored, dumped statements are in UTC.
  DateTime _now = DateTime.parse("2024-05-01T00:00");
  Duration? duration;

  TestClock([this.duration = const Duration(minutes: 1)]);

  DateTime get nowClean => _now;

  // I take no pride in what I did with this getter having side effects.
  @override
  DateTime get now {
    DateTime next = _now.add(duration!);
    _now = next;
    return _now;
  }
}
