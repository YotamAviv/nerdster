import 'dart:collection';

import 'package:nerdster/equivalence/eg.dart';
import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/equivalence.dart';
import 'package:nerdster/oneofus/statement.dart';

abstract class EquivalenceBridgeParser {
  EquateStatement? parse(Statement statement);
}

class EquivalenceBridge {
  Equivalence equivalence = Equivalence();
  final Map<String, String> equivalent2canonical = <String, String>{};
  final Map<String, Set<String>> canonical2equivalents = <String, Set<String>>{};
  final EquivalenceBridgeParser parser;

  // CODE: Rename to chained and explain it. Is it this?: If I say A is related to B, but we also
  // have A is actually AA, then we should be saying AA is related B.
  final EquivalenceBridge? _equivalence2;

  final Set<String> _rejected = <String>{};

  EquivalenceBridge(this.parser, this._equivalence2);

  bool isRejected(String token) => _rejected.contains(token);

  void clear() {
    equivalence = Equivalence();
    equivalent2canonical.clear();
    canonical2equivalents.clear();
  }

  void process(Statement statement) {
    EquateStatement? es = parser.parse(statement);

    if (es != null) {
      if (_equivalence2 != null) {
        es.canonical = _equivalence2.getCanonical(es.canonical);
        es.equivalent = _equivalence2.getCanonical(es.equivalent);
      }
      bool accepted = equivalence.process(es);
      if (!accepted) {
        _rejected.add(statement.token);
      }
    } else {}
  }

  // return value for debugging
  Set<EquivalenceGroup> make() {
    Set<EquivalenceGroup> egs = equivalence.createGroups();
    for (EquivalenceGroup eg in egs) {
      for (String equiv in eg.all) {
        equivalent2canonical[equiv] = eg.canonical;
      }
      canonical2equivalents[eg.canonical] = UnmodifiableSetView(eg.all);
      assert(eg.all.contains(eg.canonical));
    }
    return egs;
  }

  String getCanonical(String token) => equivalent2canonical[token] ?? token;

  Set<String> getEquivalents(String token) => canonical2equivalents[getCanonical(token)] ?? {token};
}
