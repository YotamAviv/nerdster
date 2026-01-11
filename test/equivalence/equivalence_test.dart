import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/equivalence/eg.dart';
import 'package:nerdster/equivalence/equivalence.dart';
import 'package:nerdster/equivalence/equate_statement.dart';

void main() {
  test('(set equality, passes)', () {
    Set s1 = {'hi', 3};
    Set s2 = {3, 'hi'};
    expect(s1, s2);
  });

/* Fails:
  test('(set as key, fails)', () {
    Set<Object> s1 = {'hi', 3};
    Set<Object> s2 = {3, 'hi'};
    Set<Object> s3 = {3, 'hi', 4};
    Map<Set<Object>, bool> map = <Set<Object>, bool>{};
    map[s1] = false;

    expect(map[s1], true);
    expect(map[s2], true);
    // expect(ss.contains(s3), true);
  });
*/

  test('ab ca', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'b')), true);
    expect(equivalence.process(EquateStatement('a', 'b')), true); // (repeat)
    expect(equivalence.process(EquateStatement('b', 'a')), false); // conflict
    expect(equivalence.process(EquateStatement('c', 'a')), true);
    expect(equivalence.process(EquateStatement('a', 'b')), true); // (repeat)
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> combined = equivalence.createGroups();
    expect(combined, {
      EquivalenceGroup('c', {'a', 'b', 'c'}, {})
    });
  });

  test('ab ac', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'b')), true);
    expect(equivalence.process(EquateStatement('a', 'b')), true); // (repeat)
    expect(equivalence.process(EquateStatement('b', 'a')), false); // conflict
    expect(equivalence.process(EquateStatement('a', 'c')), true);
    expect(equivalence.process(EquateStatement('a', 'b')), true); // (repeat)
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> combined = equivalence.createGroups();
    expect(combined, {
      EquivalenceGroup('a', {'a', 'b', 'c'}, {})
    });
  });

  test('ab ef', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'b')), true);
    expect(equivalence.process(EquateStatement('e', 'f')), true);
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> combined = equivalence.createGroups();
    expect(combined, {
      EquivalenceGroup('a', {'b', 'a'}, {}),
      EquivalenceGroup('e', {'f', 'e'}, {})
    });
  });

  test('ab cd db', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'b')), true);
    expect(equivalence.process(EquateStatement('c', 'd')), true);
    expect(equivalence.process(EquateStatement('d', 'b')), true);
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> combined = equivalence.createGroups();
    expect(combined, {
      EquivalenceGroup('c', {'a', 'b', 'c', 'd'}, {})
    });
  });

  test('!ab ab', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'b', dont: true)), true);
    expect(equivalence.process(EquateStatement('a', 'b')), false); // conflict
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> combined = equivalence.createGroups();
    expect(combined, <EquivalenceGroup>{
      // NOTE: These EGs are here as a side-effect of noting the NOT.
      EquivalenceGroup('a', {'a'}, {'b'}),
      EquivalenceGroup('b', {'b'}, {'a'}),
    });
  });

  test('ab !ab', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'b')), true);
    expect(equivalence.process(EquateStatement('a', 'b', dont: true)), false); // conflict
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> egs = equivalence.createGroups();
    expect(egs, {
      EquivalenceGroup('a', {'a', 'b'}, {})
    });
  });

  test('!ac ab bc', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'c', dont: true)), true);
    expect(equivalence.process(EquateStatement('a', 'b')), true);
    expect(equivalence.process(EquateStatement('b', 'c')), false); // conflict
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> combined = equivalence.createGroups();
    expect(combined, <EquivalenceGroup>{
      EquivalenceGroup('a', {'a', 'b'}, {'c'}),
      EquivalenceGroup('c', {'c'}, {'a'}),
    });
  });

  test('!ax bx ab', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.process(EquateStatement('a', 'x', dont: true)), true);
    expect(equivalence.process(EquateStatement('b', 'x', dont: true)), true);
    expect(equivalence.process(EquateStatement('a', 'b')), true);
    expect(equivalence.process(EquateStatement('b', 'x')), false);
    equivalence.checkRepInvariant();
    Set<EquivalenceGroup> combined = equivalence.createGroups();
    expect(combined, <EquivalenceGroup>{
      EquivalenceGroup('a', {'a', 'b'}, {'x'}),
      EquivalenceGroup('x', {'x'}, {'a'}),
    });
  });
}
