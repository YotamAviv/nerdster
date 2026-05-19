import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/equivalence/equivalence.dart';

// Verifies that groups contains exactly the expected (canonical, all, donts) triples.
void _expectGroups(
    Iterable<EquivalenceGroup> actual,
    List<(String, Set<String>, Set<String>)> expected) {
  final groups = actual.toList();
  expect(groups.length, expected.length);
  for (final (canonical, all, donts) in expected) {
    final match = groups.any((g) {
      final gAll = g.all.toSet();
      final gDonts = g.donts.toSet();
      return g.canonical == canonical &&
          gAll.length == all.length && gAll.containsAll(all) &&
          gDonts.length == donts.length && gDonts.containsAll(donts);
    });
    expect(match, isTrue,
        reason: 'Missing group: canonical=$canonical all=$all donts=$donts');
  }
}

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
    expect(equivalence.equate('b', 'a'), true);
    expect(equivalence.equate('b', 'a'), true); // (repeat)
    expect(equivalence.equate('a', 'b'), false); // conflict
    expect(equivalence.equate('a', 'c'), true);
    expect(equivalence.equate('b', 'a'), true); // (repeat)
    equivalence.checkRepInvariant();
    _expectGroups(equivalence.groups, [
      ('c', {'a', 'b', 'c'}, <String>{}),
    ]);
  });

  test('ab ac', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.equate('b', 'a'), true);
    expect(equivalence.equate('b', 'a'), true); // (repeat)
    expect(equivalence.equate('a', 'b'), false); // conflict
    expect(equivalence.equate('c', 'a'), true);
    expect(equivalence.equate('b', 'a'), true); // (repeat)
    equivalence.checkRepInvariant();
    _expectGroups(equivalence.groups, [
      ('a', {'a', 'b', 'c'}, <String>{}),
    ]);
  });

  test('ab ef', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.equate('b', 'a'), true);
    expect(equivalence.equate('f', 'e'), true);
    equivalence.checkRepInvariant();
    _expectGroups(equivalence.groups, [
      ('a', {'a', 'b'}, <String>{}),
      ('e', {'e', 'f'}, <String>{}),
    ]);
  });

  test('ab cd db', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.equate('b', 'a'), true);
    expect(equivalence.equate('d', 'c'), true);
    expect(equivalence.equate('b', 'd'), true);
    equivalence.checkRepInvariant();
    _expectGroups(equivalence.groups, [
      ('c', {'a', 'b', 'c', 'd'}, <String>{}),
    ]);
  });

  test('!ab ab', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.equate('b', 'a', not: true), true);
    expect(equivalence.equate('b', 'a'), false); // conflict
    equivalence.checkRepInvariant();
    // NOTE: These EGs are here as a side-effect of noting the NOT.
    _expectGroups(equivalence.groups, [
      ('a', {'a'}, {'b'}),
      ('b', {'b'}, {'a'}),
    ]);
  });

  test('ab !ab', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.equate('b', 'a'), true);
    expect(equivalence.equate('b', 'a', not: true), false); // conflict
    equivalence.checkRepInvariant();
    _expectGroups(equivalence.groups, [
      ('a', {'a', 'b'}, <String>{}),
    ]);
  });

  test('!ac ab bc', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.equate('c', 'a', not: true), true);
    expect(equivalence.equate('b', 'a'), true);
    expect(equivalence.equate('c', 'b'), false); // conflict
    equivalence.checkRepInvariant();
    _expectGroups(equivalence.groups, [
      ('a', {'a', 'b'}, {'c'}),
      ('c', {'c'}, {'a'}),
    ]);
  });

  test('!ax bx ab', () {
    Equivalence equivalence = Equivalence();
    expect(equivalence.equate('x', 'a', not: true), true);
    expect(equivalence.equate('x', 'b', not: true), true);
    expect(equivalence.equate('b', 'a'), true);
    expect(equivalence.equate('x', 'b'), false);
    equivalence.checkRepInvariant();
    _expectGroups(equivalence.groups, [
      ('a', {'a', 'b'}, {'x'}),
      ('x', {'x'}, {'a'}),
    ]);
  });
}
