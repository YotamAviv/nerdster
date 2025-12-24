import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/wot_equivalence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('base', () {
    Set<String> network = {'homer2', 'homer', 'sideshow'};

    WotEquivalence wot = WotEquivalence(network);
    expect(wot.process(EquateStatement('homer2', 'homer')), null);
    expect(wot.process(EquateStatement('sideshow', 'homer')), 'Equivalent key already replaced');

    wot.make();

    expect(wot.getCanonical('homer'), 'homer2');
    expect(wot.getCanonical('homer2'), 'homer2');
    expect(wot.getCanonical('sideshow'), 'sideshow');
    expect(wot.getEquivalents('homer'), {'homer', 'homer2'});
    expect(wot.getEquivalents('homer2'), {'homer', 'homer2'});
    expect(wot.getEquivalents('sideshow'), {'sideshow'});
  });

  test('base trans', () {
    Set<String> network = {'homer2', 'homer', 'sideshow', 'homer3'};

    WotEquivalence wot = WotEquivalence(network);
    expect(wot.process(EquateStatement('homer2', 'homer')), null);
    expect(wot.process(EquateStatement('sideshow', 'homer')), 'Equivalent key already replaced');
    expect(wot.process(EquateStatement('homer3', 'homer2')), null);

    wot.make();

    expect(wot.getCanonical('homer'), 'homer3');
    expect(wot.getCanonical('homer2'), 'homer3');
    expect(wot.getCanonical('sideshow'), 'sideshow');
    expect(wot.getEquivalents('homer'), {'homer', 'homer2', 'homer3'});
    expect(wot.getEquivalents('homer2'), {'homer', 'homer2', 'homer3'});
    expect(wot.getEquivalents('sideshow'), {'sideshow'});
    expect(wot.getEquivalents('homer3'), {'homer', 'homer2', 'homer3'});
  });
}