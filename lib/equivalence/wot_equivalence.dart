import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/equivalence_bridge.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// Unlike the other equivalence where different folks collaborate to form equivalence group,
/// this is supposed to form just one person's equivalence group of his own keys. 
/// The keys are used to state:
///   I replace subject. (I am canonical, and subject is equivalent.)
/// The algorithm processes these statements in order of trust and forms equivalence groups.
///
/// Point from equiv to canon. Once such a pointer exists, it cannot be overriden by 
/// subsequent (less trusted) statements.
/// Form EGs (sets) by sweeping through.
/// 
/// NOTE:
/// Correctness of the web-of-trust relys on our Trust algorithm to reject attempts
/// for malicious actors to try and claim your key as an equivalent of their key.
/// 
/// The demo/test blockOldKey demonstrated a case where [Trust1] does not
/// reject a replace statement (and so it was passed on to [WotEquivalence]),
/// but a later block statemet removed the equivalent from the network.
/// This is why network is for - to restrict equivalences to the network.
class WotEquivalence {
  final Map<String, String> equiv2canon = <String, String>{};
  final Map<String, Set<String>> canon2equivs = <String, Set<String>>{};
  final Set<String> network;

  WotEquivalence(this.network);

  String getCanonical(String equiv) => equiv2canon[equiv] ?? equiv;

  Set<String> getEquivalents(String token) =>
    canon2equivs[getCanonical(token)]?? {token};

  void make() {
    for (String equiv in equiv2canon.keys) {
      final String canon = _climbFindCanon(equiv);
      equiv2canon[equiv] = canon; // concurrent modification? no issues so far, could always make a copy right in the for statement.
      Set<String> equivs = canon2equivs.putIfAbsent(canon, () => <String>{canon});
      equivs.add(equiv);
    }
  }

  // Concerns:
  // Malicious actor trys to add your key to his group.
  // Case 1: It's your current active, canonical key:
  //   The trust algorithm should have rejected this statement because it would revoke your key.
  // Case 2: It's one of your equivalent keys:
  //   You should have claimed it first.
  // 
  // returns rejection reason in case of conflict.
  String? process(final EquateStatement es) {
    xssert(!es.dont);
    xssert(es.canonical != es.equivalent);
    if (!network.contains(es.equivalent)) {
      return '''Replaced key not in network.''';
    }
    if (!network.contains(es.canonical)) {
      return '''Replacing key not in network.''';
    }
    if (equiv2canon.containsKey(es.equivalent)) {
      xssert(equiv2canon[es.equivalent] != es.canonical, 'repeat');
      return '''Equivalent key already replaced''';
    }
    equiv2canon[es.equivalent] = es.canonical;
    return null;
  }

  String _climbFindCanon(String equiv) {
    String x = equiv2canon[equiv]!;
    while (equiv2canon.containsKey(x)) {
      x = equiv2canon[x]!;
    }
    return x;
  }
}

class NerdEquateParser implements EquivalenceBridgeParser {
  @override
  EquateStatement? parse(Statement s) {
    TrustStatement statement = s as TrustStatement;
    if (statement.verb == TrustVerb.replace) {
      String canonical = statement.iToken;
      String equivalent = statement.subjectToken;
      return EquateStatement(canonical, equivalent);
    }
    return null;
  }

  static String getToken(dynamic subject) => Jsonish(subject).token;
}

