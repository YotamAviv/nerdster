import 'statement.dart';

class Merger {
  /// Merge multiple sorted iterables of [T extends Statement],
  /// producing a single sorted iterable by descending time.
  static Iterable<T> merge<T extends Statement>(Iterable<Iterable<T>> sources) sync* {
    Statement.validateOrderTypess(sources);
    final iters = sources
        .map((s) => s.iterator)
        .where((i) => i.moveNext()) // only keep non-empty
        .toList();

    while (iters.isNotEmpty) {
      // pick the most recent (max by .time)
      Iterator<T> mostRecent = iters.reduce(
        (a, b) => a.current.time.isAfter(b.current.time) ? a : b,
      );

      yield mostRecent.current;

      if (!mostRecent.moveNext()) {
        iters.remove(mostRecent);
      }
    }
  }
}
