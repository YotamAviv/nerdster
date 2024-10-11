import 'package:nerdster/oneofus/util.dart';

/// Would be nice to have this in the test dir, but I couldn't
/// easily make that work.

class TestClock extends Clock {
  DateTime _now = parseIso("2024-05-01T07:00:00Z");
  Duration duration = const Duration(minutes: 1);

  DateTime get nowClean => _now;

  // I take no pride in what I did with this getter having side effects.
  @override
  DateTime get now {
    DateTime next = _now.add(duration);
    _now = next;
    return _now;
  }
}

