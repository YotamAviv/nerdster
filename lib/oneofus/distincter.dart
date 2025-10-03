import 'statement.dart';

/// CONSIDER: Eliminate this and move to where neeced.

// Careful: This used to return a List, and so callers could have iterated twice.

Iterable<T> distinct<T extends Statement>(
  Iterable<T> source, {
  Transformer? transformer,
}) sync* {
  final seen = <String>{};

  for (final s in source) {
    final key = s.getDistinctSignature(transformer: transformer);
    if (seen.add(key)) {
      yield s;
    }
  }
}
