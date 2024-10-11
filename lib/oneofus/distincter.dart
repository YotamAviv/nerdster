import 'statement.dart';
import 'util.dart';

Map<(Iterable<Statement>, Transformer?), Iterable<Statement>> _cache =
    <(Iterable<Statement>, Transformer?), Iterable<Statement>>{};

void clearDistinct() {
  _cache.clear();
}

Iterable<Statement> distinct(Iterable<Statement> source, {Transformer? transformer}) {
  Iterable<Statement>? out = _cache[(source, transformer)];
  if (b(out)) return out!;

  final Set<String> already = <String>{};
  final List<Statement> distinct = <Statement>[];
  for (Statement s in source) {
    String key = s.getDistinctSignature(transformer: transformer);
    if (!already.contains(key)) {
      already.add(key);
      distinct.add(s);
    }
  }
  out = distinct.where((s) => !s.isClear);
  _cache[(source, transformer)] = out;
  return out;
}
