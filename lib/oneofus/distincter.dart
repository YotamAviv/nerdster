import 'statement.dart';

/// CONSIDER: Eliminate this and move to where neeced. 

List<Statement> distinct(Iterable<Statement> source, {Transformer? transformer}) {
  final Set<String> already = <String>{};
  List<Statement> distinct = <Statement>[];
  for (Statement s in source) {
    String key = s.getDistinctSignature(transformer: transformer);
    if (!already.contains(key)) {
      already.add(key);
      distinct.add(s);
    }
  }
  return distinct;
}
