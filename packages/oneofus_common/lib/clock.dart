abstract class Clock {
  DateTime get now;
  String get nowIso => now.toUtc().toIso8601String();
}

class LiveClock extends Clock {
  @override
  DateTime get now => DateTime.now();
}

Clock clock = LiveClock();

void useClock(Clock c) {
  clock = c;
}

String formatIso(DateTime d) => d.toUtc().toIso8601String();
DateTime parseIso(String s) => DateTime.parse(s);
