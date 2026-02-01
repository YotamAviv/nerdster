import 'statement.dart';

/// Careful: This used to return a List, and so callers could have iterated twice.

Iterable<T> distinct<T extends Statement>(
  Iterable<T> source, {
  Transformer? iTransformer,
  Transformer? sTransformer,
}) sync* {
  final seen = <String>{};
  for (final s in source) {
    final key = s.getDistinctSignature(iTransformer: iTransformer, sTransformer: sTransformer);
    if (seen.add(key)) {
      yield s;
    }
  }
}
